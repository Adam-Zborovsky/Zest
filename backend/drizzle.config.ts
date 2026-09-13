import { defineConfig } from 'drizzle-kit';

// Generation needs no running database; `db:migrate` supplies DATABASE_URL at runtime.
export default defineConfig({
  dialect: 'postgresql',
  schema: './src/accounts/schema.ts',
  out: './drizzle',
  dbCredentials: { url: process.env.DATABASE_URL ?? 'postgres://placeholder/placeholder' },
});
