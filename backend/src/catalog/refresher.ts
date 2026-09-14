// Shared-catalog refresh job (M11). See docs/M11.md "Backend" and "Frozen contracts".
import { createHash } from 'node:crypto';
import type { Db } from '../accounts/db.js';
import type { RecipeGateway } from '../gateway.js';
import { markFailure, markUnchanged, publishCatalog, readCatalogState } from './store.js';

const LETTERS = Object.freeze('abcdefghijklmnopqrstuvwxyz'.split(''));
const DEFAULT_INTERVAL_MS = 24 * 60 * 60 * 1000;
const DEFAULT_LETTER_PAUSE_MS = 1000;

interface ProviderDrink { idDrink: string; strDrink: string; [key: string]: unknown }

/** The subset of a fetch-capable gateway the refresher needs; matches {@link RecipeGateway}. */
export interface CatalogGateway {
  get(operation: { endpoint: 'search.php'; parameter: 'f'; value: string }): Promise<string>;
}

/** Injectable timer surface so scheduling and cancellation are deterministic in tests. */
export interface CatalogTimers {
  setInterval(handler: () => void, ms: number): NodeJS.Timeout;
  clearInterval(handle: NodeJS.Timeout): void;
  setTimeout(handler: () => void, ms: number): NodeJS.Timeout;
  clearTimeout(handle: NodeJS.Timeout): void;
}

const REAL_TIMERS: CatalogTimers = { setInterval, clearInterval, setTimeout, clearTimeout };

export interface RefreshOutcome {
  published: boolean;
  version: string;
  recipeCount: number;
}

export interface CatalogRefresherOptions {
  db: Db;
  gateway: CatalogGateway;
  clock?: (() => Date) | undefined;
  intervalMs?: number | undefined;
  letterPauseMs?: number | undefined;
  timers?: CatalogTimers | undefined;
  /** Test/observability hook; never used for control flow. */
  onRefresh?: ((outcome: RefreshOutcome) => void) | undefined;
  onFailure?: ((code: string) => void) | undefined;
}

/**
 * Refreshes the shared catalog from TheCocktailDB's letter browse. All-or-
 * nothing: a version is published only once all 26 letters have validated.
 * Never overlaps two runs, never blocks the caller, and stops promptly on
 * close() (the current in-flight step still finishes, but no further step
 * starts and nothing more is written).
 */
export class CatalogRefresher {
  private readonly db: Db;
  private readonly gateway: CatalogGateway;
  private readonly clock: () => Date;
  private readonly intervalMs: number;
  private readonly letterPauseMs: number;
  private readonly timers: CatalogTimers;
  private readonly onRefresh: ((outcome: RefreshOutcome) => void) | undefined;
  private readonly onFailure: ((code: string) => void) | undefined;

  private interval: NodeJS.Timeout | undefined;
  private running: Promise<void> | undefined;
  private closed = false;
  private cancelSleep: (() => void) | undefined;

  constructor(options: CatalogRefresherOptions) {
    this.db = options.db;
    this.gateway = options.gateway;
    this.clock = options.clock ?? (() => new Date());
    this.intervalMs = options.intervalMs ?? DEFAULT_INTERVAL_MS;
    this.letterPauseMs = options.letterPauseMs ?? DEFAULT_LETTER_PAUSE_MS;
    this.timers = options.timers ?? REAL_TIMERS;
    this.onRefresh = options.onRefresh;
    this.onFailure = options.onFailure;
  }

  /** Never blocks the caller (safe to call before app.listen resolves). */
  async start(): Promise<void> {
    if (this.closed) return;
    let stale = true;
    try {
      const state = await readCatalogState(this.db);
      stale = !state || this.clock().getTime() - Date.parse(state.checkedAt) >= this.intervalMs;
    } catch {
      stale = true;
    }
    this.interval = this.timers.setInterval(() => { void this.refresh(); }, this.intervalMs);
    if (typeof (this.interval as unknown as { unref?: () => void }).unref === 'function') {
      (this.interval as unknown as { unref: () => void }).unref();
    }
    if (stale) void this.refresh();
  }

  /** Runs a refresh now unless one is already in flight, in which case it returns that run. */
  refresh(): Promise<void> {
    if (this.closed) return Promise.resolve();
    if (!this.running) {
      this.running = this.runOnce().finally(() => { this.running = undefined; });
    }
    return this.running;
  }

  /** Stops the recurring timer and any pending pause promptly; does not await a run in flight. */
  async close(): Promise<void> {
    this.closed = true;
    if (this.interval) this.timers.clearInterval(this.interval);
    this.cancelSleep?.();
    this.running?.catch(() => {});
  }

  private sleep(ms: number): Promise<void> {
    if (this.closed) return Promise.resolve();
    return new Promise<void>((resolve) => {
      const handle = this.timers.setTimeout(() => { this.cancelSleep = undefined; resolve(); }, ms);
      this.cancelSleep = () => { this.timers.clearTimeout(handle); this.cancelSleep = undefined; resolve(); };
    });
  }

  private async runOnce(): Promise<void> {
    const byId = new Map<string, ProviderDrink>();
    for (let index = 0; index < LETTERS.length; index++) {
      if (this.closed) return;
      const letter = LETTERS[index]!;
      let body: string;
      try {
        body = await this.gateway.get({ endpoint: 'search.php', parameter: 'f', value: letter });
      } catch (error) {
        await this.fail(errorCodeOf(error));
        return;
      }
      if (this.closed) return;
      const drinks = parseDrinks(body);
      if (drinks === undefined) {
        await this.fail('invalid_response');
        return;
      }
      for (const drink of drinks) {
        if (!byId.has(drink.idDrink)) byId.set(drink.idDrink, drink);
      }
      if (index < LETTERS.length - 1) {
        await this.sleep(this.letterPauseMs);
        if (this.closed) return;
      }
    }

    const sorted = [...byId.values()].sort(compareProviderIds);
    if (sorted.length === 0) {
      // A zero-drink total is a failure, not a publish: it almost certainly
      // means a validation gap or upstream regression, not an empty catalog.
      await this.fail('empty_catalog');
      return;
    }

    const canonical = JSON.stringify(sorted);
    const version = createHash('sha256').update(canonical).digest('hex');
    const now = this.clock().toISOString();

    try {
      const current = await readCatalogState(this.db);
      if (this.closed) return;
      if (current && current.version === version) {
        await markUnchanged(this.db, now);
        this.onRefresh?.({ published: false, version, recipeCount: sorted.length });
        return;
      }
      await publishCatalog(this.db, {
        version, recipeCount: sorted.length, publishedAt: now, checkedAt: now,
        drinks: sorted.map((drink) => ({ providerId: drink.idDrink, name: drink.strDrink, source: JSON.stringify(drink) })),
      });
      this.onRefresh?.({ published: true, version, recipeCount: sorted.length });
    } catch {
      await this.fail('storage_error');
    }
  }

  private async fail(code: string): Promise<void> {
    this.onFailure?.(code);
    try {
      await markFailure(this.db, this.clock().toISOString(), code);
    } catch {
      // Storage itself is failing: the previous snapshot (if any) is simply
      // left as-is. Never throw out of a background refresh.
    }
  }
}

function compareProviderIds(a: ProviderDrink, b: ProviderDrink): number {
  if (a.idDrink.length !== b.idDrink.length) return a.idDrink.length - b.idDrink.length;
  return a.idDrink < b.idDrink ? -1 : a.idDrink > b.idDrink ? 1 : 0;
}

function record(value: unknown): value is Record<string, unknown> {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

/** Validates the envelope the gateway already validated, plus the fields the catalog needs. */
function parseDrinks(body: string): ProviderDrink[] | undefined {
  let value: unknown;
  try {
    value = JSON.parse(body);
  } catch {
    return undefined;
  }
  if (!record(value) || !('drinks' in value)) return undefined;
  const drinks = value.drinks;
  if (drinks === null) return [];
  if (!Array.isArray(drinks)) return undefined;
  for (const drink of drinks) {
    if (!record(drink) || typeof drink.idDrink !== 'string' || !/^\d+$/.test(drink.idDrink) ||
        typeof drink.strDrink !== 'string' || !drink.strDrink.trim()) {
      return undefined;
    }
  }
  return drinks as ProviderDrink[];
}

function errorCodeOf(error: unknown): string {
  if (record(error) && typeof error.code === 'string') return error.code;
  return 'refresh_failed';
}
