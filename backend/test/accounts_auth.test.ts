import test from 'node:test';
import assert from 'node:assert/strict';
import { createTestApp } from './support/accounts_test_app.js';
import { readConfig } from '../src/config.js';

async function register(app: Awaited<ReturnType<typeof createTestApp>>['app'], email: string, password: string) {
  return app.inject({ method: 'POST', url: '/api/auth/register', payload: { email, password } });
}

async function login(app: Awaited<ReturnType<typeof createTestApp>>['app'], email: string, password: string) {
  return app.inject({ method: 'POST', url: '/api/auth/login', payload: { email, password } });
}

test('register succeeds, normalizes email, and returns a session', async () => {
  const harness = await createTestApp();
  try {
    const response = await register(harness.app, '  Sam@Example.TEST ', 'correct-horse-battery');
    assert.equal(response.statusCode, 201);
    const body = response.json();
    assert.equal(body.user.email, 'sam@example.test');
    assert.match(body.user.id, /^[0-9a-f-]{36}$/);
    assert.ok(body.session.token);
    assert.ok(body.session.expiresAt);
  } finally { await harness.cleanup(); }
});

test('register rejects invalid email/password shapes with invalid_request', async () => {
  // A fresh harness per case: registration is rate-limited to 5/hour per IP,
  // and this asserts validation, not the rate limit (covered separately below).
  for (const payload of [
    { email: 'not-an-email', password: 'longenoughpassword' },
    { email: 'a@b.com', password: 'short' },
    { email: 'a@b.com', password: 'x'.repeat(129) },
    { email: '@b.com', password: 'longenoughpassword' },
    { email: 'a@', password: 'longenoughpassword' },
    { email: 'a b@c.com', password: 'longenoughpassword' },
  ]) {
    const harness = await createTestApp();
    try {
      const response = await harness.app.inject({ method: 'POST', url: '/api/auth/register', payload });
      assert.equal(response.statusCode, 400, JSON.stringify(payload));
      assert.equal(response.json().error.code, 'invalid_request');
    } finally { await harness.cleanup(); }
  }
});

test('register reports email_taken for a duplicate normalized email', async () => {
  const harness = await createTestApp();
  try {
    assert.equal((await register(harness.app, 'dup@example.test', 'correct-horse-battery')).statusCode, 201);
    const second = await register(harness.app, ' DUP@Example.test ', 'another-long-password');
    assert.equal(second.statusCode, 409);
    assert.equal(second.json().error.code, 'email_taken');
  } finally { await harness.cleanup(); }
});

test('login succeeds with correct credentials and returns a fresh session', async () => {
  const harness = await createTestApp();
  try {
    await register(harness.app, 'sam@example.test', 'correct-horse-battery');
    const response = await login(harness.app, 'Sam@Example.test', 'correct-horse-battery');
    assert.equal(response.statusCode, 200);
    assert.equal(response.json().user.email, 'sam@example.test');
  } finally { await harness.cleanup(); }
});

test('login fails with the same message for a wrong password and an unknown email', async () => {
  const harness = await createTestApp();
  try {
    await register(harness.app, 'sam@example.test', 'correct-horse-battery');
    const wrongPassword = await login(harness.app, 'sam@example.test', 'totally-wrong-password');
    const unknownEmail = await login(harness.app, 'ghost@example.test', 'totally-wrong-password');
    assert.equal(wrongPassword.statusCode, 401);
    assert.equal(unknownEmail.statusCode, 401);
    assert.equal(wrongPassword.json().error.code, 'invalid_credentials');
    assert.deepEqual(wrongPassword.json().error, unknownEmail.json().error);
  } finally { await harness.cleanup(); }
});

test('me requires a bearer token and returns the current user', async () => {
  const harness = await createTestApp();
  try {
    const { session } = (await register(harness.app, 'sam@example.test', 'correct-horse-battery')).json();
    const noAuth = await harness.app.inject({ method: 'GET', url: '/api/auth/me' });
    assert.equal(noAuth.statusCode, 401);
    const authed = await harness.app.inject({ method: 'GET', url: '/api/auth/me', headers: { authorization: `Bearer ${session.token}` } });
    assert.equal(authed.statusCode, 200);
    assert.equal(authed.json().user.email, 'sam@example.test');
  } finally { await harness.cleanup(); }
});

test('an unknown, expired, or revoked token gets 401 on every protected route', async () => {
  const harness = await createTestApp();
  try {
    const { session } = (await register(harness.app, 'sam@example.test', 'correct-horse-battery')).json();

    const bogus = await harness.app.inject({ method: 'GET', url: '/api/auth/me', headers: { authorization: 'Bearer not-a-real-token' } });
    assert.equal(bogus.statusCode, 401);

    harness.setNow('2026-10-14T12:00:00.000Z'); // 31 days later: past the 30-day expiry
    const expired = await harness.app.inject({ method: 'GET', url: '/api/auth/me', headers: { authorization: `Bearer ${session.token}` } });
    assert.equal(expired.statusCode, 401);
    harness.setNow('2026-09-13T12:00:00.000Z');

    const revokeResponse = await harness.app.inject({ method: 'POST', url: '/api/auth/logout', headers: { authorization: `Bearer ${session.token}` } });
    assert.equal(revokeResponse.statusCode, 204);
    const afterRevoke = await harness.app.inject({ method: 'GET', url: '/api/auth/me', headers: { authorization: `Bearer ${session.token}` } });
    assert.equal(afterRevoke.statusCode, 401);
  } finally { await harness.cleanup(); }
});

test('logout revokes only its own session, leaving other devices signed in', async () => {
  const harness = await createTestApp();
  try {
    await register(harness.app, 'sam@example.test', 'correct-horse-battery');
    const deviceA = (await login(harness.app, 'sam@example.test', 'correct-horse-battery')).json().session;
    const deviceB = (await login(harness.app, 'sam@example.test', 'correct-horse-battery')).json().session;
    assert.notEqual(deviceA.token, deviceB.token);

    await harness.app.inject({ method: 'POST', url: '/api/auth/logout', headers: { authorization: `Bearer ${deviceA.token}` } });
    const aAfter = await harness.app.inject({ method: 'GET', url: '/api/auth/me', headers: { authorization: `Bearer ${deviceA.token}` } });
    const bAfter = await harness.app.inject({ method: 'GET', url: '/api/auth/me', headers: { authorization: `Bearer ${deviceB.token}` } });
    assert.equal(aAfter.statusCode, 401);
    assert.equal(bAfter.statusCode, 200);
  } finally { await harness.cleanup(); }
});

test('login rate limiting returns 429 with Retry-After once the per-IP window is exceeded', async () => {
  const harness = await createTestApp();
  try {
    await register(harness.app, 'sam@example.test', 'correct-horse-battery');
    let limited = null;
    for (let i = 0; i < 15; i++) {
      const response = await login(harness.app, `nobody${i}@example.test`, 'totally-wrong-password');
      if (response.statusCode === 429) { limited = response; break; }
    }
    assert.ok(limited, 'expected a 429 after exceeding the login rate limit');
    assert.equal(limited!.json().error.code, 'rate_limited');
    assert.ok(limited!.headers['retry-after']);
  } finally { await harness.cleanup(); }
});

test('registration rate limiting returns 429 once the per-IP hourly window is exceeded', async () => {
  const harness = await createTestApp();
  try {
    let limited = null;
    for (let i = 0; i < 8; i++) {
      const response = await register(harness.app, `person${i}@example.test`, 'correct-horse-battery');
      if (response.statusCode === 429) { limited = response; break; }
    }
    assert.ok(limited, 'expected a 429 after exceeding the registration rate limit');
    assert.equal(limited!.json().error.code, 'rate_limited');
  } finally { await harness.cleanup(); }
});

test('config validation: DATABASE_URL, PHOTO_DIR, and HOST', () => {
  const base = { COCKTAIL_DB_API_KEY: '1', PORT: '3000', CORS_ORIGINS: 'http://localhost:5173' };
  assert.throws(() => readConfig({ ...base }), /DATABASE_URL/);
  assert.throws(() => readConfig({ ...base, DATABASE_URL: 'mysql://x/y' }), /DATABASE_URL/);
  assert.throws(() => readConfig({ ...base, DATABASE_URL: 'not-a-url' }), /DATABASE_URL/);
  const good = readConfig({ ...base, DATABASE_URL: 'postgres://user:pass@localhost:5432/zest' });
  assert.equal(good.databaseUrl, 'postgres://user:pass@localhost:5432/zest');
  assert.equal(good.photoDir, './data/photos');
  assert.equal(good.host, '127.0.0.1');

  const withPhotoDir = readConfig({ ...base, DATABASE_URL: 'postgresql://localhost/zest', PHOTO_DIR: '/tmp/x' });
  assert.equal(withPhotoDir.photoDir, '/tmp/x');
  assert.throws(() => readConfig({ ...base, DATABASE_URL: 'postgres://localhost/zest', PHOTO_DIR: '' }), /PHOTO_DIR/);

  for (const host of ['127.0.0.1', '::1', '0.0.0.0', '192.168.1.20']) {
    assert.equal(readConfig({ ...base, DATABASE_URL: 'postgres://localhost/zest', HOST: host }).host, host);
  }
  for (const host of ['evil.example', 'not-an-ip', '999.999.999.999', '']) {
    assert.throws(() => readConfig({ ...base, DATABASE_URL: 'postgres://localhost/zest', HOST: host }), /HOST/);
  }
});

test('never logs or returns a password, hash, or token in an error body', async () => {
  const harness = await createTestApp();
  try {
    const response = await register(harness.app, 'sam@example.test', 'super-secret-password');
    assert.doesNotMatch(response.body, /super-secret-password/);
    assert.doesNotMatch(response.body, /\$argon2/);
    const duplicate = await register(harness.app, 'sam@example.test', 'super-secret-password');
    assert.doesNotMatch(duplicate.body, /super-secret-password|\$argon2/);
  } finally { await harness.cleanup(); }
});
