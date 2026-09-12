# Local recipe gateway — M5 prerequisite

Adam approved the local gateway after purchasing premium access and reporting that he confirmed provider terms. This explicitly supersedes the original empty-backend-until-M7 agreement. Development only: no Docker, Compose, Nginx, hosting, auth or backend database. [Setup](../backend/README.md).

## Boundary

Flutter sends recipe requests to the gateway. The gateway alone attaches the provider key to a fixed HTTPS TheCocktailDB **V2** URL. V2, not V1: purchased keys are issued as V2 keys, and V1 letter browse returns an empty 200 body for them (verified live 2026-09-12 — every allowlisted operation, including the no-data shape, works on V2 with the paid key; the public test key also works on V2 with smaller result sets). Images and canonical attribution links remain direct provider references; the gateway neither downloads nor mirrors images. Existing client-side matching, aliases, measures, models, caching and the Botanical Play UI are unchanged. M5 catalog storage, graph computation and graph-first home are still separate work. Popular/recent/multi-ingredient endpoints are not added just because the paid key supports them.

The gateway intentionally keeps the current provider-shaped `drinks` envelope and source fields. Only parameter validation, boundary/schema validation, caching and error handling happen here. Null or empty results remain valid; malformed envelopes and records are errors, never fabricated empty success. No arbitrary upstream URL, endpoint, version or API key may be supplied by clients.

**No-match string shape (observed 2026-09-13, public test key only):** `filter.php` for an ingredient with no matches answers `200 OK` with `{"drinks":"None Found"}` — a string, not the `null`/array shapes the contract otherwise validates against. Confirmed live against `v2/1/filter.php` for a partial-name miss (`i=Coca`), a working ingredient (`i=Gin`, ordinary array), and a nonsense ingredient (same `"None Found"` string); not verified against the paid key, which may differ. The gateway normalizes this exact string (case-insensitively, trimmed; `"None Found"` or `"no data found"`) to `drinks: null` before validation, so it returns the same `200 { "drinks": null }` empty result as a genuine null — any other non-null, non-array `drinks` value is still rejected as `invalid_response`.

## API

| Local GET route | Accepted query | Purpose |
| --- | --- | --- |
| `/api/health` | None needed | Local liveness; does not test the provider |
| `/api/cocktails/search.php` | Exactly `s` or `f` | Name or one ASCII first letter |
| `/api/cocktails/filter.php` | Exactly `i` | One ingredient, summaries only |
| `/api/cocktails/lookup.php` | Exactly numeric `i` | Full recipe or missing result |
| `/api/cocktails/list.php` | Exactly `i=list` | Ingredient names |

Search/ingredient values are trimmed, limited to 200 characters and reject control characters/blank values. Ingredient commas are rejected: multi-ingredient matching is not this contract. IDs are 1–20 digits. Duplicate/unknown query keys, mixed search modes and unsupported routes/methods are rejected. First letters normalize to lowercase. Name case is preserved in cache keys. Full recipes retain original metadata, slots, text and measures; lookup IDs/counts must match the request. Ingredient names are not treated as availability.

## Failures and limits

- Defaults: 8-second upstream header/body deadline, 2 MiB response-body limit, 4 distinct concurrent upstream calls, no waiting queue. Extra distinct calls get `503 service_busy` with `Retry-After: 1`; identical in-flight requests share work.
- Cache: successful validated JSON only, 10-minute TTL, 64 entries and 8 MiB total serialized UTF-8 payload, LRU eviction. These are payload bounds, not exact JavaScript heap bounds. Both gateway and Flutter caches are memory-only. A single item above the cache budget is served but not cached; above the response limit is rejected. No timers refresh records or preload the catalog.
- A provider `429` sets a gateway-wide absolute deadline. Numeric seconds and HTTP-date `Retry-After` values are supported; otherwise 30 seconds. Overlapping responses only extend the deadline. Waiting clients receive integer remaining seconds and no automatic retries. Successful cache hits may be served during cooldown without upstream traffic. Flutter additionally retains its existing shared UI cooldown.
- Deadline/close abort upstream work; noncooperative late results cannot enter the cache. A client disconnect does not cancel shared work needed by other callers; it remains bounded by the upstream deadline. Redirects are not followed.
- Errors return `{ "error": { "code": "…", "message": "…" } }`, never raw bodies, URLs, stack traces or key-bearing exceptions. Upstream failures become 502, timeouts 504, cooldown 429; invalid caller input is 400. Flutter maps 504 to its timeout UX and continues to handle 429 manually. Logs are disabled for requests; startup prints only a fixed local address or a sanitized failure.
- Limits are Zest's conservative development policy, not claimed provider quotas.

## Secrets and browser access

`COCKTAIL_DB_API_KEY` exists only in the backend environment (ignored `.env` supported), default public test key `1`. The example file contains no private key. Node validates configuration without echoing values; env loading is only part of user-run server commands, never tests. No key was requested/read for implementation or verification.

Flutter uses `ZEST_API_BASE_URL`, default `http://127.0.0.1:3000/api/cocktails/`. The base must be absolute, end in `/`, have no credentials/query/fragment, and use HTTPS except loopback HTTP. There is no direct-provider fallback and no `COCKTAIL_DB_API_KEY` frontend define. Backend unavailability produces the existing recoverable error UI.

The process binds only `127.0.0.1`. CORS accepts explicitly configured loopback origins, default `http://localhost:5173` and `http://127.0.0.1:5173`; no wildcard or credentialed cookies. The origin check precedes preflight handling. Browser clients can read `Retry-After`. Native/no-Origin requests are allowed. CORS is not authentication: trusted local processes can call this development service. Public deployment requires a separate access-control, abuse-rate-limit, TLS and secret-management review. No public deployment readiness is claimed.

## Dependencies and verification

Approved additions: Fastify for request routing/schema validation and injected HTTP tests; `@fastify/cors` for browser protocol handling; TypeScript and Node types for strict checking; `tsx` for development/test execution. Uses Node's built-in fetch, streams, env-file loader and test runner—no HTTP client, env loader, cache service or test-framework dependency. `package-lock.json` is committed; install with `npm ci`.

The finite backend demo uses Fastify injection; the cross-language `dart run tool/gateway_demo.dart` transports Flutter requests to the real Fastify routes in one-shot Node processes with a synthetic upstream. It validates all five operations and preserved source measures without opening a socket. Ordinary Flutter tests remain independent of Node. See [verification](VERIFICATION.md) and [review](reviews/GATEWAY.md) for results and the still-unverified browser/WASM runtime.

Official references checked 2026-09-12: [Fastify TypeScript](https://fastify.dev/docs/latest/Reference/TypeScript/), [Fastify testing](https://fastify.dev/docs/latest/Guides/Testing/), [Fastify CORS](https://github.com/fastify/fastify-cors), [Node env-file loading](https://nodejs.org/api/cli.html#--env-file-if-existsfile), [TheCocktailDB documentation](https://www.thecocktaildb.com/documentation). Registry versions were verified before installation. Provider documentation has known coverage/terms ambiguities; Adam's report of confirmation is recorded, not represented as independently verified private correspondence.
