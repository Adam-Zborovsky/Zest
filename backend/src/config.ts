export interface Config {
  apiKey: string;
  port: number;
  origins: string[];
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
  return { apiKey, port, origins: [...new Set(origins)] };
}
