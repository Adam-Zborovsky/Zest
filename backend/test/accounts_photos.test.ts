import test from 'node:test';
import assert from 'node:assert/strict';
import { randomBytes } from 'node:crypto';
import { createTestApp, JPEG_BYTES, PNG_BYTES } from './support/accounts_test_app.js';
import { setEntryPhoto } from '../src/accounts/repository.js';
import { sniffPhotoType } from '../src/accounts/photos.js';
import { AccountLimits } from '../src/accounts/contract.js';

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

async function registerAndSaveEntry(harness: Awaited<ReturnType<typeof createTestApp>>) {
  const registerResponse = await harness.app.inject({ method: 'POST', url: '/api/auth/register', payload: { email: 'a@example.test', password: 'correct-horse-battery' } });
  const token = registerResponse.json().session.token as string;
  const entry = savedEntry();
  await harness.app.inject({ method: 'PUT', url: `/api/entries/${entry.id}`, headers: { authorization: `Bearer ${token}` }, payload: entry });
  return { token, entry };
}

function auth(token: string) {
  return { authorization: `Bearer ${token}` };
}

test('setting a photo updates hasPhoto/photoUpdatedAt, bumps revision, and serves the bytes back', async () => {
  const harness = await createTestApp();
  try {
    const { token, entry } = await registerAndSaveEntry(harness);
    const put = await harness.app.inject({
      method: 'PUT', url: `/api/entries/${entry.id}/photo?updatedAt=2026-09-13T10:30:00.000Z`,
      headers: { ...auth(token), 'content-type': 'image/jpeg' }, payload: JPEG_BYTES,
    });
    assert.equal(put.statusCode, 200);
    assert.equal(put.json().hasPhoto, true);
    assert.equal(put.json().photoUpdatedAt, '2026-09-13T10:30:00.000Z');
    assert.equal(put.json().revision, 2);

    const get = await harness.app.inject({ method: 'GET', url: `/api/entries/${entry.id}/photo`, headers: auth(token) });
    assert.equal(get.statusCode, 200);
    assert.equal(get.headers['content-type'], 'image/jpeg');
    assert.equal(get.headers['cache-control'], 'private, no-store');
    assert.deepEqual(get.rawPayload, JPEG_BYTES);
  } finally { await harness.cleanup(); }
});

test('a magic-byte mismatch is rejected as unsupported_media_type', async () => {
  const harness = await createTestApp();
  try {
    const { token, entry } = await registerAndSaveEntry(harness);
    const response = await harness.app.inject({
      method: 'PUT', url: `/api/entries/${entry.id}/photo?updatedAt=2026-09-13T10:30:00.000Z`,
      headers: { ...auth(token), 'content-type': 'image/png' }, payload: JPEG_BYTES,
    });
    assert.equal(response.statusCode, 415);
    assert.equal(response.json().error.code, 'unsupported_media_type');
  } finally { await harness.cleanup(); }
});

test('a photo body over 4 MiB is rejected as payload_too_large', async () => {
  const harness = await createTestApp();
  try {
    const { token, entry } = await registerAndSaveEntry(harness);
    const oversized = Buffer.concat([JPEG_BYTES, Buffer.alloc(AccountLimits.maxPhotoBytes)]);
    const response = await harness.app.inject({
      method: 'PUT', url: `/api/entries/${entry.id}/photo?updatedAt=2026-09-13T10:30:00.000Z`,
      headers: { ...auth(token), 'content-type': 'image/jpeg' }, payload: oversized,
    });
    assert.equal(response.statusCode, 413);
    assert.equal(response.json().error.code, 'payload_too_large');
  } finally { await harness.cleanup(); }
});

test('photo writes apply last-edit-wins on photoUpdatedAt', async () => {
  const harness = await createTestApp();
  try {
    const { token, entry } = await registerAndSaveEntry(harness);
    const first = await harness.app.inject({
      method: 'PUT', url: `/api/entries/${entry.id}/photo?updatedAt=2026-09-13T10:30:00.000Z`,
      headers: { ...auth(token), 'content-type': 'image/jpeg' }, payload: JPEG_BYTES,
    });
    assert.equal(first.json().revision, 2);

    const stale = await harness.app.inject({
      method: 'PUT', url: `/api/entries/${entry.id}/photo?updatedAt=2026-09-13T10:00:00.000Z`,
      headers: { ...auth(token), 'content-type': 'image/png' }, payload: PNG_BYTES,
    });
    assert.equal(stale.json().revision, 2);
    assert.equal(stale.json().photoUpdatedAt, '2026-09-13T10:30:00.000Z');

    const staleGet = await harness.app.inject({ method: 'GET', url: `/api/entries/${entry.id}/photo`, headers: auth(token) });
    assert.equal(staleGet.headers['content-type'], 'image/jpeg');

    const newer = await harness.app.inject({
      method: 'PUT', url: `/api/entries/${entry.id}/photo?updatedAt=2026-09-13T11:00:00.000Z`,
      headers: { ...auth(token), 'content-type': 'image/png' }, payload: PNG_BYTES,
    });
    assert.equal(newer.json().revision, 3);
    const newerGet = await harness.app.inject({ method: 'GET', url: `/api/entries/${entry.id}/photo`, headers: auth(token) });
    assert.equal(newerGet.headers['content-type'], 'image/png');
  } finally { await harness.cleanup(); }
});

test('DELETE clears a photo and removes the file; GET then 404s', async () => {
  const harness = await createTestApp();
  try {
    const { token, entry } = await registerAndSaveEntry(harness);
    await harness.app.inject({
      method: 'PUT', url: `/api/entries/${entry.id}/photo?updatedAt=2026-09-13T10:30:00.000Z`,
      headers: { ...auth(token), 'content-type': 'image/jpeg' }, payload: JPEG_BYTES,
    });
    const del = await harness.app.inject({ method: 'DELETE', url: `/api/entries/${entry.id}/photo?updatedAt=2026-09-13T11:00:00.000Z`, headers: auth(token) });
    assert.equal(del.statusCode, 200);
    assert.equal(del.json().hasPhoto, false);
    const get = await harness.app.inject({ method: 'GET', url: `/api/entries/${entry.id}/photo`, headers: auth(token) });
    assert.equal(get.statusCode, 404);
  } finally { await harness.cleanup(); }
});

test('deleting the entry removes its photo file and tombstones hide hasPhoto', async () => {
  const harness = await createTestApp();
  try {
    const { token, entry } = await registerAndSaveEntry(harness);
    await harness.app.inject({
      method: 'PUT', url: `/api/entries/${entry.id}/photo?updatedAt=2026-09-13T10:30:00.000Z`,
      headers: { ...auth(token), 'content-type': 'image/jpeg' }, payload: JPEG_BYTES,
    });
    const tombstone = { ...entry, source: null, variation: null, updatedAt: '2026-09-13T12:00:00.000Z', deleted: true };
    const deleteResponse = await harness.app.inject({ method: 'PUT', url: `/api/entries/${entry.id}`, headers: auth(token), payload: tombstone });
    assert.equal(deleteResponse.json().hasPhoto, false);
    assert.equal(deleteResponse.json().photoUpdatedAt, null);

    const get = await harness.app.inject({ method: 'GET', url: `/api/entries/${entry.id}/photo`, headers: auth(token) });
    assert.equal(get.statusCode, 404);
  } finally { await harness.cleanup(); }
});

test('GET photo 404s for an entry with no photo', async () => {
  const harness = await createTestApp();
  try {
    const { token, entry } = await registerAndSaveEntry(harness);
    const response = await harness.app.inject({ method: 'GET', url: `/api/entries/${entry.id}/photo`, headers: auth(token) });
    assert.equal(response.statusCode, 404);
  } finally { await harness.cleanup(); }
});

test('sniffPhotoType identifies jpeg/png/webp by magic bytes and rejects anything else', () => {
  assert.equal(sniffPhotoType(JPEG_BYTES), 'image/jpeg');
  assert.equal(sniffPhotoType(PNG_BYTES), 'image/png');
  const webp = Buffer.concat([Buffer.from('RIFF'), Buffer.from([0, 0, 0, 0]), Buffer.from('WEBP')]);
  assert.equal(sniffPhotoType(webp), 'image/webp');
  assert.equal(sniffPhotoType(Buffer.from('not an image')), null);
});

test('the photo quota rejects a write that would exceed the per-user limit', async () => {
  // AccountLimits.photoQuotaBytes is a fixed 512 MiB from the wire contract, far
  // too large to exercise over HTTP; setEntryPhoto takes quotaBytes as a plain
  // parameter, so the quota rule itself is tested directly at the repository level.
  const harness = await createTestApp();
  try {
    const registerResponse = await harness.app.inject({ method: 'POST', url: '/api/auth/register', payload: { email: 'owner@example.test', password: 'correct-horse-battery' } });
    const userId = registerResponse.json().user.id as string;
    const token = registerResponse.json().session.token as string;
    const entry = savedEntry();
    await harness.app.inject({ method: 'PUT', url: `/api/entries/${entry.id}`, headers: auth(token), payload: entry });

    const fits = await setEntryPhoto(harness.db, { userId, entryId: entry.id, updatedAt: '2026-09-13T10:00:00.000Z', mime: 'image/jpeg', bytes: 10, quotaBytes: 10 });
    assert.equal(fits.outcome, 'applied');

    const secondEntry = savedEntry();
    await harness.app.inject({ method: 'PUT', url: `/api/entries/${secondEntry.id}`, headers: auth(token), payload: secondEntry });
    const overQuota = await setEntryPhoto(harness.db, { userId, entryId: secondEntry.id, updatedAt: '2026-09-13T10:00:00.000Z', mime: 'image/jpeg', bytes: 1, quotaBytes: 10 });
    assert.equal(overQuota.outcome, 'quota_exceeded');
  } finally { await harness.cleanup(); }
});
