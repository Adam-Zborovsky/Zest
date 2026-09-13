import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import path from 'node:path';
import type { AuthResponse, EntryRecord, ErrorResponse, SyncPageResponse } from '../src/accounts/contract.js';

const FIXTURES_DIR = path.join(process.cwd(), '..', 'contract', 'accounts');

async function readFixture<T>(name: string): Promise<T> {
  return JSON.parse(await readFile(path.join(FIXTURES_DIR, name), 'utf8')) as T;
}

function assertUser(user: { id: string; email: string; createdAt: string }) {
  assert.match(user.id, /^[0-9a-f-]{36}$/);
  assert.match(user.email, /^[^\s@]+@[^\s@]+$/);
  assert.ok(!Number.isNaN(Date.parse(user.createdAt)));
}

function assertEntry(entry: EntryRecord) {
  assert.match(entry.id, /^[0-9a-f]{32}$/);
  assert.ok(entry.kind === 'saved' || entry.kind === 'variation');
  assert.match(entry.sourceRecipeId, /^[0-9]{1,20}$/);
  assert.match(entry.day, /^\d{4}-\d{2}-\d{2}$/);
  assert.equal(typeof entry.hasPhoto, 'boolean');
  assert.equal(typeof entry.deleted, 'boolean');
  assert.ok(!Number.isNaN(Date.parse(entry.createdAt)));
  assert.ok(!Number.isNaN(Date.parse(entry.updatedAt)));
  assert.equal(typeof entry.revision, 'number');
  if (entry.deleted) {
    assert.equal(entry.source, null);
    assert.equal(entry.variation, null);
    assert.equal(entry.hasPhoto, false);
    assert.equal(entry.photoUpdatedAt, null);
  }
  if (entry.kind === 'variation' && !entry.deleted) {
    assert.ok(entry.variation);
    assert.equal(typeof entry.variation!.name, 'string');
    assert.ok(Array.isArray(entry.variation!.ingredients));
  }
}

test('account-session.json parses as an AuthResponse', async () => {
  const fixture = await readFixture<AuthResponse>('account-session.json');
  assertUser(fixture.user);
  assert.ok(fixture.session.token.length > 0);
  assert.ok(!Number.isNaN(Date.parse(fixture.session.expiresAt)));
});

test('entry-saved.json and entry-variation.json parse as EntryRecord', async () => {
  assertEntry(await readFixture<EntryRecord>('entry-saved.json'));
  assertEntry(await readFixture<EntryRecord>('entry-variation.json'));
});

test('entry-deleted.json parses as a final tombstone EntryRecord', async () => {
  const fixture = await readFixture<EntryRecord>('entry-deleted.json');
  assertEntry(fixture);
  assert.equal(fixture.deleted, true);
});

test('sync-page.json parses as a SyncPageResponse', async () => {
  const fixture = await readFixture<SyncPageResponse>('sync-page.json');
  assert.ok(Array.isArray(fixture.entries));
  fixture.entries.forEach(assertEntry);
  assert.equal(typeof fixture.revision, 'number');
  assert.equal(typeof fixture.hasMore, 'boolean');
});

test('error-rate-limited.json parses as an ErrorResponse', async () => {
  const fixture = await readFixture<ErrorResponse>('error-rate-limited.json');
  assert.equal(fixture.error.code, 'rate_limited');
  assert.equal(typeof fixture.error.message, 'string');
});
