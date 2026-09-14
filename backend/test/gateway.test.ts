import test from 'node:test';
import assert from 'node:assert/strict';
import { buildApp } from '../src/app.js';

const drink = (id = '42', name = 'Synthetic Sour') => ({
  idDrink: id, strDrink: name, strInstructions: 'Stir synthetic ingredients.',
  strIngredient1: 'Synthetic gin', strMeasure1: '1 oz',
});

function jsonResponse(value: unknown, init: ResponseInit = {}): Response {
  return new Response(JSON.stringify(value), {
    status: 200, headers: { 'content-type': 'application/json' }, ...init,
  });
}

function fetcherFor(value: unknown, calls: string[] = []) {
  return async (url: string, _init: RequestInit) => {
    calls.push(url);
    return jsonResponse(value);
  };
}

async function withApp(fetcher: (url: string, init: RequestInit) => Promise<Response>, fn: (app: ReturnType<typeof buildApp>) => Promise<void>, options: Record<string, unknown> = {}) {
  const app = buildApp({ apiKey: 'synthetic-key', fetcher, ...options });
  try { await app.ready(); await fn(app); } finally { await app.close(); }
}

test('health is local and does not call the provider', async () => {
  let calls = 0;
  await withApp(async () => { calls++; return jsonResponse({ drinks: [] }); }, async (app) => {
    const response = await app.inject({ method: 'GET', url: '/api/health' });
    assert.equal(response.statusCode, 200);
    assert.deepEqual(response.json(), { status: 'ok' });
  });
  assert.equal(calls, 0);
});

test('lookup.php preserves the validated source response', async () => {
  const payload = { drinks: [drink()] };
  await withApp(fetcherFor(payload), async (app) => {
    const response = await app.inject({ method: 'GET', url: '/api/cocktails/lookup.php?i=42' });
    assert.equal(response.statusCode, 200);
    assert.deepEqual(response.json(), payload);
  });
});

test('provider URL is fixed to the allowlisted authority, endpoint, parameter, and key', async () => {
  const calls: string[] = [];
  await withApp(fetcherFor({ drinks: [drink()] }, calls), async (app) => {
    const response = await app.inject({ method: 'GET', url: '/api/cocktails/lookup.php?i=42' });
    assert.equal(response.statusCode, 200);
  });
  assert.equal(calls.length, 1);
  assert.equal(calls[0], 'https://www.thecocktaildb.com/api/json/v2/synthetic-key/lookup.php?i=42');
});

test('unknown paths, parameters, duplicates, and unsafe values are rejected', async () => {
  await withApp(fetcherFor({ drinks: [drink()] }), async (app) => {
    for (const url of [
      '/api/cocktails/lookup.php?i=1&s=x', '/api/cocktails/lookup.php?x=x',
      '/api/cocktails/lookup.php?i=x%00', '/api/cocktails/lookup.php?i=abc',
      '/api/cocktails/search.php?s=x', '/api/cocktails/filter.php?i=x',
      '/api/cocktails/list.php?i=list', '/api/nope',
    ]) {
      const response = await app.inject({ method: 'GET', url });
      assert.ok(response.statusCode >= 400, `${url} unexpectedly accepted`);
      assert.doesNotMatch(response.body, /thecocktaildb|synthetic-key|https?:\/\//i);
    }
  });
});

test('disallowed origins are rejected and native requests without Origin are accepted', async () => {
  await withApp(fetcherFor({ drinks: [] }), async (app) => {
    const denied = await app.inject({ method: 'GET', url: '/api/health', headers: { origin: 'https://evil.example' } });
    assert.equal(denied.statusCode, 403);
    const native = await app.inject({ method: 'GET', url: '/api/health' });
    assert.equal(native.statusCode, 200);
    const wildcard = await app.inject({ method: 'GET', url: '/api/health', headers: { origin: '*' } });
    assert.equal(wildcard.statusCode, 403);
  });
});

test('cache deduplicates concurrent calls, serves TTL entries, and evicts by LRU/entry bounds', async () => {
  const calls: string[] = [];
  let now = 0;
  let release!: () => void;
  const gate = new Promise<void>((resolve) => { release = resolve; });
  const fetcher = async (url: string) => { calls.push(url); await gate; return jsonResponse({ drinks: [drink('1')] }); };
  await withApp(fetcher, async (app) => {
    const one = app.inject({ method: 'GET', url: '/api/cocktails/lookup.php?i=1' });
    const two = app.inject({ method: 'GET', url: '/api/cocktails/lookup.php?i=1' });
    release();
    assert.equal((await one).statusCode, 200); assert.equal((await two).statusCode, 200); assert.equal(calls.length, 1);
    assert.equal((await app.inject({ method: 'GET', url: '/api/cocktails/lookup.php?i=1' })).statusCode, 200);
    assert.equal(calls.length, 1);
    now = 1001;
    const expired = await app.inject({ method: 'GET', url: '/api/cocktails/lookup.php?i=1' });
    assert.equal(expired.statusCode, 200); assert.equal(calls.length, 2);
  }, { now: () => now, ttlMs: 1000, maxEntries: 1 });
});

test('cache respects byte bound and does not cache oversized bodies', async () => {
  let calls = 0;
  await withApp(async () => { calls++; return jsonResponse({ drinks: [drink('1')] }); }, async (app) => {
    assert.equal((await app.inject({ method: 'GET', url: '/api/cocktails/lookup.php?i=1' })).statusCode, 200);
    assert.equal((await app.inject({ method: 'GET', url: '/api/cocktails/lookup.php?i=1' })).statusCode, 200);
  }, { maxBytes: 1 });
  assert.equal(calls, 2);
});

test('shared 429 cooldown accepts seconds and HTTP-date Retry-After', async () => {
  let now = 10_000; let calls = 0;
  await withApp(async () => { calls++; return new Response('', { status: 429, headers: { 'retry-after': '5' } }); }, async (app) => {
    assert.equal((await app.inject({ method: 'GET', url: '/api/cocktails/lookup.php?i=1' })).statusCode, 429);
    const blocked = await app.inject({ method: 'GET', url: '/api/cocktails/lookup.php?i=2' });
    assert.equal(blocked.statusCode, 429); assert.equal(blocked.json().error.code, 'rate_limited');
    now += 5000;
    assert.equal((await app.inject({ method: 'GET', url: '/api/cocktails/lookup.php?i=2' })).statusCode, 429);
  }, { now: () => now });
  assert.equal(calls, 2);
  now = Date.parse('2030-01-01T00:00:00Z');
  await withApp(async () => new Response('', { status: 429, headers: { 'retry-after': 'Tue, 01 Jan 2030 00:00:05 GMT' } }), async (app) => {
    const response = await app.inject({ method: 'GET', url: '/api/cocktails/lookup.php?i=3' });
    assert.equal(response.statusCode, 429); assert.equal(response.headers['retry-after'], '5');
  }, { now: () => now });
});

test('upstream failures are safe and retry-after is exposed', async () => {
  await withApp(async () => new Response('', { status: 429, headers: { 'retry-after': '7' } }), async (app) => {
    const response = await app.inject({ method: 'GET', url: '/api/cocktails/lookup.php?i=1' });
    assert.equal(response.statusCode, 429); assert.equal(response.headers['retry-after'], '7');
    assert.deepEqual(response.json().error, { code: 'rate_limited', message: 'Recipe service request failed.' });
  });
  await withApp(async () => new Response('', { status: 500 }), async (app) => {
    const response = await app.inject({ method: 'GET', url: '/api/cocktails/lookup.php?i=1' });
    assert.equal(response.statusCode, 502); assert.doesNotMatch(response.body, /thecocktaildb|synthetic-key|https?:\/\//i);
  });
});

test('malformed, oversized, and schema-invalid upstream responses are rejected', async () => {
  for (const response of [new Response('{', { status: 200 }), jsonResponse({ nope: [] }), jsonResponse({ drinks: [{ idDrink: 'x', strDrink: 'bad' }] }), jsonResponse({ drinks: 'some other string' })]) {
    await withApp(async () => response.clone(), async (app) => {
      const result = await app.inject({ method: 'GET', url: '/api/cocktails/lookup.php?i=1' });
      assert.equal(result.statusCode, 502); assert.deepEqual(result.json().error.code, 'invalid_response');
    });
  }
  const huge = 'x'.repeat(128);
  await withApp(async () => new Response(huge), async (app) => {
    assert.equal((await app.inject({ method: 'GET', url: '/api/cocktails/lookup.php?i=1' })).statusCode, 502);
  }, { maxResponseBytes: 8 });
});

test('provider "no data" string shapes for drinks normalize to the valid empty result', async () => {
  for (const noData of ['None Found', 'no data found', 'NONE FOUND', '  None Found  ']) {
    await withApp(fetcherFor({ drinks: noData }), async (app) => {
      const response = await app.inject({ method: 'GET', url: '/api/cocktails/lookup.php?i=1' });
      assert.equal(response.statusCode, 200);
      assert.deepEqual(response.json(), { drinks: null });
    });
  }
});

test('timeout aborts the fetcher and returns a safe 504', async () => {
  let aborted = false;
  await withApp(async (_url, init) => new Promise<Response>((_, reject) => {
    init.signal?.addEventListener('abort', () => { aborted = true; reject(new Error('aborted')); });
  }), async (app) => {
    const response = await app.inject({ method: 'GET', url: '/api/cocktails/lookup.php?i=1' });
    assert.equal(response.statusCode, 504); assert.equal(response.json().error.code, 'upstream_timeout');
  }, { timeoutMs: 5 });
  assert.equal(aborted, true);
});

test('concurrency cap rejects excess distinct requests while allowing deduplication', async () => {
  let active = 0; let peak = 0; const resolvers: (() => void)[] = [];
  const fetcher = async () => { active++; peak = Math.max(peak, active); await new Promise<void>((resolve) => resolvers.push(resolve)); active--; return jsonResponse({ drinks: [] }); };
  await withApp(fetcher, async (app) => {
    const a = app.inject({ method: 'GET', url: '/api/cocktails/lookup.php?i=1' });
    const b = app.inject({ method: 'GET', url: '/api/cocktails/lookup.php?i=2' });
    await new Promise<void>((resolve) => setImmediate(resolve));
    const c = await app.inject({ method: 'GET', url: '/api/cocktails/lookup.php?i=3' });
    assert.equal(c.statusCode, 503); resolvers.splice(0).forEach((resolve) => resolve()); await a; await b;
  }, { maxConcurrent: 2 });
  assert.equal(peak, 2);
});
