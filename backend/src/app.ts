import Fastify from 'fastify';
import cors from '@fastify/cors';
import { GatewayError, RecipeGateway } from './gateway.js';
import type { Endpoint, Fetcher, Operation } from './gateway.js';
import { registerAccountsRoutes } from './accounts/routes.js';
import type { Db } from './accounts/db.js';
import type { Argon2Options } from './accounts/auth.js';

export interface AppOptions {
  apiKey: string;
  origins?: string[];
  fetcher?: Fetcher;
  now?: () => number;
  timeoutMs?: number;
  ttlMs?: number;
  maxEntries?: number;
  maxBytes?: number;
  maxResponseBytes?: number;
  maxConcurrent?: number;
  // Accounts and synced collection (M8, docs/ACCOUNTS.md). Omitting `db`
  // leaves the accounts/sync/photo routes unregistered.
  db?: Db;
  photoDir?: string;
  argon2Options?: Argon2Options;
  clock?: () => Date;
  tokenGenerator?: () => string;
}

export function buildApp(options: AppOptions) {
  const app = Fastify({ logger: false, bodyLimit: 1024, exposeHeadRoutes: false,
    ajv: { customOptions: { removeAdditional: false, coerceTypes: false } } });
  const gateway = new RecipeGateway(options);
  const origins = options.origins ?? ['http://localhost:5173', 'http://127.0.0.1:5173'];
  // CORS alone is not access control. Reject disallowed browser origins before work.
  app.addHook('onRequest', async (request, reply) => {
    if (request.headers.origin !== undefined && !origins.includes(request.headers.origin)) {
      return reply.code(403).send({ error: { code: 'origin_not_allowed', message: 'Origin not allowed.' } });
    }
    reply.header('Cache-Control', 'no-store');
    reply.header('X-Content-Type-Options', 'nosniff');
  });
  // Widened for accounts and sync (docs/ACCOUNTS.md): still loopback-only origins, no credentials.
  app.register(cors, { origin: origins, methods: ['GET', 'POST', 'PUT', 'DELETE'], credentials: false,
    allowedHeaders: ['Accept', 'Authorization', 'Content-Type'], exposedHeaders: ['Retry-After'] });
  if (options.db) {
    app.register(registerAccountsRoutes, {
      db: options.db, photoDir: options.photoDir ?? './data/photos',
      argon2Options: options.argon2Options, clock: options.clock, tokenGenerator: options.tokenGenerator,
    });
  }
  app.get('/api/health', async () => ({ status: 'ok' }));
  const text = { type: 'string', minLength: 1, maxLength: 200, pattern: '^[^\\u0000-\\u001f\\u007f]+$' };
  const routes: [Endpoint, object][] = [
    ['search.php', { oneOf: [
      { type: 'object', additionalProperties: false, required: ['s'], properties: { s: text } },
      { type: 'object', additionalProperties: false, required: ['f'], properties: { f: { type: 'string', pattern: '^[A-Za-z]$' } } },
    ] }],
    ['filter.php', { type: 'object', additionalProperties: false, required: ['i'], properties: { i: text } }],
    ['lookup.php', { type: 'object', additionalProperties: false, required: ['i'], properties: { i: { type: 'string', pattern: '^[0-9]{1,20}$' } } }],
    ['list.php', { type: 'object', additionalProperties: false, required: ['i'], properties: { i: { type: 'string', const: 'list' } } }],
  ];
  for (const [endpoint, querystring] of routes) {
    app.get<{ Querystring: Record<string, string> }>(`/api/cocktails/${endpoint}`, { schema: { querystring } }, async (request, reply) => {
      const parameter = Object.keys(request.query)[0] as Operation['parameter'];
      let value = request.query[parameter]!.trim();
      if (!value || (endpoint === 'filter.php' && value.includes(','))) {
        return reply.code(400).send({ error: { code: 'invalid_request', message: 'Invalid recipe request.' } });
      }
      if (parameter === 'f') value = value.toLowerCase();
      const body = await gateway.get({ endpoint, parameter, value });
      return reply.type('application/json').send(body);
    });
  }
  app.setNotFoundHandler((_, reply) => reply.code(404).send({ error: { code: 'not_found', message: 'Endpoint not found.' } }));
  app.setErrorHandler((error, _, reply) => {
    if (error instanceof GatewayError) {
      if (error.retryAfter !== undefined) reply.header('Retry-After', error.retryAfter);
      return reply.code(error.status).send({ error: { code: error.code, message: error.message } });
    }
    const status = typeof error === 'object' && error !== null && 'statusCode' in error ? error.statusCode : undefined;
    if (typeof status === 'number' && status >= 400 && status < 500) {
      return reply.code(status).send({ error: { code: 'invalid_request', message: 'Invalid recipe request.' } });
    }
    return reply.code(500).send({ error: { code: 'internal_error', message: 'Request could not be completed.' } });
  });
  app.addHook('onClose', async () => { gateway.close(); });
  return app;
}
