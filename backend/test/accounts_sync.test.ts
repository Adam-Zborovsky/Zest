import test from 'node:test';
import assert from 'node:assert/strict';
import { randomBytes } from 'node:crypto';
import { createTestApp, PNG_BYTES } from './support/accounts_test_app.js';

function entryId(): string {
  return randomBytes(16).toString('hex');
}

function savedEntry(overrides: Record<string, unknown> = {}) {
  return {
    id: entryId(), kind: 'saved', sourceRecipeId: '98001',
    source: { idDrink: '98001', strDrink: 'Testbench Tonic' },
    variation: null, day: '2026-09-13', hasPhoto: false, photoUpdatedAt: null,
    createdAt: '2026-09-13T10:00:00.000Z', updatedAt: '2026-09-13T10:00:00.000Z', deleted: false,
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

test('PUT stores a new entry and returns it with an assigned revision', async () => {
  const harness = await createTestApp();
  try {
    const token = await registerUser(harness.app, 'a@example.test');
    const entry = savedEntry();
    const response = await harness.app.inject({ method: 'PUT', url: `/api/entries/${entry.id}`, headers: auth(token), payload: entry });
    assert.equal(response.statusCode, 200);
    const body = response.json();
    assert.equal(body.id, entry.id);
    assert.equal(body.revision, 1);
    assert.equal(body.deleted, false);
  } finally { await harness.cleanup(); }
});

test('last-edit-wins: a newer update applies, an equal or older one does not, and a retry is idempotent', async () => {
  const harness = await createTestApp();
  try {
    const token = await registerUser(harness.app, 'a@example.test');
    const entry = savedEntry({ updatedAt: '2026-09-13T10:00:00.000Z' });
    const first = await harness.app.inject({ method: 'PUT', url: `/api/entries/${entry.id}`, headers: auth(token), payload: entry });
    assert.equal(first.json().revision, 1);

    const older = { ...entry, day: '2026-09-01', updatedAt: '2026-09-13T09:00:00.000Z' };
    const olderResponse = await harness.app.inject({ method: 'PUT', url: `/api/entries/${entry.id}`, headers: auth(token), payload: older });
    assert.equal(olderResponse.json().revision, 1);
    assert.equal(olderResponse.json().day, '2026-09-13');

    const equal = { ...entry, day: '2026-09-02' };
    const equalResponse = await harness.app.inject({ method: 'PUT', url: `/api/entries/${entry.id}`, headers: auth(token), payload: equal });
    assert.equal(equalResponse.json().day, '2026-09-13');
    assert.equal(equalResponse.json().revision, 1);

    const newer = { ...entry, day: '2026-09-14', updatedAt: '2026-09-13T11:00:00.000Z' };
    const newerResponse = await harness.app.inject({ method: 'PUT', url: `/api/entries/${entry.id}`, headers: auth(token), payload: newer });
    assert.equal(newerResponse.json().day, '2026-09-14');
    assert.equal(newerResponse.json().revision, 2);

    const retry = await harness.app.inject({ method: 'PUT', url: `/api/entries/${entry.id}`, headers: auth(token), payload: newer });
    assert.equal(retry.json().revision, 2);
    assert.equal(retry.json().day, '2026-09-14');
  } finally { await harness.cleanup(); }
});

test('tombstones are final: a later non-deleted PUT cannot resurrect a deleted entry', async () => {
  const harness = await createTestApp();
  try {
    const token = await registerUser(harness.app, 'a@example.test');
    const entry = savedEntry();
    await harness.app.inject({ method: 'PUT', url: `/api/entries/${entry.id}`, headers: auth(token), payload: entry });

    const tombstone = { ...entry, source: null, variation: null, updatedAt: '2026-09-13T11:00:00.000Z', deleted: true };
    const deleteResponse = await harness.app.inject({ method: 'PUT', url: `/api/entries/${entry.id}`, headers: auth(token), payload: tombstone });
    assert.equal(deleteResponse.json().deleted, true);
    assert.equal(deleteResponse.json().revision, 2);

    const revive = { ...entry, updatedAt: '2026-09-13T12:00:00.000Z', deleted: false };
    const reviveResponse = await harness.app.inject({ method: 'PUT', url: `/api/entries/${entry.id}`, headers: auth(token), payload: revive });
    assert.equal(reviveResponse.json().deleted, true);
    assert.equal(reviveResponse.json().revision, 2);
    assert.equal(reviveResponse.json().source, null);
  } finally { await harness.cleanup(); }
});

test('a future updatedAt more than 24 hours ahead is rejected', async () => {
  const harness = await createTestApp();
  try {
    const token = await registerUser(harness.app, 'a@example.test');
    const entry = savedEntry({ updatedAt: '2026-09-15T13:00:01.000Z' }); // >24h past 2026-09-13T12:00:00Z clock
    const response = await harness.app.inject({ method: 'PUT', url: `/api/entries/${entry.id}`, headers: auth(token), payload: entry });
    assert.equal(response.statusCode, 400);
    assert.equal(response.json().error.code, 'invalid_request');

    const withinSkew = savedEntry({ updatedAt: '2026-09-14T11:59:00.000Z' }); // <24h ahead
    const ok = await harness.app.inject({ method: 'PUT', url: `/api/entries/${withinSkew.id}`, headers: auth(token), payload: withinSkew });
    assert.equal(ok.statusCode, 200);
  } finally { await harness.cleanup(); }
});

test('an entry that does not exist, belongs to another user, or is deleted gets 404, never 403', async () => {
  const harness = await createTestApp();
  try {
    const tokenA = await registerUser(harness.app, 'a@example.test');
    const tokenB = await registerUser(harness.app, 'b@example.test');
    const entry = savedEntry();
    await harness.app.inject({ method: 'PUT', url: `/api/entries/${entry.id}`, headers: auth(tokenA), payload: entry });

    const missing = await harness.app.inject({ method: 'PUT', url: `/api/entries/${entryId()}/photo?updatedAt=2026-09-13T10:00:00.000Z`,
      headers: { ...auth(tokenA), 'content-type': 'image/png' }, payload: PNG_BYTES });
    assert.equal(missing.statusCode, 404);

    const crossUserPhoto = await harness.app.inject({ method: 'GET', url: `/api/entries/${entry.id}/photo`, headers: auth(tokenB) });
    assert.equal(crossUserPhoto.statusCode, 404);
  } finally { await harness.cleanup(); }
});

test('pull never returns another user\'s rows and filters correctly by since/limit', async () => {
  const harness = await createTestApp();
  try {
    const tokenA = await registerUser(harness.app, 'a@example.test');
    const tokenB = await registerUser(harness.app, 'b@example.test');
    const entryA = savedEntry();
    const entryB = savedEntry();
    await harness.app.inject({ method: 'PUT', url: `/api/entries/${entryA.id}`, headers: auth(tokenA), payload: entryA });
    await harness.app.inject({ method: 'PUT', url: `/api/entries/${entryB.id}`, headers: auth(tokenB), payload: entryB });

    const pullA = await harness.app.inject({ method: 'GET', url: '/api/sync/entries?since=0', headers: auth(tokenA) });
    const body = pullA.json();
    assert.equal(body.entries.length, 1);
    assert.equal(body.entries[0].id, entryA.id);
  } finally { await harness.cleanup(); }
});

test('pull orders ascending by revision, pages with hasMore, and resumes from `revision`', async () => {
  const harness = await createTestApp();
  try {
    const token = await registerUser(harness.app, 'a@example.test');
    const ids: string[] = [];
    for (let i = 0; i < 5; i++) {
      const entry = savedEntry({ updatedAt: `2026-09-13T10:0${i}:00.000Z` });
      ids.push(entry.id);
      await harness.app.inject({ method: 'PUT', url: `/api/entries/${entry.id}`, headers: auth(token), payload: entry });
    }
    const firstPage = await harness.app.inject({ method: 'GET', url: '/api/sync/entries?since=0&limit=2', headers: auth(token) });
    const firstBody = firstPage.json();
    assert.equal(firstBody.entries.length, 2);
    assert.equal(firstBody.hasMore, true);
    assert.deepEqual(firstBody.entries.map((entry: { revision: number }) => entry.revision), [1, 2]);

    const secondPage = await harness.app.inject({ method: 'GET', url: `/api/sync/entries?since=${firstBody.revision}&limit=2`, headers: auth(token) });
    const secondBody = secondPage.json();
    assert.equal(secondBody.entries.length, 2);
    assert.equal(secondBody.hasMore, true);

    const lastPage = await harness.app.inject({ method: 'GET', url: `/api/sync/entries?since=${secondBody.revision}&limit=2`, headers: auth(token) });
    assert.equal(lastPage.json().entries.length, 1);
    assert.equal(lastPage.json().hasMore, false);
  } finally { await harness.cleanup(); }
});

test('the per-user revision counter increases strictly across concurrent PUTs', async () => {
  const harness = await createTestApp();
  try {
    const token = await registerUser(harness.app, 'a@example.test');
    const entries = Array.from({ length: 8 }, () => savedEntry());
    const responses = await Promise.all(entries.map((entry) =>
      harness.app.inject({ method: 'PUT', url: `/api/entries/${entry.id}`, headers: auth(token), payload: entry })));
    const revisions = responses.map((response) => response.json().revision as number).sort((a, b) => a - b);
    assert.deepEqual(revisions, [1, 2, 3, 4, 5, 6, 7, 8]);
  } finally { await harness.cleanup(); }
});

test('a variation entry round-trips its variation payload', async () => {
  const harness = await createTestApp();
  try {
    const token = await registerUser(harness.app, 'a@example.test');
    const entry = savedEntry({
      kind: 'variation',
      variation: { name: 'My Twist', ingredients: [{ name: 'Gin', measure: '2 oz' }], method: 'Shake it.', notes: 'Extra citrusy.' },
    });
    const response = await harness.app.inject({ method: 'PUT', url: `/api/entries/${entry.id}`, headers: auth(token), payload: entry });
    assert.equal(response.statusCode, 200);
    assert.deepEqual(response.json().variation, entry.variation);
  } finally { await harness.cleanup(); }
});

test('the path id must match the body id', async () => {
  const harness = await createTestApp();
  try {
    const token = await registerUser(harness.app, 'a@example.test');
    const entry = savedEntry();
    const response = await harness.app.inject({ method: 'PUT', url: `/api/entries/${entryId()}`, headers: auth(token), payload: entry });
    assert.equal(response.statusCode, 400);
  } finally { await harness.cleanup(); }
});
