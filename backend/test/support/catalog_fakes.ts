// Fakes for CatalogRefresher unit tests: deterministic timers and a
// synthetic gateway shaped like RecipeGateway.get, never real network.
import { GatewayError } from '../../src/gateway.js';
import type { CatalogGateway, CatalogTimers } from '../../src/catalog/refresher.js';

export interface FakeTimers {
  timers: CatalogTimers;
  /** Synchronously invokes every currently pending interval callback. */
  fireIntervals(): void;
  /** Synchronously invokes and clears every currently pending timeout callback. */
  fireTimeouts(): void;
  pendingTimeouts(): number;
  pendingIntervals(): number;
}

export function createFakeTimers(): FakeTimers {
  let nextId = 1;
  const intervals = new Map<number, () => void>();
  const timeouts = new Map<number, () => void>();
  const timers: CatalogTimers = {
    setInterval: (handler) => {
      const id = nextId++;
      intervals.set(id, handler);
      return id as unknown as NodeJS.Timeout;
    },
    clearInterval: (handle) => { intervals.delete(handle as unknown as number); },
    setTimeout: (handler) => {
      const id = nextId++;
      timeouts.set(id, handler);
      return id as unknown as NodeJS.Timeout;
    },
    clearTimeout: (handle) => { timeouts.delete(handle as unknown as number); },
  };
  return {
    timers,
    fireIntervals: () => { for (const handler of [...intervals.values()]) handler(); },
    fireTimeouts: () => {
      const due = [...timeouts.values()];
      timeouts.clear();
      for (const handler of due) handler();
    },
    pendingTimeouts: () => timeouts.size,
    pendingIntervals: () => intervals.size,
  };
}

export interface FixtureDrink { idDrink: string; strDrink: string; strInstructions?: string; strIngredient1?: string }

export function fixtureDrink(id: string, name: string): FixtureDrink {
  return { idDrink: id, strDrink: name, strInstructions: 'Stir synthetic ingredients.', strIngredient1: 'Synthetic gin' };
}

export type LetterPlan = Record<string, FixtureDrink[] | 'fail' | undefined>;

/** Builds a CatalogGateway.get fake keyed by first-letter value, recording every call. */
export function fakeGateway(plan: LetterPlan, calls: string[] = []): { gateway: CatalogGateway; calls: string[] } {
  const gateway: CatalogGateway = {
    async get(operation) {
      calls.push(operation.value);
      const result = plan[operation.value];
      if (result === 'fail') throw new GatewayError('upstream_unavailable', 502);
      if (result === undefined || result.length === 0) return JSON.stringify({ drinks: null });
      return JSON.stringify({ drinks: result });
    },
  };
  return { gateway, calls };
}

export const ALL_LETTERS = 'abcdefghijklmnopqrstuvwxyz'.split('');

/** A full 26-letter plan with one distinct drink per letter, ids assigned in letter order. */
export function fullCatalogPlan(startId = 1): LetterPlan {
  const plan: LetterPlan = {};
  ALL_LETTERS.forEach((letter, index) => {
    plan[letter] = [fixtureDrink(String(startId + index), `${letter.toUpperCase()} Test Cocktail`)];
  });
  return plan;
}

/**
 * Drives a run to completion under fake timers: repeatedly fires whatever
 * timeouts are pending and yields the event loop, until `promise` settles.
 * Never advances fake intervals — those are asserted explicitly.
 */
export async function flushRefresh(promise: Promise<void>, fake: FakeTimers, maxTicks = 200): Promise<void> {
  let settled = false;
  void promise.finally(() => { settled = true; });
  for (let i = 0; i < maxTicks && !settled; i++) {
    fake.fireTimeouts();
    await new Promise<void>((resolve) => { setImmediate(resolve); });
  }
  await promise;
}

/** Yields a fixed number of microtask turns without resolving any timer. */
export async function flushMicrotasks(turns = 5): Promise<void> {
  for (let i = 0; i < turns; i++) await Promise.resolve();
}
