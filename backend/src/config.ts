import { isIP } from 'node:net';

export interface Config {
  apiKey: string;
  port: number;
  origins: string[];
  databaseUrl: string;
  photoDir: string;
  host: string;
}

export function readConfig(env: NodeJS.ProcessEnv = process.env): Config {
  const apiKey = env.COCKTAIL_DB_API_KEY ?? '1';
  if (!/^[A-Za-z0-9_-]{1,256}$/.test(apiKey)) {
    throw new Error('COCKTAIL_DB_API_KEY must be a non-empty safe key.');
  }
  const portText = env.PORT ?? '3000';
  const port = Number(portText);
  if (!/^\d+$/.test(portText) || !Number.isInteger(port) || port < 1 || port > 65535) {
    throw new Error('PORT must be an integer between 1 and 65535.');
  }
  const origins = (env.CORS_ORIGINS ?? 'http://localhost:5173,http://127.0.0.1:5173')
    .split(',').map((origin) => origin.trim());
  for (const origin of origins) {
    let url: URL;
    try { url = new URL(origin); } catch { throw new Error('Invalid CORS_ORIGINS.'); }
    if (!['http:', 'https:'].includes(url.protocol) || url.origin !== origin ||
        !['localhost', '127.0.0.1', '[::1]'].includes(url.hostname)) {
      throw new Error('CORS_ORIGINS must contain exact loopback HTTP(S) origins.');
    }
  }
  const databaseUrl = env.DATABASE_URL;
  if (!databaseUrl || !/^postgres(ql)?:\/\/.+/.test(databaseUrl)) {
    throw new Error('DATABASE_URL is required and must be a postgres(ql):// connection string.');
  }
  const photoDir = env.PHOTO_DIR ?? './data/photos';
  if (!photoDir.trim()) throw new Error('PHOTO_DIR must not be blank.');
  const host = env.HOST ?? '127.0.0.1';
  if (!['127.0.0.1', '::1', '0.0.0.0'].includes(host) && isIP(host) === 0) {
    throw new Error('HOST must be 127.0.0.1, ::1, 0.0.0.0, or a valid IP literal.');
  }
  return { apiKey, port, origins: [...new Set(origins)], databaseUrl, photoDir, host };
}

export function isLoopbackHost(host: string): boolean {
  return host === '127.0.0.1' || host === '::1' || host === 'localhost';
}
