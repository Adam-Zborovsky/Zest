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

test('24h scheduling: start() refreshes immediately with no snapshot, skips when checkedAt is fresh, and fires on the interval', async () => {
  const { db, cleanup } = await createCatalogTestDb();
  try {
    const intervalMs = 24 * 60 * 60 * 1000;
    const fake = createFakeTimers();
    const clock = mutableClock(CLOCK_START);
    const { gateway, calls } = fakeGateway(fullCatalogPlan());
    const refresher = new CatalogRefresher({ db, gateway, clock: clock.clock, intervalMs, letterPauseMs: 0, timers: fake.timers });

    // No published snapshot: start() must refresh right away. refresh()
    // returns the same in-flight promise start() already kicked off.
    await refresher.start();
    await flushRefresh(refresher.refresh(), fake);
    assert.ok(calls.length > 0, 'expected an immediate refresh with no prior snapshot');
    assert.equal(fake.pendingIntervals(), 1);

    // A second refresher, same db, checkedAt is now fresh: no immediate run.
    const fake2 = createFakeTimers();
    const { gateway: gateway2, calls: calls2 } = fakeGateway(fullCatalogPlan());
    clock.set('2026-09-14T09:00:00.000Z');
    const refresher2 = new CatalogRefresher({ db, gateway: gateway2, clock: clock.clock, intervalMs, letterPauseMs: 0, timers: fake2.timers });
    await refresher2.start();
    await flushMicrotasks(20);
    assert.equal(calls2.length, 0, 'a recent checkedAt must not trigger an immediate refresh');

    // Firing the interval callback triggers another refresh.
    fake2.fireIntervals();
    await flushRefresh(refresher2.refresh(), fake2);
    assert.ok(calls2.length > 0, 'the 24h interval must trigger a refresh');

    await refresher.close();
    assert.equal(fake.pendingIntervals(), 0, 'close() must clear the recurring timer');
    await refresher2.close();
  } finally {
    await cleanup();
  }
});
