export type Endpoint = 'search.php' | 'filter.php' | 'lookup.php' | 'list.php';
export interface Operation { endpoint: Endpoint; parameter: 's' | 'f' | 'i'; value: string }
export type Fetcher = (url: string, init: RequestInit) => Promise<Response>;

export class GatewayError extends Error {
  constructor(readonly code: string, readonly status: number, readonly retryAfter?: number) {
    super('Recipe service request failed.');
  }
}

interface Options {
  apiKey: string;
  fetcher?: Fetcher;
  now?: () => number;
  timeoutMs?: number;
  ttlMs?: number;
  maxEntries?: number;
  maxBytes?: number;
  maxResponseBytes?: number;
  maxConcurrent?: number;
}

/** Memory-only, bounded cache. Never logs or returns upstream errors/URLs. */
export class RecipeGateway {
  private readonly options: Required<Options>;
  private readonly cache = new Map<string, { body: string; bytes: number; expires: number }>();
  private readonly pending = new Map<string, Promise<string>>();
  private readonly aborters = new Set<AbortController>();
  private bytes = 0;
  private cooldownUntil = 0;
  private closed = false;

  constructor(options: Options) {
    this.options = {
      fetcher: fetch, now: Date.now, timeoutMs: 8000, ttlMs: 600000,
      maxEntries: 64, maxBytes: 8 * 1024 * 1024,
      maxResponseBytes: 2 * 1024 * 1024, maxConcurrent: 4, ...options,
    };
    if (!/^[A-Za-z0-9_-]{1,256}$/.test(options.apiKey)) throw new Error('Invalid provider key configuration.');
    for (const name of ['timeoutMs', 'maxEntries', 'maxBytes', 'maxResponseBytes', 'maxConcurrent'] as const) {
      if (!Number.isSafeInteger(this.options[name]) || this.options[name] <= 0) throw new Error(`Invalid ${name}.`);
    }
    if (!Number.isSafeInteger(this.options.ttlMs) || this.options.ttlMs < 0) throw new Error('Invalid ttlMs.');
  }

  get(operation: Operation): Promise<string> {
    if (this.closed) return Promise.reject(new GatewayError('service_closed', 503));
    const key = JSON.stringify(operation);
    const cached = this.cache.get(key);
    if (cached) {
      this.cache.delete(key);
      if (cached.expires > this.options.now()) {
        this.cache.set(key, cached);
        return Promise.resolve(cached.body);
      }
      this.bytes -= cached.bytes;
    }
    const remaining = this.cooldownUntil - this.options.now();
    if (remaining > 0) return Promise.reject(new GatewayError('rate_limited', 429, Math.ceil(remaining / 1000)));
    const pending = this.pending.get(key);
    if (pending) return pending;
    if (this.pending.size >= this.options.maxConcurrent) {
      return Promise.reject(new GatewayError('service_busy', 503, 1));
    }
    const request = this.load(operation).then((body) => {
      if (!this.closed) {
        const bytes = Buffer.byteLength(body);
        if (bytes <= this.options.maxBytes && this.options.ttlMs > 0) {
          this.cache.set(key, { body, bytes, expires: this.options.now() + this.options.ttlMs });
          this.bytes += bytes;
          while (this.cache.size > this.options.maxEntries || this.bytes > this.options.maxBytes) {
            const oldest = this.cache.keys().next().value!;
            this.bytes -= this.cache.get(oldest)!.bytes;
            this.cache.delete(oldest);
          }
        }
      }
      return body;
    }).finally(() => { this.pending.delete(key); });
    this.pending.set(key, request);
    return request;
  }

  private async load(operation: Operation): Promise<string> {
    const controller = new AbortController();
    this.aborters.add(controller);
    let timedOut = false;
    let rejectAbort: (error: GatewayError) => void = () => {};
    const aborted = new Promise<never>((_, reject) => { rejectAbort = reject; });
    const onAbort = () => rejectAbort(new GatewayError(timedOut ? 'upstream_timeout' : 'service_closed', timedOut ? 504 : 503));
    controller.signal.addEventListener('abort', onAbort, { once: true });
    const timer = setTimeout(() => { timedOut = true; controller.abort(); }, this.options.timeoutMs);
    try {
      return await Promise.race([this.fetchBody(operation, controller.signal), aborted]);
    } catch (error) {
      if (error instanceof GatewayError) throw error;
      throw new GatewayError('upstream_unavailable', 502);
    } finally {
      clearTimeout(timer);
      controller.signal.removeEventListener('abort', onAbort);
      this.aborters.delete(controller);
    }
  }

  private async fetchBody(operation: Operation, signal: AbortSignal): Promise<string> {
    // The remote authority, version and endpoint set are never supplied by a caller.
    // V2, not V1: paid keys are issued as V2 keys, and V1 letter browse returns
    // an empty 200 body for them (verified live 2026-09-12). V2 keeps the same
    // endpoint names, parameters, envelope and null no-data shape, and the
    // public test key also works there with smaller result sets.
    const url = new URL(`https://www.thecocktaildb.com/api/json/v2/${this.options.apiKey}/${operation.endpoint}`);
    url.searchParams.set(operation.parameter, operation.value);
    const response = await this.options.fetcher(url.toString(), { method: 'GET', redirect: 'error', signal });
    if (signal.aborted) {
      void response.body?.cancel().catch(() => {});
      throw new GatewayError('service_closed', 503);
    }
    if (!response.ok) {
      void response.body?.cancel().catch(() => {});
      if (response.status === 429) {
        const delay = retrySeconds(response.headers.get('retry-after'), this.options.now());
        this.cooldownUntil = Math.max(this.cooldownUntil, this.options.now() + delay * 1000);
        throw new GatewayError('rate_limited', 429, Math.max(0, Math.ceil((this.cooldownUntil - this.options.now()) / 1000)));
      }
      throw new GatewayError('upstream_unavailable', 502);
    }
    const reader = response.body?.getReader();
    if (!reader) throw new GatewayError('invalid_response', 502);
    const chunks: Uint8Array[] = [];
    let size = 0;
    const cancel = () => { void reader.cancel().catch(() => {}); };
    signal.addEventListener('abort', cancel, { once: true });
    try {
      while (true) {
        const { done, value } = await reader.read();
        if (signal.aborted) throw new GatewayError('service_closed', 503);
        if (done) break;
        size += value.byteLength;
        if (size > this.options.maxResponseBytes) throw new GatewayError('invalid_response', 502);
        chunks.push(value);
      }
      const decoded: unknown = JSON.parse(new TextDecoder('utf-8', { fatal: true }).decode(Buffer.concat(chunks)));
      normalizeNoResults(decoded);
      validateEnvelope(decoded, operation);
      return JSON.stringify(decoded);
    } catch (error) {
      cancel();
      if (error instanceof GatewayError) throw error;
      throw new GatewayError('invalid_response', 502);
    } finally {
      signal.removeEventListener('abort', cancel);
    }
  }

  close(): void {
    this.closed = true;
    for (const controller of this.aborters) controller.abort();
    this.cache.clear();
    this.bytes = 0;
  }
}

function retrySeconds(value: string | null, now: number): number {
  if (value !== null && /^\d+$/.test(value.trim())) {
    const seconds = Number(value);
    if (Number.isSafeInteger(seconds) && Number.isSafeInteger(now + seconds * 1000)) return seconds;
  }
  const date = value === null ? NaN : Date.parse(value);
  return Number.isFinite(date) ? Math.max(0, Math.ceil((date - now) / 1000)) : 30;
}

function record(value: unknown): value is Record<string, unknown> {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

// V2 answers some no-match ingredient/name lookups with a "no data" string in
// place of the usual null/array `drinks` value (observed live 2026-09-13 with
// the public test key: `{"drinks":"None Found"}` for filter.php). This is
// provider-shaped noise, not a malformed envelope: normalize it to the same
// `drinks: null` shape already treated as a valid empty result, before
// validation runs. Any other string is left alone and still rejected below.
const NO_RESULTS_STRINGS = new Set(['none found', 'no data found']);

function normalizeNoResults(value: unknown): void {
  if (record(value) && typeof value.drinks === 'string' && NO_RESULTS_STRINGS.has(value.drinks.trim().toLowerCase())) {
    value.drinks = null;
  }
}

function validateEnvelope(value: unknown, operation: Operation): void {
  const invalid = () => { throw new GatewayError('invalid_response', 502); };
  if (!record(value) || !('drinks' in value)) return invalid();
  const drinks = value.drinks;
  if (drinks === null) return;
  if (!Array.isArray(drinks)) return invalid();
  if (operation.endpoint === 'lookup.php' && drinks.length > 1) return invalid();
  for (const drink of drinks) {
    if (!record(drink)) return invalid();
    if (operation.endpoint === 'list.php') {
      if (typeof drink.strIngredient1 !== 'string' || !drink.strIngredient1.trim()) return invalid();
      continue;
    }
    if (typeof drink.idDrink !== 'string' || !/^\d+$/.test(drink.idDrink) ||
        typeof drink.strDrink !== 'string' || !drink.strDrink.trim()) return invalid();
    if (operation.endpoint === 'lookup.php' && drink.idDrink !== operation.value) return invalid();
    if (operation.endpoint !== 'filter.php' && (!('strInstructions' in drink) || !('strIngredient1' in drink))) return invalid();
    // Source fields remain untouched, but malformed types must not poison cache.
    for (const [key, field] of Object.entries(drink)) {
      if (key.startsWith('str') && field !== null && typeof field !== 'string') return invalid();
    }
  }
}
