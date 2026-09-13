// Test harness for the accounts/sync backend: PGlite with the committed
// migrations applied, a temp photo directory, and cheap argon2 parameters.
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { PGlite } from '@electric-sql/pglite';
import { drizzle } from 'drizzle-orm/pglite';
import { migrate } from 'drizzle-orm/pglite/migrator';
import { buildApp, type AppOptions } from '../../src/app.js';
import { schema } from '../../src/accounts/db.js';
import type { Db } from '../../src/accounts/db.js';
import { resetDummyHashForTests } from '../../src/accounts/auth.js';

const CHEAP_ARGON2 = { memoryCost: 8, timeCost: 1, parallelism: 1 };

export interface TestHarness {
  app: ReturnType<typeof buildApp>;
  db: Db;
  photoDir: string;
  setNow(iso: string): void;
  nextToken(): string;
  cleanup(): Promise<void>;
}

export async function createTestApp(overrides: Partial<AppOptions> = {}): Promise<TestHarness> {
  const pglite = new PGlite();
  const db = drizzle(pglite, { schema }) as unknown as Db;
  await migrate(db as never, { migrationsFolder: path.join(process.cwd(), 'drizzle') });

  const photoDir = mkdtempSync(path.join(tmpdir(), 'zest-photos-'));
  let now = new Date('2026-09-13T12:00:00.000Z');
  let tokenCounter = 0;
  resetDummyHashForTests();

  const app = buildApp({
    apiKey: 'synthetic-key',
    db,
    photoDir,
    argon2Options: CHEAP_ARGON2,
    clock: () => now,
    tokenGenerator: () => `test-token-${++tokenCounter}`,
    ...overrides,
  });
  await app.ready();

  return {
    app, db, photoDir,
    setNow: (iso: string) => { now = new Date(iso); },
    nextToken: () => `test-token-${tokenCounter}`,
    cleanup: async () => {
      await app.close();
      await pglite.close();
      rmSync(photoDir, { recursive: true, force: true });
    },
  };
}

export const JPEG_BYTES = Buffer.from([0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10, 0x4a, 0x46, 0x49, 0x46]);
export const PNG_BYTES = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0x00, 0x00, 0x00, 0x0d]);
