import test from 'node:test';
import assert from 'node:assert/strict';
import { readConfig } from '../src/config.js';

test('readConfig uses safe test defaults and ignores unrelated environment', () => {
  assert.deepEqual(readConfig({}), {
    apiKey: '1', port: 3000,
    origins: ['http://localhost:5173', 'http://127.0.0.1:5173'],
  });
  assert.equal(readConfig({ COCKTAIL_DB_API_KEY: 'test_key-2', PORT: '8080', CORS_ORIGINS: 'http://localhost:5173' }).apiKey, 'test_key-2');
});

test('provider key is validated without accepting arbitrary URL/path injection', () => {
  for (const apiKey of ['', 'key/secret', 'key?x=y', 'key with spaces', 'x'.repeat(257)]) {
    assert.throws(() => readConfig({ COCKTAIL_DB_API_KEY: apiKey }), /COCKTAIL_DB_API_KEY/);
  }
  assert.equal(readConfig({ COCKTAIL_DB_API_KEY: 'A_b-9' }).apiKey, 'A_b-9');
});

test('port accepts only an integer TCP port in range', () => {
  for (const port of ['', '0', '65536', '3.5', '-1', '1e3', ' 3000']) {
    assert.throws(() => readConfig({ PORT: port }), /PORT/);
  }
  assert.equal(readConfig({ PORT: '65535' }).port, 65535);
  assert.equal(readConfig({ PORT: '1' }).port, 1);
});

test('CORS origins are exact loopback HTTP(S) origins, deduplicated', () => {
  const config = readConfig({ CORS_ORIGINS: 'http://localhost:5173, https://127.0.0.1:8443,http://localhost:5173' });
  assert.deepEqual(config.origins, ['http://localhost:5173', 'https://127.0.0.1:8443']);
  for (const origins of [
    '', '*', 'https://evil.example', 'http://localhost:5173/path',
    'http://localhost:5173/', 'ftp://localhost:5173', 'http://0.0.0.0:5173',
    'http://[::1]:5173/path', 'http://localhost:5173,https://evil.example',
  ]) {
    assert.throws(() => readConfig({ CORS_ORIGINS: origins }), /CORS_ORIGINS/);
  }
});
