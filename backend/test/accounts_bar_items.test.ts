import test from 'node:test';
import assert from 'node:assert/strict';
import { randomBytes } from 'node:crypto';
import { createTestApp } from './support/accounts_test_app.js';

function savedEntry(overrides: Record<string, unknown> = {}) {
  return {
    id: randomBytes(16).toString('hex'), kind: 'saved', sourceRecipeId: '98001',
    source: { idDrink: '98001', strDrink: 'Testbench Tonic' }, variation: null,
    day: '2026-09-13', hasPhoto: false, photoUpdatedAt: null,
    createdAt: '2026-09-13T10:00:00.000Z', updatedAt: '2026-09-13T10:00:00.000Z', deleted: false,
    ...overrides,
  };
}

function barItem(overrides: Record<string, unknown> = {}) {
  return {
    ingredientId: 'fresh lime juice', displayName: 'Fresh lime juice', location: 'stocked',
    updatedAt: '2026-09-13T10:00:00.000Z', deleted: false,
    ...overrides,
  };
}

async function registerUser(app: Awaited<ReturnType<typeof createTestApp>>['app'], email: string) {
  const response = await app.inject({ method: 'POST', url: '/api/auth/register', payload: { email, password: 'correct-horse-battery' } });
  return response.json().session.token as string;
}

function auth(token: string) {
  return { authorization: `Bearer ${token}` };
}

function encodedIngredientPath(ingredientId: string): string {
  return `/api/bar-items/${encodeURIComponent(ingredientId)}`;
}

test('PUT accepts a decoded normalized route identity and returns the assigned home-bar revision', async () => {
  const harness = await createTestApp();
  try {
    const token = await registerUser(harness.app, 'a@example.test');
    const item = barItem();
    const response = await harness.app.inject({
      method: 'PUT', url: encodedIngredientPath(item.ingredientId), headers: auth(token), payload: item,
    });
    assert.equal(response.statusCode, 200);
    assert.deepEqual(response.json(), { ...item, revision: 1 });
  } finally { await harness.cleanup(); }
});

test('home-bar revisions are independent from collection-entry revisions', async () => {
  const harness = await createTestApp();
  try {
    const token = await registerUser(harness.app, 'a@example.test');
    const entry = savedEntry();
    assert.equal((await harness.app.inject({ method: 'PUT', url: `/api/entries/${entry.id}`, headers: auth(token), payload: entry })).json().revision, 1);

    const item = barItem();
    const barWrite = await harness.app.inject({ method: 'PUT', url: encodedIngredientPath(item.ingredientId), headers: auth(token), payload: item });
    assert.equal(barWrite.json().revision, 1);

    await harness.app.inject({
      method: 'PUT', url: `/api/entries/${entry.id}`, headers: auth(token),
      payload: { ...entry, updatedAt: '2026-09-13T10:01:00.000Z', day: '2026-09-14' },
    });
    const pull = await harness.app.inject({ method: 'GET', url: '/api/sync/bar-items?since=1', headers: auth(token) });
    assert.deepEqual(pull.json(), { items: [], revision: 1, hasMore: false });
  } finally { await harness.cleanup(); }
});

test('last edit wins strictly: equal and earlier writes are no-ops', async () => {
  const harness = await createTestApp();
  try {
    const token = await registerUser(harness.app, 'a@example.test');
    const item = barItem();
    await harness.app.inject({ method: 'PUT', url: encodedIngredientPath(item.ingredientId), headers: auth(token), payload: item });

    const equal = await harness.app.inject({
      method: 'PUT', url: encodedIngredientPath(item.ingredientId), headers: auth(token),
      payload: { ...item, displayName: 'Different spelling', location: 'shopping' },
    });
    assert.equal(equal.json().revision, 1);
    assert.equal(equal.json().location, 'stocked');

    const older = await harness.app.inject({
      method: 'PUT', url: encodedIngredientPath(item.ingredientId), headers: auth(token),
      payload: { ...item, updatedAt: '2026-09-13T09:59:59.999Z', location: 'shopping' },
    });
    assert.equal(older.json().revision, 1);

    const newer = await harness.app.inject({
      method: 'PUT', url: encodedIngredientPath(item.ingredientId), headers: auth(token),
      payload: { ...item, displayName: 'Lime juice, fresh', location: 'shopping', updatedAt: '2026-09-13T10:01:00.000Z' },
    });
    assert.deepEqual(newer.json(), {
      ...item, displayName: 'Lime juice, fresh', location: 'shopping', updatedAt: '2026-09-13T10:01:00.000Z', revision: 2,
    });
  } finally { await harness.cleanup(); }
});

test('a later explicit add restores a home-bar tombstone', async () => {
  const harness = await createTestApp();
  try {
    const token = await registerUser(harness.app, 'a@example.test');
    const item = barItem();
    await harness.app.inject({ method: 'PUT', url: encodedIngredientPath(item.ingredientId), headers: auth(token), payload: item });

    const tombstone = { ...item, deleted: true, updatedAt: '2026-09-13T10:01:00.000Z' };
    const removed = await harness.app.inject({ method: 'PUT', url: encodedIngredientPath(item.ingredientId), headers: auth(token), payload: tombstone });
    assert.deepEqual(removed.json(), { ...tombstone, revision: 2 });

    const restored = { ...item, displayName: 'Fresh Lime Juice', updatedAt: '2026-09-13T10:02:00.000Z' };
    const response = await harness.app.inject({ method: 'PUT', url: encodedIngredientPath(item.ingredientId), headers: auth(token), payload: restored });
    assert.deepEqual(response.json(), { ...restored, revision: 3 });

    const staleDelete = await harness.app.inject({ method: 'PUT', url: encodedIngredientPath(item.ingredientId), headers: auth(token), payload: tombstone });
    assert.equal(staleDelete.json().deleted, false);
    assert.equal(staleDelete.json().revision, 3);
  } finally { await harness.cleanup(); }
});

test('pull is isolated by user, ordered by home-bar revision, and pages from the returned cursor', async () => {
  const harness = await createTestApp();
  try {
    const tokenA = await registerUser(harness.app, 'a@example.test');
    const tokenB = await registerUser(harness.app, 'b@example.test');
    const names = ['gin', 'dry vermouth', 'orange bitters'];
    for (let index = 0; index < names.length; index += 1) {
      const item = barItem({ ingredientId: names[index], displayName: names[index], updatedAt: `2026-09-13T10:0${index}:00.000Z` });
      await harness.app.inject({ method: 'PUT', url: encodedIngredientPath(item.ingredientId), headers: auth(tokenA), payload: item });
    }
    const other = barItem({ ingredientId: 'tequila', displayName: 'Tequila' });
    await harness.app.inject({ method: 'PUT', url: encodedIngredientPath(other.ingredientId), headers: auth(tokenB), payload: other });

    const first = await harness.app.inject({ method: 'GET', url: '/api/sync/bar-items?since=0&limit=2', headers: auth(tokenA) });
    assert.equal(first.statusCode, 200);
    assert.deepEqual(first.json().items.map((item: { ingredientId: string; revision: number }) => [item.ingredientId, item.revision]), [
      ['gin', 1], ['dry vermouth', 2],
    ]);
    assert.equal(first.json().hasMore, true);

    const second = await harness.app.inject({ method: 'GET', url: `/api/sync/bar-items?since=${first.json().revision}&limit=2`, headers: auth(tokenA) });
    assert.deepEqual(second.json().items.map((item: { ingredientId: string; revision: number }) => [item.ingredientId, item.revision]), [['orange bitters', 3]]);
    assert.equal(second.json().hasMore, false);
  } finally { await harness.cleanup(); }
});

test('bar-item routes require authentication and strictly reject invalid identities and bodies', async () => {
  const harness = await createTestApp();
  try {
    const item = barItem();
    assert.equal((await harness.app.inject({ method: 'GET', url: '/api/sync/bar-items?since=0' })).statusCode, 401);
    assert.equal((await harness.app.inject({ method: 'PUT', url: encodedIngredientPath(item.ingredientId), payload: item })).statusCode, 401);

    const token = await registerUser(harness.app, 'a@example.test');
    const invalidRequests = [
      { url: encodedIngredientPath(item.ingredientId), payload: { ...item, ingredientId: 'lime juice' } },
      { url: '/api/bar-items/Dark%20Rum', payload: { ...item, ingredientId: 'dark rum' } },
      { url: '/api/bar-items/dark%20rums', payload: { ...item, ingredientId: 'dark rums' } },
      { url: '/api/bar-items/fresh%20%20lime%20juice', payload: item },
      { url: '/api/bar-items/%20', payload: item },
      { url: encodedIngredientPath(item.ingredientId), payload: { ...item, ingredientId: 'fresh\nlime juice' } },
      { url: encodedIngredientPath(item.ingredientId), payload: { ...item, displayName: 'Fresh\nlime juice' } },
      { url: encodedIngredientPath(item.ingredientId), payload: { ...item, location: 'cupboard' } },
      { url: encodedIngredientPath(item.ingredientId), payload: { ...item, updatedAt: 'not-a-date' } },
      { url: encodedIngredientPath(item.ingredientId), payload: { ...item, updatedAt: '2026-09-14T12:00:00.001Z' } },
      { url: encodedIngredientPath(item.ingredientId), payload: { ...item, displayName: 'x'.repeat(121) } },
      { url: encodedIngredientPath(item.ingredientId), payload: { ...item, revision: 1 } },
      { url: encodedIngredientPath(item.ingredientId), payload: { ...item, deleted: undefined } },
    ];
    for (const invalid of invalidRequests) {
      const response = await harness.app.inject({ method: 'PUT', url: invalid.url, headers: auth(token), payload: invalid.payload });
      assert.equal(response.statusCode, 400, invalid.url);
      assert.equal(response.json().error.code, 'invalid_request');
    }

    const tooLarge = await harness.app.inject({
      method: 'PUT', url: encodedIngredientPath(item.ingredientId), headers: auth(token),
      payload: { ...item, ignored: 'x'.repeat(20 * 1024) },
    });
    assert.equal(tooLarge.statusCode, 413);
    assert.equal(tooLarge.json().error.code, 'payload_too_large');
  } finally { await harness.cleanup(); }
});
