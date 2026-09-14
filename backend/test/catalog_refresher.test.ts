import test from 'node:test';
import assert from 'node:assert/strict';
import { CatalogRefresher } from '../src/catalog/refresher.js';
import { readCatalogRecipes, readCatalogState } from '../src/catalog/store.js';
import { createCatalogTestDb } from './support/catalog_test_db.js';
import {
  createFakeTimers, fakeGateway, fixtureDrink, flushMicrotasks, flushRefresh, fullCatalogPlan,
} from './support/catalog_fakes.js';

const CLOCK_START = '2026-09-14T08:00:00.000Z';

function mutableClock(iso: string) {
  let now = new Date(iso);
  return { clock: () => now, set: (nextIso: string) => { now = new Date(nextIso); } };
}

test('a full run dedupes across letters, sorts by provider id, and publishes once', async () => {
  const { db, cleanup } = await createCatalogTestDb();
  try {
    const plan = fullCatalogPlan();
    // A duplicate id under a second letter must not create a second row.
    const existingZ = plan.z;
    plan.z = [...(Array.isArray(existingZ) ? existingZ : []), fixtureDrink('1', 'A Test Cocktail')];
    const { gateway, calls } = fakeGateway(plan);
    const fake = createFakeTimers();
    const clock = mutableClock(CLOCK_START);
    const refresher = new CatalogRefresher({ db, gateway, clock: clock.clock, letterPauseMs: 5, timers: fake.timers });

    await flushRefresh(refresher.refresh(), fake);

    assert.equal(calls.length, 26);
    const state = await readCatalogState(db);
    assert.ok(state);
    assert.equal(state!.recipeCount, 26);
    assert.equal(state!.publishedAt, CLOCK_START);
    assert.equal(state!.checkedAt, CLOCK_START);
    assert.equal(state!.lastErrorCode, null);

    const rows = await readCatalogRecipes(db);
    assert.deepEqual(rows.map((row) => row.providerId), Array.from({ length: 26 }, (_, i) => String(i + 1)));
  } finally {
    await cleanup();
  }
});

test('version is stable across runs and independent of which letter contributed a drink', async () => {
  const dbA = await createCatalogTestDb();
  const dbB = await createCatalogTestDb();
  try {
    const drinks = [fixtureDrink('11007', 'Margarita'), fixtureDrink('11008', 'Mojito'), fixtureDrink('11009', 'Old Fashioned')];

    const planA: Record<string, ReturnType<typeof fixtureDrink>[]> = { a: [drinks[0]!], b: [drinks[1]!], c: [drinks[2]!] };
    const { gateway: gatewayA } = fakeGateway(planA);
    const fakeA = createFakeTimers();
    const refresherA = new CatalogRefresher({ db: dbA.db, gateway: gatewayA, clock: () => new Date(CLOCK_START), letterPauseMs: 0, timers: fakeA.timers });
    await flushRefresh(refresherA.refresh(), fakeA);

    // Same three drinks, but distributed under entirely different letters.
    const planB: Record<string, ReturnType<typeof fixtureDrink>[]> = { m: [drinks[0]!], o: [drinks[1]!], x: [drinks[2]!] };
    const { gateway: gatewayB } = fakeGateway(planB);
    const fakeB = createFakeTimers();
    const refresherB = new CatalogRefresher({ db: dbB.db, gateway: gatewayB, clock: () => new Date(CLOCK_START), letterPauseMs: 0, timers: fakeB.timers });
    await flushRefresh(refresherB.refresh(), fakeB);

    const stateA = await readCatalogState(dbA.db);
    const stateB = await readCatalogState(dbB.db);
    assert.ok(stateA && stateB);
    assert.equal(stateA!.version, stateB!.version);
  } finally {
    await dbA.cleanup();
    await dbB.cleanup();
  }
});

test('unchanged data on a second run moves only checkedAt, never publishedAt or version', async () => {
  const { db, cleanup } = await createCatalogTestDb();
  try {
    const plan = fullCatalogPlan();
    const clock = mutableClock(CLOCK_START);

    const { gateway: gateway1 } = fakeGateway(plan);
    const fake1 = createFakeTimers();
    const refresher1 = new CatalogRefresher({ db, gateway: gateway1, clock: clock.clock, letterPauseMs: 0, timers: fake1.timers });
    await flushRefresh(refresher1.refresh(), fake1);
    const first = await readCatalogState(db);
    assert.ok(first);

    clock.set('2026-09-15T08:00:00.000Z');
    const { gateway: gateway2 } = fakeGateway(plan);
    const fake2 = createFakeTimers();
    const refresher2 = new CatalogRefresher({ db, gateway: gateway2, clock: clock.clock, letterPauseMs: 0, timers: fake2.timers });
    await flushRefresh(refresher2.refresh(), fake2);
    const second = await readCatalogState(db);

    assert.equal(second!.version, first!.version);
    assert.equal(second!.publishedAt, first!.publishedAt);
    assert.equal(second!.checkedAt, '2026-09-15T08:00:00.000Z');
  } finally {
    await cleanup();
  }
});

test('one failing letter keeps the previous snapshot and records an error code', async () => {
  const { db, cleanup } = await createCatalogTestDb();
  try {
    const clock = mutableClock(CLOCK_START);
    const { gateway: gateway1 } = fakeGateway(fullCatalogPlan());
    const fake1 = createFakeTimers();
    const refresher1 = new CatalogRefresher({ db, gateway: gateway1, clock: clock.clock, letterPauseMs: 0, timers: fake1.timers });
    await flushRefresh(refresher1.refresh(), fake1);
    const before = await readCatalogState(db);
    const beforeRows = await readCatalogRecipes(db);

    clock.set('2026-09-15T08:00:00.000Z');
    const failingPlan = fullCatalogPlan();
    failingPlan.m = 'fail';
    const { gateway: gateway2 } = fakeGateway(failingPlan);
    const fake2 = createFakeTimers();
    const refresher2 = new CatalogRefresher({ db, gateway: gateway2, clock: clock.clock, letterPauseMs: 0, timers: fake2.timers });
    await flushRefresh(refresher2.refresh(), fake2);

    const after = await readCatalogState(db);
    const afterRows = await readCatalogRecipes(db);
    assert.equal(after!.version, before!.version);
    assert.equal(after!.publishedAt, before!.publishedAt);
    assert.equal(after!.recipeCount, before!.recipeCount);
    assert.deepEqual(afterRows, beforeRows);
    assert.equal(after!.checkedAt, '2026-09-15T08:00:00.000Z');
    assert.equal(after!.lastErrorCode, 'upstream_unavailable');
  } finally {
    await cleanup();
  }
});

test('a first-run failure publishes nothing and leaves no snapshot row', async () => {
  const { db, cleanup } = await createCatalogTestDb();
  try {
    const plan = fullCatalogPlan();
    plan.g = 'fail';
    const { gateway } = fakeGateway(plan);
    const fake = createFakeTimers();
    const refresher = new CatalogRefresher({ db, gateway, clock: () => new Date(CLOCK_START), letterPauseMs: 0, timers: fake.timers });
    await flushRefresh(refresher.refresh(), fake);
    assert.equal(await readCatalogState(db), undefined);
  } finally {
    await cleanup();
  }
});

test('a 429 cooldown from the gateway is treated as a failure, not a crash', async () => {
  const { GatewayError } = await import('../src/gateway.js');
  const { db, cleanup } = await createCatalogTestDb();
  try {
    const gateway = {
      async get(operation: { value: string }) {
        if (operation.value === 'd') throw new GatewayError('rate_limited', 429, 12);
        return JSON.stringify({ drinks: null });
      },
    };
    let failureCode: string | undefined;
    const fake = createFakeTimers();
    const refresher = new CatalogRefresher({
      db, gateway, clock: () => new Date(CLOCK_START), letterPauseMs: 0, timers: fake.timers,
      onFailure: (code) => { failureCode = code; },
    });
    await flushRefresh(refresher.refresh(), fake);
    assert.equal(failureCode, 'rate_limited');
    assert.equal(await readCatalogState(db), undefined);
  } finally {
    await cleanup();
  }
});

test('a zero-drink total is a failure, never an empty publish', async () => {
  const { db, cleanup } = await createCatalogTestDb();
  try {
    const { gateway } = fakeGateway({});
    let failureCode: string | undefined;
    const fake = createFakeTimers();
    const refresher = new CatalogRefresher({
      db, gateway, clock: () => new Date(CLOCK_START), letterPauseMs: 0, timers: fake.timers,
      onFailure: (code) => { failureCode = code; },
    });
    await flushRefresh(refresher.refresh(), fake);
    assert.equal(failureCode, 'empty_catalog');
    assert.equal(await readCatalogState(db), undefined);
  } finally {
    await cleanup();
  }
});

test('overlapping refresh calls share one run instead of starting a second', async () => {
  const { db, cleanup } = await createCatalogTestDb();
  try {
    const { gateway, calls } = fakeGateway(fullCatalogPlan());
    const fake = createFakeTimers();
    const refresher = new CatalogRefresher({ db, gateway, clock: () => new Date(CLOCK_START), letterPauseMs: 5, timers: fake.timers });

    const first = refresher.refresh();
    const second = refresher.refresh();
    assert.equal(first, second, 'a concurrent call must return the same in-flight promise');

    await flushRefresh(first, fake);
    assert.equal(calls.length, 26, 'only one run worth of letter calls should have happened');
  } finally {
    await cleanup();
  }
});

test('close() during a run stops promptly and publishes nothing', async () => {
  const { db, cleanup } = await createCatalogTestDb();
  try {
    const { gateway, calls } = fakeGateway(fullCatalogPlan());
    const fake = createFakeTimers();
    const refresher = new CatalogRefresher({ db, gateway, clock: () => new Date(CLOCK_START), letterPauseMs: 1000, timers: fake.timers });

    const run = refresher.refresh();
    // Let the first letter resolve and the pause timer get registered, but
    // never fire it — this is the "mid-run" state close() must interrupt.
    await flushMicrotasks(10);
    assert.equal(calls.length, 1);
    assert.equal(fake.pendingTimeouts(), 1);

    await refresher.close();
    await run;

    assert.equal(calls.length, 1, 'no further letters should be fetched after close()');
    assert.equal(fake.pendingTimeouts(), 0);
    assert.equal(await readCatalogState(db), undefined);
  } finally {
    await cleanup();
  }
});

test('24h scheduling: start() schedules an immediate run with no snapshot, defers when checkedAt is fresh, and the scheduled timer fires the next check', async () => {
  const { db, cleanup } = await createCatalogTestDb();
  try {
    const intervalMs = 24 * 60 * 60 * 1000;
    const fake = createFakeTimers();
    const clock = mutableClock(CLOCK_START);
    const { gateway, calls } = fakeGateway(fullCatalogPlan());
    const refresher = new CatalogRefresher({ db, gateway, clock: clock.clock, intervalMs, letterPauseMs: 0, timers: fake.timers });

    // No published snapshot: start() must schedule a due-now (0ms) timer.
    await refresher.start();
    assert.equal(fake.pendingTimeouts(), 1);
    assert.equal(fake.lastDelay(), 0);
    fake.fireTimeouts();
    await flushRefresh(refresher.refresh(), fake);
    assert.ok(calls.length > 0, 'expected an immediate refresh with no prior snapshot');
    // A successful run reschedules a fresh 24h-out timer, not a recurring interval.
    assert.equal(fake.pendingTimeouts(), 1);
    assert.equal(fake.lastDelay(), intervalMs);

    // A second refresher, same db, checkedAt is now fresh: the next check is
    // scheduled far out, not due now.
    const fake2 = createFakeTimers();
    const { gateway: gateway2, calls: calls2 } = fakeGateway(fullCatalogPlan());
    clock.set('2026-09-14T09:00:00.000Z');
    const refresher2 = new CatalogRefresher({ db, gateway: gateway2, clock: clock.clock, intervalMs, letterPauseMs: 0, timers: fake2.timers });
    await refresher2.start();
    assert.equal(fake2.pendingTimeouts(), 1);
    assert.ok(fake2.lastDelay()! > 0 && fake2.lastDelay()! <= intervalMs);
    await flushMicrotasks(20);
    assert.equal(calls2.length, 0, 'a recent checkedAt must not trigger an immediate refresh');

    // Firing the scheduled timer triggers the next check.
    fake2.fireTimeouts();
    await flushRefresh(refresher2.refresh(), fake2);
    assert.ok(calls2.length > 0, 'the scheduled timer must trigger a refresh');

    await refresher.close();
    assert.equal(fake.pendingTimeouts(), 0, 'close() must clear the pending scheduled timer');
    await refresher2.close();
  } finally {
    await cleanup();
  }
});

test('a failed run schedules a retry well before the full interval, not a 24h wait', async () => {
  const { db, cleanup } = await createCatalogTestDb();
  try {
    const intervalMs = 24 * 60 * 60 * 1000;
    const failingPlan = fullCatalogPlan();
    failingPlan.m = 'fail';
    const { gateway } = fakeGateway(failingPlan);
    const fake = createFakeTimers();
    const refresher = new CatalogRefresher({ db, gateway, clock: () => new Date(CLOCK_START), intervalMs, letterPauseMs: 0, timers: fake.timers });

    await flushRefresh(refresher.refresh(), fake);

    // The refresh's own retry timer is the only one left pending once its
    // internal letter-pause timeouts have all been drained.
    assert.equal(fake.pendingTimeouts(), 1);
    const delay = fake.lastDelay()!;
    assert.ok(delay > 0 && delay < intervalMs, `expected a bounded backoff retry, got ${delay}ms`);
    assert.ok(delay <= 5 * 60 * 1000, `expected the first retry within the 5-minute base backoff, got ${delay}ms`);
    await refresher.close();
  } finally {
    await cleanup();
  }
});

test('backoff doubles across consecutive failures and is capped at the interval', async () => {
  const { db, cleanup } = await createCatalogTestDb();
  try {
    const intervalMs = 5000; // small on purpose so the cap is reached in a few doublings
    const failingPlan = fullCatalogPlan();
    failingPlan.m = 'fail';
    const fake = createFakeTimers();
    const refresher = new CatalogRefresher({
      db, gateway: fakeGateway(failingPlan).gateway, clock: () => new Date(CLOCK_START),
      intervalMs, letterPauseMs: 0, backoffBaseMs: 1000, timers: fake.timers,
    });

    await flushRefresh(refresher.refresh(), fake);
    assert.equal(fake.lastDelay(), 1000, 'first failure retries at the base backoff');

    fake.fireTimeouts();
    await flushRefresh(refresher.refresh(), fake);
    assert.equal(fake.lastDelay(), 2000, 'second consecutive failure doubles the backoff');

    fake.fireTimeouts();
    await flushRefresh(refresher.refresh(), fake);
    assert.equal(fake.lastDelay(), 4000, 'third consecutive failure doubles again');

    // The fourth doubling (8000ms) would exceed the 5000ms interval: it must cap there instead.
    fake.fireTimeouts();
    await flushRefresh(refresher.refresh(), fake);
    assert.equal(fake.lastDelay(), intervalMs, 'backoff must never exceed the success interval');

    // And stays capped on further consecutive failures.
    fake.fireTimeouts();
    await flushRefresh(refresher.refresh(), fake);
    assert.equal(fake.lastDelay(), intervalMs, 'backoff stays capped, not still doubling');
    await refresher.close();
  } finally {
    await cleanup();
  }
});

test('backoff resets to the base after a successful run following failures', async () => {
  const { db, cleanup } = await createCatalogTestDb();
  try {
    const intervalMs = 30 * 60 * 1000;
    const failingPlan = fullCatalogPlan();
    failingPlan.m = 'fail';
    let impl = fakeGateway(failingPlan).gateway;
    const swappableGateway = { get: (op: Parameters<typeof impl.get>[0]) => impl.get(op) };
    const fake = createFakeTimers();
    const refresher = new CatalogRefresher({
      db, gateway: swappableGateway, clock: () => new Date(CLOCK_START),
      intervalMs, letterPauseMs: 0, backoffBaseMs: 1000, timers: fake.timers,
    });
    await flushRefresh(refresher.refresh(), fake);
    assert.equal(fake.lastDelay(), 1000);
    fake.fireTimeouts();
    await flushRefresh(refresher.refresh(), fake);
    assert.equal(fake.lastDelay(), 2000);

    // Swap in a gateway that now succeeds fully.
    impl = fakeGateway(fullCatalogPlan()).gateway;
    fake.fireTimeouts();
    await flushRefresh(refresher.refresh(), fake);
    assert.equal(fake.lastDelay(), intervalMs, 'a success reschedules the full interval');

    // Fail again immediately after: backoff must have reset to the base, not
    // continued doubling from before the success.
    impl = fakeGateway(failingPlan).gateway;
    fake.fireTimeouts();
    await flushRefresh(refresher.refresh(), fake);
    assert.equal(fake.lastDelay(), 1000, 'backoff must reset to the base after a success');
    await refresher.close();
  } finally {
    await cleanup();
  }
});

test('a gateway retryAfter longer than the computed backoff wins', async () => {
  const { GatewayError } = await import('../src/gateway.js');
  const { db, cleanup } = await createCatalogTestDb();
  try {
    const intervalMs = 24 * 60 * 60 * 1000;
    const gateway = {
      async get(operation: { value: string }) {
        if (operation.value === 'd') throw new GatewayError('rate_limited', 429, 900); // 900s = 15 min
        return JSON.stringify({ drinks: null });
      },
    };
    const fake = createFakeTimers();
    const refresher = new CatalogRefresher({
      db, gateway, clock: () => new Date(CLOCK_START), intervalMs, letterPauseMs: 0, backoffBaseMs: 1000, timers: fake.timers,
    });
    await flushRefresh(refresher.refresh(), fake);
    assert.equal(fake.lastDelay(), 900 * 1000, 'a longer retryAfter overrides the shorter computed backoff');
    await refresher.close();
  } finally {
    await cleanup();
  }
});

test('restarting after a failed check retries promptly, even though checked_at is recent', async () => {
  const { db, cleanup } = await createCatalogTestDb();
  try {
    const intervalMs = 24 * 60 * 60 * 1000;
    const clock = mutableClock(CLOCK_START);

    // A successful publish first, so there is a snapshot row for a later
    // failed check to record its error code against.
    const fakeSeed = createFakeTimers();
    const seed = new CatalogRefresher({ db, gateway: fakeGateway(fullCatalogPlan()).gateway, clock: clock.clock, intervalMs, letterPauseMs: 0, timers: fakeSeed.timers });
    await flushRefresh(seed.refresh(), fakeSeed);
    await seed.close();

    const failingPlan = fullCatalogPlan();
    failingPlan.m = 'fail';
    clock.set('2026-09-15T08:00:00.000Z');
    const fake1 = createFakeTimers();
    const refresher1 = new CatalogRefresher({ db, gateway: fakeGateway(failingPlan).gateway, clock: clock.clock, intervalMs, letterPauseMs: 0, timers: fake1.timers });
    await flushRefresh(refresher1.refresh(), fake1);
    const state = await readCatalogState(db);
    assert.equal(state!.lastErrorCode, 'upstream_unavailable');
    await refresher1.close();

    // A brand-new refresher instance (simulating a server restart) a minute
    // later — checked_at is fresh by the clock, but the last check failed.
    clock.set('2026-09-14T08:01:00.000Z');
    const fake2 = createFakeTimers();
    const refresher2 = new CatalogRefresher({ db, gateway: fakeGateway(fullCatalogPlan()).gateway, clock: clock.clock, intervalMs, letterPauseMs: 0, timers: fake2.timers });
    await refresher2.start();
    assert.equal(fake2.pendingTimeouts(), 1);
    assert.equal(fake2.lastDelay(), 0, 'a failed last check must be treated as stale regardless of checked_at age');
    await refresher2.close();
  } finally {
    await cleanup();
  }
});
