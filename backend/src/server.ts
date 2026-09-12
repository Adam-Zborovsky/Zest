import { buildApp } from './app.js';
import { readConfig } from './config.js';

async function main() {
  const config = readConfig();
  const app = buildApp(config);
  await app.listen({ host: '127.0.0.1', port: config.port });
  console.info(`Zest recipe gateway: http://127.0.0.1:${config.port}/api`);
  for (const signal of ['SIGINT', 'SIGTERM'] as const) {
    process.once(signal, () => { void app.close().catch(() => { process.exitCode = 1; }); });
  }
}

main().catch(() => {
  // Never print arbitrary errors: upstream URLs or configuration can carry keys.
  console.error('Gateway startup failed. Check configuration and port availability.');
  process.exitCode = 1;
});
