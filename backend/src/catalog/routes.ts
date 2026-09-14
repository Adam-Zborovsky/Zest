// GET /api/catalog (M11). Wire shape frozen in docs/M11.md.
import { gzipSync } from 'node:zlib';
import type { FastifyInstance, FastifyReply, FastifyRequest } from 'fastify';
import rateLimit from '@fastify/rate-limit';
import type { Db } from '../accounts/db.js';
import { readCatalogState, readCatalogSnapshot } from './store.js';

export const CATALOG_ATTRIBUTION = Object.freeze({ name: 'TheCocktailDB', url: 'https://www.thecocktaildb.com' });

export interface CatalogRateLimitOptions {
  max?: number;
  timeWindow?: string | number;
}

export interface CatalogRoutesOptions {
  db: Db;
  rateLimit?: CatalogRateLimitOptions | undefined;
}

interface CachedBody {
  version: string;
  json: Buffer;
  gzip: Buffer;
}

/** @fastify/rate-limit throws whatever errorResponseBuilder returns; app.ts's
 * top-level error handler recognizes this shape and converts it to the
 * standard `{error:{code,message}}` envelope. */
export class CatalogRateLimitError extends Error {
  readonly code = 'rate_limited';
  constructor(readonly status: number) {
    super('Too many requests. Try again later.');
  }
}

function rateLimitedResponse(_request: FastifyRequest, context: { statusCode: number }) {
  return new CatalogRateLimitError(context.statusCode);
}

export async function registerCatalogRoutes(app: FastifyInstance, opts: CatalogRoutesOptions): Promise<void> {
  const { db } = opts;
  // Serialized once per published version and held in memory; rebuilt only
  // when the stored version differs from what is cached.
  let cached: CachedBody | undefined;

  await app.register(async function catalogScope(scope) {
    await scope.register(rateLimit, {
      global: true,
      max: opts.rateLimit?.max ?? 30,
      timeWindow: opts.rateLimit?.timeWindow ?? '1 minute',
      keyGenerator: (request) => request.ip,
      errorResponseBuilder: rateLimitedResponse,
    });

    scope.get('/api/catalog', async (request, reply) => {
      // Read state alone first: a 304 (the common case for an unchanged
      // catalog) is answered from this single row, never from the full
      // recipes table.
      const state = await readCatalogState(db);
      if (!state) {
        return reply.code(503).send({ error: { code: 'catalog_unavailable', message: 'The catalog has not been published yet.' } });
      }
      const etag = `"${state.version}"`;
      reply.header('ETag', etag);
      reply.header('Cache-Control', 'no-cache');
      appendVary(reply, 'Accept-Encoding');

      if (ifNoneMatchMatches(request.headers['if-none-match'], state.version)) {
        return reply.code(304).send();
      }

      if (!cached || cached.version !== state.version) {
        // The cached body is stale (or missing): only now is the recipes
        // table read, via the consistent-read pair so a publish landing
        // mid-request can never serve a torn version/drinks body.
        const snapshot = await readCatalogSnapshot(db);
        if (!snapshot) {
          return reply.code(503).send({ error: { code: 'catalog_unavailable', message: 'The catalog has not been published yet.' } });
        }
        const { state: freshState, recipes } = snapshot;
        reply.header('ETag', `"${freshState.version}"`);
        if (ifNoneMatchMatches(request.headers['if-none-match'], freshState.version)) {
          return reply.code(304).send();
        }
        if (!cached || cached.version !== freshState.version) {
          const body = {
            version: freshState.version,
            publishedAt: freshState.publishedAt,
            recipeCount: freshState.recipeCount,
            attribution: CATALOG_ATTRIBUTION,
            drinks: recipes.map((row) => JSON.parse(row.source) as unknown),
          };
          const json = Buffer.from(JSON.stringify(body), 'utf-8');
          cached = { version: freshState.version, json, gzip: gzipSync(json) };
        }
      }

      const acceptEncoding = request.headers['accept-encoding'] ?? '';
      if (acceptsGzip(acceptEncoding)) {
        reply.header('Content-Encoding', 'gzip');
        return reply.type('application/json').send(cached.gzip);
      }
      return reply.type('application/json').send(cached.json);
    });
  });
}

/**
 * Appends `value` to any `Vary` header @fastify/cors already set (it sets
 * `Vary: Origin` for a non-wildcard configured origin), rather than
 * overwriting it — so a CORS response still varies correctly by Origin.
 */
function appendVary(reply: FastifyReply, value: string): void {
  const existing = reply.getHeader('Vary');
  if (typeof existing === 'string' && existing.trim() !== '') {
    const parts = existing.split(',').map((part) => part.trim()).filter(Boolean);
    if (!parts.includes(value)) parts.push(value);
    reply.header('Vary', parts.join(', '));
  } else {
    reply.header('Vary', value);
  }
}

/**
 * RFC 9110 §12.5.1 Accept-Encoding: each coding may carry a `;q=` weight;
 * `q=0` (or an unparsable weight) means "not acceptable", not accepted.
 */
function acceptsGzip(acceptEncoding: string): boolean {
  for (const raw of acceptEncoding.split(',')) {
    const [codingRaw, ...params] = raw.split(';').map((part) => part.trim());
    if (codingRaw?.toLowerCase() !== 'gzip') continue;
    const qParam = params.find((param) => param.toLowerCase().startsWith('q='));
    if (qParam === undefined) return true;
    const q = Number(qParam.slice(2));
    if (Number.isFinite(q) && q > 0) return true;
  }
  return false;
}

/**
 * RFC 9110 §13.1.2 If-None-Match: a comma-separated list of entity-tags, each
 * either strong (`"v"`) or weak (`W/"v"`), or the wildcard `*`. If-None-Match
 * always uses the *weak comparison* function, so a weak tag matches a current
 * strong ETag whose opaque-tag is equal — only the quoted value is compared,
 * never the weak/strong indicator.
 */
function ifNoneMatchMatches(header: string | string[] | undefined, version: string): boolean {
  if (header === undefined) return false;
  const raw = Array.isArray(header) ? header.join(',') : header;
  for (const rawTag of raw.split(',')) {
    const tag = rawTag.trim();
    if (tag === '') continue;
    if (tag === '*') return true;
    const opaque = tag.startsWith('W/') ? tag.slice(2) : tag;
    if (opaque.length >= 2 && opaque.startsWith('"') && opaque.endsWith('"') && opaque.slice(1, -1) === version) {
      return true;
    }
  }
  return false;
}
