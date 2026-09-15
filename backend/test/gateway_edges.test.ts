import test from 'node:test';
import assert from 'node:assert/strict';
import { RecipeGateway } from '../src/gateway.js';
import { buildApp } from '../src/app.js';

const operation = (value: string) => ({ endpoint: 'search.php' as const, parameter: 's' as const, value });
const source = { drinks: [{ idDrink: '99101', strDrink: 'Paper Seed',
  strInstructions: 'An invented instruction.', strIngredient1: 'Imaginary syrup', strMeasure1: 'A fictional measure' }] };

test('LRU reads promote entries and total serialized bytes bound the cache', async () => {
  for (const limits of [{ maxEntries: 2 }, { maxBytes: Buffer.byteLength(JSON.stringify(source)) * 2 }]) {
    let calls = 0;
    const gateway = new RecipeGateway({ apiKey: '1', ...limits, fetcher: async () => { calls++; return Response.json(source); } });
    try {
      await gateway.get(operation('a')); await gateway.get(operation('b'));
      await gateway.get(operation('a')); await gateway.get(operation('c'));
      await gateway.get(operation('a')); assert.equal(calls, 3);
      await gateway.get(operation('b')); assert.equal(calls, 4);
    } finally { gateway.close(); }
  }
});

test('a later short 429 never shortens another in-flight request cooldown', async () => {
  let now = 0;
  const releases = new Map<string, (response: Response) => void>();
  const gateway = new RecipeGateway({ apiKey: '1', now: () => now,
    fetcher: (url) => new Promise((resolve) => { releases.set(new URL(url).searchParams.get('s')!, resolve); }) });
  try {
    const long = assert.rejects(gateway.get(operation('long')), { status: 429, retryAfter: 60 });
    const short = assert.rejects(gateway.get(operation('short')), { status: 429, retryAfter: 60 });
    releases.get('long')!(new Response(null, { status: 429, headers: { 'retry-after': '60' } }));
    await long;
    releases.get('short')!(new Response(null, { status: 429, headers: { 'retry-after': '1' } }));
    await short;
    now = 2000;
    await assert.rejects(gateway.get(operation('blocked')), { status: 429, retryAfter: 58 });
    assert.equal(releases.size, 2);
  } finally { gateway.close(); }
});

test('a noncooperative timed-out fetch cannot seed the cache later', async () => {
  let calls = 0;
  let release!: (response: Response) => void;
  const gateway = new RecipeGateway({ apiKey: '1', timeoutMs: 5, fetcher: () => {
    calls++;
    if (calls === 1) return new Promise((resolve) => { release = resolve; });
    return Promise.resolve(Response.json(source));
  } });
  try {
    await assert.rejects(gateway.get(operation('same')), { status: 504 });
    release(Response.json(source));
    await new Promise<void>((resolve) => setImmediate(resolve));
    await gateway.get(operation('same'));
    assert.equal(calls, 2);
  } finally { gateway.close(); }
});

test('body-stream timeout cancels the stream; close aborts outstanding work', async () => {
  let cancelled = false;
  const gateway = new RecipeGateway({ apiKey: '1', timeoutMs: 5, fetcher: async () =>
    new Response(new ReadableStream({ cancel() { cancelled = true; } })) });
  await assert.rejects(gateway.get(operation('slow-body')), { status: 504 });
  assert.equal(cancelled, true);
  gateway.close();
  await assert.rejects(gateway.get(operation('closed')), { status: 503 });

  let aborted = false;
  const pending = new RecipeGateway({ apiKey: '1', fetcher: (_url, init) => {
    init.signal!.addEventListener('abort', () => { aborted = true; });
    return new Promise(() => {});
  } });
  const rejection = assert.rejects(pending.get(operation('close')), { status: 503 });
  pending.close(); await rejection;
  assert.equal(aborted, true);
});

test('errors are not cached and redirect following is explicitly disabled', async () => {
  let calls = 0;
  const app = buildApp({ apiKey: 'synthetic-private-key', fetcher: async (_url, init) => {
    assert.equal(init.redirect, 'error');
    if (++calls === 1) throw new Error('https://provider.invalid/synthetic-private-key');
    return Response.json(source);
  } });
  try {
    const first = await app.inject('/api/cocktails/lookup.php?i=99101');
    assert.equal(first.statusCode, 502);
    assert.doesNotMatch(first.body, /synthetic-private-key|provider.invalid/);
    assert.equal((await app.inject('/api/cocktails/lookup.php?i=99101')).statusCode, 200);
    assert.equal(calls, 2);
  } finally { await app.close(); }
});

test('duplicate/extra query fields and unsupported methods never reach upstream', async () => {
  let calls = 0;
  const app = buildApp({ apiKey: '1', fetcher: async () => { calls++; return Response.json(source); } });
  try {
    for (const query of ['i=1&i=2', 'i=1&apiKey=override', 'i=1&url=https://evil.invalid', 'i=%20%20', `i=${'1'.repeat(21)}`]) {
      assert.equal((await app.inject(`/api/cocktails/lookup.php?${query}`)).statusCode, 400);
    }
    assert.equal((await app.inject({ method: 'POST', url: '/api/cocktails/lookup.php?i=1' })).statusCode, 404);
    assert.equal(calls, 0);
  } finally { await app.close(); }
});

test('removed client-facing routes 404', async () => {
  const app = buildApp({ apiKey: '1', fetcher: async () => Response.json(source) });
  try {
    for (const url of ['/api/cocktails/search.php?s=x', '/api/cocktails/filter.php?i=x', '/api/cocktails/list.php?i=list']) {
      assert.equal((await app.inject({ method: 'GET', url })).statusCode, 404);
    }
    assert.equal((await app.inject({ method: 'GET', url: '/api/cocktails/lookup.php?i=99101' })).statusCode, 200);
  } finally { await app.close(); }
});

test('browser CORS allows the configured origin and exposes cooldown, never credentials', async () => {
  const app = buildApp({ apiKey: '1', fetcher: async () => Response.json(source) });
  try {
    const response = await app.inject({ url: '/api/health', headers: { origin: 'http://localhost:5173' } });
    assert.equal(response.headers['access-control-allow-origin'], 'http://localhost:5173');
    assert.equal(response.headers['access-control-allow-credentials'], undefined);
    assert.equal(response.headers['access-control-expose-headers'], 'Retry-After');
    const preflight = await app.inject({ method: 'OPTIONS', url: '/api/cocktails/lookup.php', headers: {
      origin: 'http://localhost:5173', 'access-control-request-method': 'GET',
    } });
    assert.equal(preflight.statusCode, 204);
    const denied = await app.inject({ method: 'OPTIONS', url: '/api/cocktails/lookup.php', headers: {
      origin: 'https://evil.invalid', 'access-control-request-method': 'GET',
    } });
    assert.equal(denied.statusCode, 403);
  } finally { await app.close(); }
});

test('CORS preflight for the conditional catalog GET allows If-None-Match, and a GET with Origin still works', async () => {
  const app = buildApp({ apiKey: '1', fetcher: async () => Response.json(source) });
  try {
    const preflight = await app.inject({ method: 'OPTIONS', url: '/api/catalog', headers: {
      origin: 'http://localhost:5173', 'access-control-request-method': 'GET',
      'access-control-request-headers': 'If-None-Match',
    } });
    assert.equal(preflight.statusCode, 204);
    assert.match(preflight.headers['access-control-allow-headers'] as string, /if-none-match/i);
    const response = await app.inject({
      method: 'GET', url: '/api/health', headers: { origin: 'http://localhost:5173', 'if-none-match': '"anything"' },
    });
    assert.equal(response.statusCode, 200);
    assert.equal(response.headers['access-control-allow-origin'], 'http://localhost:5173');
  } finally { await app.close(); }
});
