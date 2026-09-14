// Persistence for the shared catalog snapshot (M11). See docs/M11.md.
import { asc, eq, sql } from 'drizzle-orm';
import type { Db } from '../accounts/db.js';
import { catalogRecipes, catalogState } from './schema.js';

const STATE_ID = 1;

export interface CatalogStateRow {
  version: string;
  recipeCount: number;
  publishedAt: string;
  checkedAt: string;
  lastErrorCode: string | null;
}

export interface CatalogRecipeRow {
  providerId: string;
  name: string;
  source: string;
  updatedAt: string;
}

/**
 * Postgres/PGlite return timestamptz text in the session's own offset format
 * (e.g. "2026-09-13 12:30:00+02"), not the strict ISO-8601 UTC the wire
 * contract requires. Every timestamp read back from a row is normalized here
 * before it is ever exposed, matching accounts/repository.ts.
 */
function toIso(value: string): string {
  return new Date(value).toISOString();
}

export async function readCatalogState(db: Db): Promise<CatalogStateRow | undefined> {
  const rows = await db.select().from(catalogState).where(eq(catalogState.id, STATE_ID)).limit(1);
  const row = rows[0];
  if (!row) return undefined;
  return { ...row, publishedAt: toIso(row.publishedAt), checkedAt: toIso(row.checkedAt) };
}

/** Rows in wire order: shortest provider id first, then lexical — matches the frozen sort rule. */
export async function readCatalogRecipes(db: Db): Promise<CatalogRecipeRow[]> {
  const rows = await db.select().from(catalogRecipes)
    .orderBy(sql`length(${catalogRecipes.providerId})`, asc(catalogRecipes.providerId));
  return rows.map((row) => ({ ...row, updatedAt: toIso(row.updatedAt) }));
}

export interface CatalogSnapshotRead {
  state: CatalogStateRow;
  recipes: CatalogRecipeRow[];
}

/**
 * Reads state and recipes as one consistent pair, guarding against a publish
 * landing between the two separate statements (state and recipes are read
 * with two different queries, not one join, so a torn read is otherwise
 * possible). If the version moved between the state read and the recipes
 * read, retries once with the fresher state.
 *
 * `afterStateRead` is a test-only seam: tests use it to publish a new
 * snapshot between the state read and the recipes read, to exercise the
 * retry deterministically.
 */
export async function readCatalogSnapshot(
  db: Db,
  afterStateRead?: () => Promise<void> | void,
): Promise<CatalogSnapshotRead | undefined> {
  let state = await readCatalogState(db);
  if (!state) return undefined;
  await afterStateRead?.();

  let recipes = await readCatalogRecipes(db);
  const after = await readCatalogState(db);
  if (after && after.version !== state.version) {
    // A publish committed while we were reading: retry once with the
    // now-current state so the pair we return is internally consistent.
    state = after;
    recipes = await readCatalogRecipes(db);
  }
  return { state, recipes };
}

export interface PublishInput {
  version: string;
  recipeCount: number;
  publishedAt: string;
  checkedAt: string;
  drinks: Array<{ providerId: string; name: string; source: string }>;
}

/** Replaces the snapshot in one transaction: previous rows are visible until this commits. */
export async function publishCatalog(db: Db, input: PublishInput): Promise<void> {
  await db.transaction(async (tx) => {
    await tx.delete(catalogRecipes);
    if (input.drinks.length > 0) {
      await tx.insert(catalogRecipes).values(input.drinks.map((drink) => ({
        providerId: drink.providerId, name: drink.name, source: drink.source, updatedAt: input.publishedAt,
      })));
    }
    await tx.insert(catalogState).values({
      id: STATE_ID, version: input.version, recipeCount: input.recipeCount,
      publishedAt: input.publishedAt, checkedAt: input.checkedAt, lastErrorCode: null,
    }).onConflictDoUpdate({
      target: catalogState.id,
      set: {
        version: input.version, recipeCount: input.recipeCount,
        publishedAt: input.publishedAt, checkedAt: input.checkedAt, lastErrorCode: null,
      },
    });
  });
}

/** Same body hash as the current version: only the check timestamp moves. */
export async function markUnchanged(db: Db, checkedAt: string): Promise<void> {
  await db.update(catalogState).set({ checkedAt, lastErrorCode: null }).where(eq(catalogState.id, STATE_ID));
}

/**
 * A refresh attempt failed. The previous snapshot (if any) is left untouched;
 * this only records that a check happened and why it did not publish. A
 * no-op before the first successful publish, since there is no row yet.
 */
export async function markFailure(db: Db, checkedAt: string, errorCode: string): Promise<void> {
  await db.update(catalogState).set({ checkedAt, lastErrorCode: errorCode }).where(eq(catalogState.id, STATE_ID));
}
