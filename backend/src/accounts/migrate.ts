// Runs the committed migrations in backend/drizzle/ against DATABASE_URL.
// Usage (from backend/): npm run db:migrate
import { drizzle } from 'drizzle-orm/node-postgres';
import { migrate } from 'drizzle-orm/node-postgres/migrator';
import { Pool } from 'pg';
import { readConfig } from '../config.js';

async function main() {
  const config = readConfig();
  const pool = new Pool({ connectionString: config.databaseUrl });
  try {
    const db = drizzle(pool);
    await migrate(db, { migrationsFolder: './drizzle' });
    console.info('Migrations applied.');
  } finally {
    await pool.end();
  }
}

main().catch(() => {
  // Never print arbitrary errors: a connection string can carry credentials.
  console.error('Migration failed. Check DATABASE_URL and database availability.');
  process.exitCode = 1;
});
