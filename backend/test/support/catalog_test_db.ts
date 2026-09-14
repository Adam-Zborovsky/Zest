// Bare PGlite database with the committed migrations applied, for tests
// that exercise catalog storage/refresh logic without spinning up Fastify.
import path from 'node:path';
import { PGlite } from '@electric-sql/pglite';
import { drizzle } from 'drizzle-orm/pglite';
import { migrate } from 'drizzle-orm/pglite/migrator';
import { schema } from '../../src/accounts/db.js';
import type { Db } from '../../src/accounts/db.js';

export interface CatalogTestDb {
  db: Db;
  cleanup(): Promise<void>;
}

export async function createCatalogTestDb(): Promise<CatalogTestDb> {
  const pglite = new PGlite();
  const db = drizzle(pglite, { schema }) as unknown as Db;
  await migrate(db as never, { migrationsFolder: path.join(process.cwd(), 'drizzle') });
  return { db, cleanup: async () => { await pglite.close(); } };
}
