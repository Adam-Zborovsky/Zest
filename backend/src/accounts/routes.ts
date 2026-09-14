import { randomUUID } from 'node:crypto';
import path from 'node:path';
import type { FastifyInstance, FastifyRequest } from 'fastify';
import rateLimit from '@fastify/rate-limit';
import { AccountLimits } from './contract.js';
import type { Db } from './db.js';
import { DEFAULT_ARGON2_OPTIONS, getDummyHash, hashPassword, verifyPassword, type Argon2Options } from './auth.js';
import {
  AccountError, emailTaken, invalidCredentials, notFound, payloadTooLarge, quotaExceeded, unauthorized, unsupportedMediaType,
} from './errors.js';
import {
  clearEntryPhoto, createSession, createUser, EmailTakenError, findActiveSession, findEntry, findUserByEmail, findUserById,
  getPhotoMime, pullEntries, pullHomeBarItems, revokeSession, setEntryPhoto, touchSession, upsertEntry, upsertHomeBarItem,
} from './repository.js';
import { commitTempFile, discardTempFile, photoPath, readPhotoFile, removePhotoFile, sniffPhotoType, writeTempFile } from './photos.js';
import { defaultTokenGenerator, hashToken } from './tokens.js';
import {
  normalizeEmail, validateEntryBody, validateEntryId, validateHomeBarItemBody, validateIngredientId, validateLimit,
  validatePassword, validatePhotoUpdatedAt, validateSince,
  ValidationError,
} from './validation.js';

export interface AccountsOptions {
  db: Db;
  photoDir: string;
  argon2Options?: Argon2Options | undefined;
  clock?: (() => Date) | undefined;
  tokenGenerator?: (() => string) | undefined;
}

const LAST_USED_TOUCH_INTERVAL_MS = 60 * 60 * 1000;
const PHOTO_CONTENT_TYPES = ['image/jpeg', 'image/png', 'image/webp'] as const;

function rateLimitedResponse(message: string) {
  return (_request: FastifyRequest, context: { statusCode: number }) =>
    new AccountError('rate_limited', context.statusCode, message);
}

export async function registerAccountsRoutes(app: FastifyInstance, opts: AccountsOptions): Promise<void> {
  const { db, photoDir } = opts;
  const argon2Options = opts.argon2Options ?? DEFAULT_ARGON2_OPTIONS;
  const clock = opts.clock ?? (() => new Date());
  const tokenGenerator = opts.tokenGenerator ?? defaultTokenGenerator;

  // Registered before any route: Fastify binds each route to the error handler
  // active in its scope at declaration time, so this must precede every route.
  app.setErrorHandler((error, _request, reply) => {
    if (error instanceof AccountError) {
      if (error.retryAfter !== undefined) reply.header('Retry-After', error.retryAfter);
      return reply.code(error.status).send({ error: { code: error.code, message: error.message } });
    }
    if (error instanceof ValidationError) {
      return reply.code(400).send({ error: { code: 'invalid_request', message: error.message } });
    }
    const status = typeof error === 'object' && error !== null && 'statusCode' in error ? error.statusCode : undefined;
    if (status === 413) return reply.code(413).send({ error: { code: 'payload_too_large', message: 'Request body is too large.' } });
    if (status === 415) return reply.code(415).send({ error: { code: 'unsupported_media_type', message: 'Unsupported content type.' } });
    if (typeof status === 'number' && status >= 400 && status < 500) {
      return reply.code(status).send({ error: { code: 'invalid_request', message: 'Invalid request.' } });
    }
    return reply.code(500).send({ error: { code: 'internal_error', message: 'Request could not be completed.' } });
  });

  // Baseline: every account/sync/photo route, 300 requests/minute per IP.
  await app.register(rateLimit, {
    global: true, max: 300, timeWindow: '1 minute', keyGenerator: (request) => request.ip,
    errorResponseBuilder: rateLimitedResponse('Too many requests. Try again later.'),
  });

  app.addContentTypeParser(PHOTO_CONTENT_TYPES as unknown as string[], { parseAs: 'buffer' }, (_request, body, done) => {
    done(null, body);
  });

  async function issueSession(userId: string) {
    const token = tokenGenerator();
    const now = clock();
    const nowIso = now.toISOString();
    const expiresAt = new Date(now.getTime() + AccountLimits.sessionDays * 24 * 60 * 60 * 1000).toISOString();
    await createSession(db, { tokenHash: hashToken(token), userId, now: nowIso, expiresAt });
    return { token, expiresAt };
  }

  async function requireSession(request: FastifyRequest): Promise<string> {
    const header = request.headers.authorization;
    if (!header?.startsWith('Bearer ')) throw unauthorized();
    const token = header.slice('Bearer '.length).trim();
    if (!token) throw unauthorized();
    const tokenHash = hashToken(token);
    const nowIso = clock().toISOString();
    const session = await findActiveSession(db, tokenHash, nowIso);
    if (!session) throw unauthorized();
    const lastUsed = session.lastUsedAt ? Date.parse(session.lastUsedAt) : 0;
    if (Date.parse(nowIso) - lastUsed > LAST_USED_TOUCH_INTERVAL_MS) {
      await touchSession(db, tokenHash, nowIso).catch(() => {});
    }
    return session.userId;
  }

  const credentialsSchema = {
    body: {
      type: 'object', additionalProperties: false, required: ['email', 'password'],
      properties: { email: { type: 'string' }, password: { type: 'string' } },
    },
  };

  await app.register(async function registerScope(scope) {
    // Per docs/ACCOUNTS.md: 5 per hour per IP, stricter than the 300/min baseline.
    await scope.register(rateLimit, {
      global: true, max: 5, timeWindow: '1 hour', keyGenerator: (request) => request.ip,
      errorResponseBuilder: rateLimitedResponse('Too many attempts. Try again later.'),
    });

    scope.post('/api/auth/register', { schema: credentialsSchema }, async (request, reply) => {
      const body = request.body as { email: unknown; password: unknown };
      const email = normalizeEmail(body.email);
      const password = validatePassword(body.password);
      const passwordHash = await hashPassword(password, argon2Options);
      const now = clock().toISOString();
      try {
        const user = await createUser(db, { id: randomUUID(), email, passwordHash, now });
        const session = await issueSession(user.id);
        return reply.code(201).send({ user: { id: user.id, email: user.email, createdAt: user.createdAt }, session });
      } catch (error) {
        if (error instanceof EmailTakenError) throw emailTaken();
        throw error;
      }
    });
  });

  await app.register(async function loginIpScope(ipScope) {
    // Per docs/ACCOUNTS.md: 10/15min per IP and 5/15min per normalized email.
    // Two independent @fastify/rate-limit instances, nested so both apply to
    // only this route — a single instance supports one rule per route.
    await ipScope.register(rateLimit, {
      global: true, max: 10, timeWindow: '15 minutes', keyGenerator: (request) => request.ip,
      errorResponseBuilder: rateLimitedResponse('Too many attempts. Try again later.'),
    });
    await ipScope.register(async function loginEmailScope(emailScope) {
      await emailScope.register(rateLimit, {
        global: true, max: 5, timeWindow: '15 minutes', hook: 'preHandler',
        keyGenerator: (request) => {
          try { return `email:${normalizeEmail((request.body as { email?: unknown } | undefined)?.email)}`; }
          catch { return `email:invalid:${request.ip}`; }
        },
        errorResponseBuilder: rateLimitedResponse('Too many attempts. Try again later.'),
      });

      emailScope.post('/api/auth/login', { schema: credentialsSchema }, async (request, reply) => {
        const body = request.body as { email: unknown; password: unknown };
        const email = normalizeEmail(body.email);
        const password = validatePassword(body.password);
        const user = await findUserByEmail(db, email);
        const hash = user ? user.passwordHash : await getDummyHash(argon2Options);
        const valid = await verifyPassword(hash, password);
        if (!user || !valid) throw invalidCredentials();
        const session = await issueSession(user.id);
        return reply.send({ user: { id: user.id, email: user.email, createdAt: user.createdAt }, session });
      });
    });
  });

  app.post('/api/auth/logout', async (request, reply) => {
    const header = request.headers.authorization;
    if (!header?.startsWith('Bearer ')) throw unauthorized();
    const token = header.slice('Bearer '.length).trim();
    if (!token) throw unauthorized();
    const tokenHash = hashToken(token);
    const nowIso = clock().toISOString();
    const session = await findActiveSession(db, tokenHash, nowIso);
    if (!session) throw unauthorized();
    await revokeSession(db, tokenHash);
    return reply.code(204).send();
  });

  app.get('/api/auth/me', async (request, reply) => {
    const userId = await requireSession(request);
    const user = await findUserById(db, userId);
    if (!user) throw unauthorized();
    return reply.send({ user: { id: user.id, email: user.email, createdAt: user.createdAt } });
  });

  app.get('/api/sync/entries', {
    schema: { querystring: {
      type: 'object', additionalProperties: false, required: ['since'],
      properties: { since: { type: 'string' }, limit: { type: 'string' } },
    } },
  }, async (request, reply) => {
    const userId = await requireSession(request);
    const query = request.query as { since: string; limit?: string };
    const since = validateSince(query.since);
    const limit = validateLimit(query.limit);
    const result = await pullEntries(db, { userId, since, limit });
    return reply.send(result);
  });

  app.get('/api/sync/bar-items', {
    schema: { querystring: {
      type: 'object', additionalProperties: false, required: ['since'],
      properties: { since: { type: 'string' }, limit: { type: 'string' } },
    } },
  }, async (request, reply) => {
    const userId = await requireSession(request);
    const query = request.query as { since: string; limit?: string };
    const since = validateSince(query.since);
    const limit = validateLimit(query.limit);
    const result = await pullHomeBarItems(db, { userId, since, limit });
    return reply.send(result);
  });

  app.put('/api/entries/:id', { bodyLimit: 128 * 1024 }, async (request, reply) => {
    const userId = await requireSession(request);
    const entryId = validateEntryId((request.params as { id: string }).id);
    const body = validateEntryBody(request.body, entryId, clock().getTime());
    const result = await upsertEntry(db, { userId, photoDir, body });
    return reply.send(result);
  });

  app.put('/api/bar-items/:ingredientId', { bodyLimit: AccountLimits.maxHomeBarItemBodyBytes }, async (request, reply) => {
    const userId = await requireSession(request);
    // Fastify exposes decoded route parameters, so an encoded route identity
    // receives the same normalization check as its body counterpart.
    const ingredientId = validateIngredientId((request.params as { ingredientId: string }).ingredientId);
    const body = validateHomeBarItemBody(request.body, ingredientId, clock().getTime());
    const result = await upsertHomeBarItem(db, { userId, body });
    return reply.send(result);
  });

  const photoUpdatedAtSchema = {
    querystring: {
      type: 'object', additionalProperties: false, required: ['updatedAt'],
      properties: { updatedAt: { type: 'string' } },
    },
  };

  app.put('/api/entries/:id/photo', { bodyLimit: AccountLimits.maxPhotoBytes, schema: photoUpdatedAtSchema },
    async (request, reply) => {
      const userId = await requireSession(request);
      const entryId = validateEntryId((request.params as { id: string }).id);
      const updatedAt = validatePhotoUpdatedAt((request.query as { updatedAt: string }).updatedAt, clock().getTime());
      const contentType = request.headers['content-type'];
      if (!contentType || !(PHOTO_CONTENT_TYPES as readonly string[]).includes(contentType)) throw unsupportedMediaType();
      const bytes = request.body as Buffer;
      // Defense in depth: `bodyLimit` above already rejects an oversized
      // request before this handler runs, but a stricter re-check here means
      // a future bodyLimit change (or a body Fastify parsed some other way)
      // can never let an over-quota buffer reach setEntryPhoto/disk.
      if (bytes.length > AccountLimits.maxPhotoBytes) throw payloadTooLarge();
      const sniffed = sniffPhotoType(bytes);
      if (!sniffed || sniffed !== contentType) throw unsupportedMediaType();

      const finalPath = photoPath(photoDir, userId, entryId);
      const tempPath = await writeTempFile(path.dirname(finalPath), bytes);
      try {
        const result = await setEntryPhoto(db, {
          userId, entryId, updatedAt, mime: sniffed, bytes: bytes.length, quotaBytes: AccountLimits.photoQuotaBytes,
        });
        if (result.outcome === 'not_found') { await discardTempFile(tempPath); throw notFound(); }
        if (result.outcome === 'quota_exceeded') { await discardTempFile(tempPath); throw quotaExceeded(); }
        if (result.outcome === 'applied') await commitTempFile(tempPath, finalPath);
        else await discardTempFile(tempPath);
        return reply.send(result.entry);
      } catch (error) {
        await discardTempFile(tempPath).catch(() => {});
        throw error;
      }
    });

  app.delete('/api/entries/:id/photo', { schema: photoUpdatedAtSchema }, async (request, reply) => {
    const userId = await requireSession(request);
    const entryId = validateEntryId((request.params as { id: string }).id);
    const updatedAt = validatePhotoUpdatedAt((request.query as { updatedAt: string }).updatedAt, clock().getTime());
    const result = await clearEntryPhoto(db, { userId, entryId, updatedAt });
    if (result.outcome === 'not_found') throw notFound();
    if (result.outcome === 'applied') await removePhotoFile(photoPath(photoDir, userId, entryId));
    return reply.send(result.entry);
  });

  app.get('/api/entries/:id/photo', async (request, reply) => {
    const userId = await requireSession(request);
    const entryId = validateEntryId((request.params as { id: string }).id);
    const entry = await findEntry(db, userId, entryId);
    if (!entry || !entry.hasPhoto) throw notFound();
    const mime = await getPhotoMime(db, userId, entryId);
    const bytes = await readPhotoFile(photoPath(photoDir, userId, entryId));
    if (!bytes || !mime) throw notFound();
    reply.header('Cache-Control', 'private, no-store');
    return reply.type(mime).send(bytes);
  });
}
