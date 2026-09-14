import test from 'node:test';
import assert from 'node:assert/strict';
import { gunzipSync } from 'node:zlib';
import { createTestApp } from './support/accounts_test_app.js';
import { publishCatalog } from '../src/catalog/store.js';
import type { Db } from '../src/accounts/db.js';

function drink(id: string, name: string) {
  return { idDrink: id, strDrink: name, strInstructions: 'Stir synthetic ingredients.', strIngredient1: 'Synthetic gin' };
}

async function seedCatalog(db: Db, opts: { version: string; publishedAt: string; drinks: ReturnType<typeof drink>[] }) {
  await publishCatalog(db, {
    version: opts.version, recipeCount: opts.drinks.length, publishedAt: opts.publishedAt, checkedAt: opts.publishedAt,
    drinks: opts.drinks.map((d) => ({ providerId: d.idDrink, name: d.strDrink, source: JSON.stringify(d) })),
  });
}

test('GET /api/catalog returns 503 catalog_unavailable before the first publish', async () => {
  const harness = await createTestApp();
  try {
    const response = await harness.app.inject({ method: 'GET', url: '/api/catalog' });
    assert.equal(response.statusCode, 503);
    assert.deepEqual(response.json(), { error: { code: 'catalog_unavailable', message: response.json().error.message } });
  } finally {
    await harness.cleanup();
  }
});

test('GET /api/catalog serves the wire shape with a quoted strong ETag and no-cache override', async () => {
  const harness = await createTestApp();
  try {
    await seedCatalog(harness.db, {
      version: 'a'.repeat(64), publishedAt: '2026-09-14T08:00:00.000Z',
      drinks: [drink('11007', 'Margarita'), drink('5', 'Synthetic Sour')],
    });
    const response = await harness.app.inject({ method: 'GET', url: '/api/catalog' });
    assert.equal(response.statusCode, 200);
    assert.equal(response.headers.etag, `"${'a'.repeat(64)}"`);
    assert.equal(response.headers['cache-control'], 'no-cache');
    assert.equal(response.headers.vary, 'Accept-Encoding');
    const body = response.json();
    assert.equal(body.version, 'a'.repeat(64));
    assert.equal(body.recipeCount, 2);
    assert.equal(body.publishedAt, '2026-09-14T08:00:00.000Z');
    assert.deepEqual(body.attribution, { name: 'TheCocktailDB', url: 'https://www.thecocktaildb.com' });
    // Wire order: shortest provider id first, then lexical.
    assert.deepEqual(body.drinks.map((d: { idDrink: string }) => d.idDrink), ['5', '11007']);
  } finally {
    await harness.cleanup();
  }
});

test('a matching If-None-Match gets 304 with no body', async () => {
  const harness = await createTestApp();
  try {
    const version = 'b'.repeat(64);
    await seedCatalog(harness.db, { version, publishedAt: '2026-09-14T08:00:00.000Z', drinks: [drink('1', 'One')] });
    const response = await harness.app.inject({
      method: 'GET', url: '/api/catalog', headers: { 'if-none-match': `"${version}"` },
    });
    assert.equal(response.statusCode, 304);
    assert.equal(response.rawPayload.length, 0);
    assert.equal(response.headers.etag, `"${version}"`);
  } finally {
    await harness.cleanup();
  }
});

test('a stale If-None-Match still gets 200 with the current version', async () => {
  const harness = await createTestApp();
  try {
    const version = 'c'.repeat(64);
    await seedCatalog(harness.db, { version, publishedAt: '2026-09-14T08:00:00.000Z', drinks: [drink('1', 'One')] });
    const response = await harness.app.inject({
      method: 'GET', url: '/api/catalog', headers: { 'if-none-match': `"${'d'.repeat(64)}"` },
    });
    assert.equal(response.statusCode, 200);
  } finally {
    await harness.cleanup();
  }
});

test('gzip is used when accepted, with Content-Encoding and Vary, and the plain body matches', async () => {
  const harness = await createTestApp();
  try {
    const version = 'e'.repeat(64);
    await seedCatalog(harness.db, {
      version, publishedAt: '2026-09-14T08:00:00.000Z',
      drinks: [drink('11007', 'Margarita'), drink('11008', 'Mojito')],
    });

    const plain = await harness.app.inject({ method: 'GET', url: '/api/catalog' });
    assert.equal(plain.headers['content-encoding'], undefined);

    const gzipped = await harness.app.inject({
      method: 'GET', url: '/api/catalog', headers: { 'accept-encoding': 'gzip, deflate' },
    });
    assert.equal(gzipped.statusCode, 200);
    assert.equal(gzipped.headers['content-encoding'], 'gzip');
    assert.equal(gzipped.headers.vary, 'Accept-Encoding');
    const decompressed = gunzipSync(gzipped.rawPayload).toString('utf-8');
    assert.equal(decompressed, plain.body);
  } finally {
    await harness.cleanup();
  }
});

test('the in-memory body cache is invalidated when a new version publishes', async () => {
  const harness = await createTestApp();
  try {
    await seedCatalog(harness.db, { version: 'f'.repeat(64), publishedAt: '2026-09-14T08:00:00.000Z', drinks: [drink('1', 'One')] });
    const first = await harness.app.inject({ method: 'GET', url: '/api/catalog' });
    assert.equal(first.json().recipeCount, 1);
    assert.equal(first.headers.etag, `"${'f'.repeat(64)}"`);

    await seedCatalog(harness.db, {
      version: 'g'.repeat(64), publishedAt: '2026-09-14T09:00:00.000Z',
      drinks: [drink('1', 'One'), drink('2', 'Two')],
    });
    const second = await harness.app.inject({ method: 'GET', url: '/api/catalog' });
    assert.equal(second.headers.etag, `"${'g'.repeat(64)}"`);
    assert.equal(second.json().recipeCount, 2);
    assert.deepEqual(second.json().drinks.map((d: { idDrink: string }) => d.idDrink), ['1', '2']);
  } finally {
    await harness.cleanup();
  }
});

test('the catalog route is rate limited independently of the accounts limiter', async () => {
  const harness = await createTestApp({ catalogRateLimit: { max: 2, timeWindow: '1 minute' } });
  try {
    await seedCatalog(harness.db, { version: 'h'.repeat(64), publishedAt: '2026-09-14T08:00:00.000Z', drinks: [drink('1', 'One')] });
    const first = await harness.app.inject({ method: 'GET', url: '/api/catalog' });
    const second = await harness.app.inject({ method: 'GET', url: '/api/catalog' });
    const third = await harness.app.inject({ method: 'GET', url: '/api/catalog' });
    assert.equal(first.statusCode, 200);
    assert.equal(second.statusCode, 200);
    assert.equal(third.statusCode, 429);
    assert.equal(third.json().error.code, 'rate_limited');
  } finally {
    await harness.cleanup();
  }
});

test('the no-cache override does not leak onto other routes', async () => {
  const harness = await createTestApp();
  try {
    await seedCatalog(harness.db, { version: 'i'.repeat(64), publishedAt: '2026-09-14T08:00:00.000Z', drinks: [drink('1', 'One')] });
    const catalogResponse = await harness.app.inject({ method: 'GET', url: '/api/catalog' });
    assert.equal(catalogResponse.headers['cache-control'], 'no-cache');
    const health = await harness.app.inject({ method: 'GET', url: '/api/health' });
    assert.equal(health.headers['cache-control'], 'no-store');
  } finally {
    await harness.cleanup();
  }
});
