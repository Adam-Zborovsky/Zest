// Database operations for accounts, sessions, entries and photos.
// Every mutation to a user's entries runs in one transaction that locks the
// user row (SELECT ... FOR UPDATE) and increments a per-user revision counter,
// per docs/ACCOUNTS.md.
import { and, asc, eq, gt, sql } from 'drizzle-orm';
import type { Db } from './db.js';
import { barItems, entries, sessions, users } from './schema.js';
import type { EntryRecord, HomeBarItemRecord, VariationRecord } from './contract.js';
import type { ValidatedEntry, ValidatedHomeBarItem } from './validation.js';
import { photoPath, removePhotoFile } from './photos.js';

export class EmailTakenError extends Error {}

export interface StoredUser {
  id: string;
  email: string;
  passwordHash: string;
  revision: number;
  createdAt: string;
}

/**
 * Postgres/PGlite return timestamptz text in the session's own offset format
 * (e.g. "2026-09-13 12:30:00+02"), not the strict ISO-8601 UTC the wire
 * contract requires. Every timestamp read back from a row is normalized here
 * before it is ever exposed.
 */
function toIso(value: string): string {
  return new Date(value).toISOString();
}

function normalizeUser(row: typeof users.$inferSelect): StoredUser {
  return { ...row, createdAt: toIso(row.createdAt) };
}

export async function createUser(db: Db, params: { id: string; email: string; passwordHash: string; now: string }): Promise<StoredUser> {
  try {
    const [row] = await db.insert(users).values({
      id: params.id, email: params.email, passwordHash: params.passwordHash, revision: 0, createdAt: params.now,
    }).returning();
    return normalizeUser(row!);
  } catch (error) {
    if (isUniqueViolation(error)) throw new EmailTakenError();
    throw error;
  }
}

function pgErrorCode(error: unknown): string | undefined {
  if (typeof error !== 'object' || error === null) return undefined;
  const direct = (error as { code?: unknown }).code;
  if (typeof direct === 'string') return direct;
  // Drizzle wraps the driver's error, which carries the actual Postgres code.
  const cause = (error as { cause?: unknown }).cause;
  if (typeof cause === 'object' && cause !== null && typeof (cause as { code?: unknown }).code === 'string') {
    return (cause as { code: string }).code;
  }
  return undefined;
}

function isUniqueViolation(error: unknown): boolean {
  return pgErrorCode(error) === '23505';
}

export async function findUserByEmail(db: Db, email: string): Promise<StoredUser | null> {
  const rows = await db.select().from(users).where(eq(users.email, email)).limit(1);
  return rows[0] ? normalizeUser(rows[0]) : null;
}

export async function findUserById(db: Db, id: string): Promise<StoredUser | null> {
  const rows = await db.select().from(users).where(eq(users.id, id)).limit(1);
  return rows[0] ? normalizeUser(rows[0]) : null;
}

export async function createSession(db: Db, params: { tokenHash: string; userId: string; now: string; expiresAt: string }): Promise<void> {
  await db.insert(sessions).values({
    tokenHash: params.tokenHash, userId: params.userId, createdAt: params.now, expiresAt: params.expiresAt,
  });
}

export interface ActiveSession {
  userId: string;
  lastUsedAt: string | null;
}

export async function findActiveSession(db: Db, tokenHash: string, nowIso: string): Promise<ActiveSession | null> {
  const rows = await db.select().from(sessions).where(eq(sessions.tokenHash, tokenHash)).limit(1);
  const row = rows[0];
  if (!row) return null;
  if (row.revokedAt !== null) return null;
  if (Date.parse(row.expiresAt) <= Date.parse(nowIso)) return null;
  return { userId: row.userId, lastUsedAt: row.lastUsedAt };
}

export async function touchSession(db: Db, tokenHash: string, now: string): Promise<void> {
  await db.update(sessions).set({ lastUsedAt: now }).where(eq(sessions.tokenHash, tokenHash));
}

export async function revokeSession(db: Db, tokenHash: string): Promise<void> {
  await db.update(sessions).set({ revokedAt: sql`now()` }).where(eq(sessions.tokenHash, tokenHash));
}

interface EntryRow {
  userId: string;
  id: string;
  kind: string;
  sourceRecipeId: string;
  source: string | null;
  variation: string | null;
  day: string;
  hasPhoto: boolean;
  photoMime: string | null;
  photoBytes: number | null;
  photoUpdatedAt: string | null;
  createdAt: string;
  updatedAt: string;
  deleted: boolean;
  revision: number;
}

function toEntryRecord(row: EntryRow): EntryRecord {
  return {
    id: row.id,
    kind: row.kind as EntryRecord['kind'],
    sourceRecipeId: row.sourceRecipeId,
    source: row.source === null ? null : (JSON.parse(row.source) as Record<string, unknown>),
    variation: row.variation === null ? null : (JSON.parse(row.variation) as VariationRecord),
    day: row.day,
    hasPhoto: row.hasPhoto,
    photoUpdatedAt: row.photoUpdatedAt === null ? null : toIso(row.photoUpdatedAt),
    createdAt: toIso(row.createdAt),
    updatedAt: toIso(row.updatedAt),
    deleted: row.deleted,
    revision: row.revision,
  };
}

/**
 * Applies last-edit-wins semantics for an entry PUT inside one transaction that
 * locks the user row and bumps its revision counter. Tombstones are final.
 */
export async function upsertEntry(db: Db, params: { userId: string; photoDir: string; body: ValidatedEntry }): Promise<EntryRecord> {
  return db.transaction(async (tx) => {
    await tx.select({ id: users.id }).from(users).where(eq(users.id, params.userId)).for('update');
    const existingRows = await tx.select().from(entries)
      .where(and(eq(entries.userId, params.userId), eq(entries.id, params.body.id))).limit(1);
    const existing = existingRows[0] as EntryRow | undefined;

    if (existing?.deleted) return toEntryRecord(existing);
    if (existing && Date.parse(params.body.updatedAt) <= Date.parse(existing.updatedAt)) return toEntryRecord(existing);

    const revisionRows = await tx.update(users).set({ revision: sql`${users.revision} + 1` })
      .where(eq(users.id, params.userId)).returning({ revision: users.revision });
    const revision = revisionRows[0]!.revision;

    const becomingDeleted = params.body.deleted;
    const values = {
      userId: params.userId,
      id: params.body.id,
      kind: params.body.kind,
      sourceRecipeId: params.body.sourceRecipeId,
      source: becomingDeleted ? null : JSON.stringify(params.body.source),
      variation: becomingDeleted ? null : (params.body.variation === null ? null : JSON.stringify(params.body.variation)),
      day: params.body.day,
      hasPhoto: becomingDeleted ? false : (existing?.hasPhoto ?? false),
      photoMime: becomingDeleted ? null : (existing?.photoMime ?? null),
      photoBytes: becomingDeleted ? null : (existing?.photoBytes ?? null),
      photoUpdatedAt: becomingDeleted ? null : (existing?.photoUpdatedAt ?? null),
      createdAt: existing?.createdAt ?? params.body.createdAt,
      updatedAt: params.body.updatedAt,
      deleted: params.body.deleted,
      revision,
    };

    if (existing) {
      await tx.update(entries).set(values).where(and(eq(entries.userId, params.userId), eq(entries.id, params.body.id)));
    } else {
      await tx.insert(entries).values(values);
    }

    if (becomingDeleted && existing?.hasPhoto) {
      await removePhotoFile(photoPath(params.photoDir, params.userId, params.body.id)).catch(() => {});
    }

    return toEntryRecord(values as EntryRow);
  });
}

export interface PullResult {
  entries: EntryRecord[];
  revision: number;
  hasMore: boolean;
}

export async function pullEntries(db: Db, params: { userId: string; since: number; limit: number }): Promise<PullResult> {
  const rows = await db.select().from(entries)
    .where(and(eq(entries.userId, params.userId), gt(entries.revision, params.since)))
    .orderBy(asc(entries.revision)).limit(params.limit + 1);
  const hasMore = rows.length > params.limit;
  const page = (hasMore ? rows.slice(0, params.limit) : rows) as EntryRow[];
  const revision = page.length > 0 ? page[page.length - 1]!.revision : params.since;
  return { entries: page.map(toEntryRecord), revision, hasMore };
}

export async function findEntry(db: Db, userId: string, entryId: string): Promise<EntryRecord | null> {
  const rows = await db.select().from(entries).where(and(eq(entries.userId, userId), eq(entries.id, entryId))).limit(1);
  const row = rows[0] as EntryRow | undefined;
  if (!row || row.deleted) return null;
  return toEntryRecord(row);
}

/** The stored MIME type for an entry's current photo, or null if it has none. */
export async function getPhotoMime(db: Db, userId: string, entryId: string): Promise<string | null> {
  const rows = await db.select().from(entries).where(and(eq(entries.userId, userId), eq(entries.id, entryId))).limit(1);
  const row = rows[0] as EntryRow | undefined;
  if (!row || row.deleted || !row.hasPhoto) return null;
  return row.photoMime;
}

export interface PhotoWriteResult {
  entry: EntryRecord | null;
  outcome: 'applied' | 'stale' | 'not_found' | 'quota_exceeded';
}

/** Sets a photo on an entry, applying last-edit-wins on photoUpdatedAt and the per-user quota. */
export async function setEntryPhoto(db: Db, params: {
  userId: string; entryId: string; updatedAt: string; mime: string; bytes: number; quotaBytes: number;
}): Promise<PhotoWriteResult> {
  return db.transaction(async (tx) => {
    await tx.select({ id: users.id }).from(users).where(eq(users.id, params.userId)).for('update');
    const existingRows = await tx.select().from(entries)
      .where(and(eq(entries.userId, params.userId), eq(entries.id, params.entryId))).limit(1);
    const existing = existingRows[0] as EntryRow | undefined;
    if (!existing || existing.deleted) return { entry: null, outcome: 'not_found' };
    if (existing.photoUpdatedAt !== null && Date.parse(params.updatedAt) <= Date.parse(existing.photoUpdatedAt)) {
      return { entry: toEntryRecord(existing), outcome: 'stale' };
    }

    const totalRows = await tx.select({ total: sql<string>`coalesce(sum(${entries.photoBytes}), 0)` }).from(entries)
      .where(and(eq(entries.userId, params.userId), eq(entries.deleted, false)));
    const currentTotal = Number(totalRows[0]!.total) - (existing.photoBytes ?? 0);
    if (currentTotal + params.bytes > params.quotaBytes) return { entry: toEntryRecord(existing), outcome: 'quota_exceeded' };

    const revisionRows = await tx.update(users).set({ revision: sql`${users.revision} + 1` })
      .where(eq(users.id, params.userId)).returning({ revision: users.revision });
    const revision = revisionRows[0]!.revision;

    const values = {
      hasPhoto: true, photoMime: params.mime, photoBytes: params.bytes, photoUpdatedAt: params.updatedAt, revision,
    };
    await tx.update(entries).set(values).where(and(eq(entries.userId, params.userId), eq(entries.id, params.entryId)));
    return { entry: toEntryRecord({ ...existing, ...values }), outcome: 'applied' };
  });
}

export async function clearEntryPhoto(db: Db, params: { userId: string; entryId: string; updatedAt: string }): Promise<PhotoWriteResult> {
  return db.transaction(async (tx) => {
    await tx.select({ id: users.id }).from(users).where(eq(users.id, params.userId)).for('update');
    const existingRows = await tx.select().from(entries)
      .where(and(eq(entries.userId, params.userId), eq(entries.id, params.entryId))).limit(1);
    const existing = existingRows[0] as EntryRow | undefined;
    if (!existing || existing.deleted) return { entry: null, outcome: 'not_found' };
    if (existing.photoUpdatedAt !== null && Date.parse(params.updatedAt) <= Date.parse(existing.photoUpdatedAt)) {
      return { entry: toEntryRecord(existing), outcome: 'stale' };
    }

    const revisionRows = await tx.update(users).set({ revision: sql`${users.revision} + 1` })
      .where(eq(users.id, params.userId)).returning({ revision: users.revision });
    const revision = revisionRows[0]!.revision;

    const values = { hasPhoto: false, photoMime: null, photoBytes: null, photoUpdatedAt: params.updatedAt, revision };
    await tx.update(entries).set(values).where(and(eq(entries.userId, params.userId), eq(entries.id, params.entryId)));
    return { entry: toEntryRecord({ ...existing, ...values }), outcome: 'applied' };
  });
}

interface BarItemRow {
  userId: string;
  ingredientId: string;
  displayName: string;
  location: string;
  updatedAt: string;
  deleted: boolean;
  revision: number;
}

function toHomeBarItemRecord(row: BarItemRow): HomeBarItemRecord {
  return {
    ingredientId: row.ingredientId,
    displayName: row.displayName,
    location: row.location as HomeBarItemRecord['location'],
    updatedAt: toIso(row.updatedAt),
    deleted: row.deleted,
    revision: row.revision,
  };
}

/**
 * Applies M10's last-edit-wins home-bar state. Unlike collection records,
 * home-bar tombstones are restorable by a strictly newer explicit write.
 */
export async function upsertHomeBarItem(db: Db, params: {
  userId: string;
  body: ValidatedHomeBarItem;
}): Promise<HomeBarItemRecord> {
  return db.transaction(async (tx) => {
    await tx.select({ id: users.id }).from(users).where(eq(users.id, params.userId)).for('update');
    const existingRows = await tx.select().from(barItems)
      .where(and(eq(barItems.userId, params.userId), eq(barItems.ingredientId, params.body.ingredientId))).limit(1);
    const existing = existingRows[0] as BarItemRow | undefined;
    if (existing && Date.parse(params.body.updatedAt) <= Date.parse(existing.updatedAt)) {
      return toHomeBarItemRecord(existing);
    }

    const revisionRows = await tx.update(users).set({ barRevision: sql`${users.barRevision} + 1` })
      .where(eq(users.id, params.userId)).returning({ revision: users.barRevision });
    const revision = revisionRows[0]!.revision;
    const values = {
      userId: params.userId,
      ingredientId: params.body.ingredientId,
      displayName: params.body.displayName,
      location: params.body.location,
      updatedAt: params.body.updatedAt,
      deleted: params.body.deleted,
      revision,
    };
    if (existing) {
      await tx.update(barItems).set(values)
        .where(and(eq(barItems.userId, params.userId), eq(barItems.ingredientId, params.body.ingredientId)));
    } else {
      await tx.insert(barItems).values(values);
    }
    return toHomeBarItemRecord(values);
  });
}

export interface HomeBarPullResult {
  items: HomeBarItemRecord[];
  revision: number;
  hasMore: boolean;
}

/** Pulls only one user's home-bar stream, in ascending revision order. */
export async function pullHomeBarItems(db: Db, params: {
  userId: string;
  since: number;
  limit: number;
}): Promise<HomeBarPullResult> {
  const rows = await db.select().from(barItems)
    .where(and(eq(barItems.userId, params.userId), gt(barItems.revision, params.since)))
    .orderBy(asc(barItems.revision)).limit(params.limit + 1);
  const hasMore = rows.length > params.limit;
  const page = (hasMore ? rows.slice(0, params.limit) : rows) as BarItemRow[];
  const revision = page.length > 0 ? page[page.length - 1]!.revision : params.since;
  return { items: page.map(toHomeBarItemRecord), revision, hasMore };
}
