import { drizzle } from 'drizzle-orm/node-postgres';
import { Pool } from 'pg';
import { buildApp } from './app.js';
import { isLoopbackHost, readConfig } from './config.js';
import { schema } from './accounts/db.js';

async function main() {
  const config = readConfig();
  const pool = new Pool({ connectionString: config.databaseUrl });
  const db = drizzle(pool, { schema });
  const app = buildApp({ ...config, db, photoDir: config.photoDir });
  await app.listen({ host: config.host, port: config.port });
  console.info(`Zest recipe gateway: http://${config.host}:${config.port}/api`);
  if (!isLoopbackHost(config.host)) {
    console.warn('HOST is not loopback: this process also accepts connections from other devices on the network.');
  }
  for (const signal of ['SIGINT', 'SIGTERM'] as const) {
    process.once(signal, () => {
      void app.close().then(() => pool.end()).catch(() => { process.exitCode = 1; });
    });
  }
}

main().catch(() => {
  // Never print arbitrary errors: connection strings and configuration can carry credentials.
  console.error('Gateway startup failed. Check configuration and port availability.');
  process.exitCode = 1;
});
