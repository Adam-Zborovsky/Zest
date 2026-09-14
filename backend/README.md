# Zest local recipe gateway, accounts, and personal-data sync

The paid provider key stays here, not in Flutter. The service also holds accounts, sessions, each person's synced collection, and their M10 home-bar and shopping-list records — see [docs/ACCOUNTS.md](../docs/ACCOUNTS.md) and [docs/M10.md](../docs/M10.md) for the contracts. It also owns the shared M11 catalog snapshot — see "Shared catalog" below and [docs/M11.md](../docs/M11.md). Everything below is development-only: there is no deployment, HTTPS, Nginx, or backup story yet.

## Shared catalog (M11)

`GET /api/catalog` serves one versioned snapshot of TheCocktailDB's full drink catalog to every client, so devices no longer each run their own 26-request A–Z browse. It is unauthenticated and rate-limited (30/min per IP by default), unlike the accounts routes.

- **Refresh job** (`src/catalog/refresher.ts`): on startup, refreshes immediately if no snapshot has ever been published, the last check failed, or the last check was more than 24 hours ago; otherwise it schedules the next check for 24 hours after that check. It walks `search.php?f=` for all 26 letters through the same `RecipeGateway` the `lookup.php` route uses (so it shares the 429 cooldown), calling it directly rather than over HTTP — `search.php`, `filter.php` and `list.php` are no longer client-facing routes (M11: the client searches the local shared catalog instead) — pausing about a second between letters.
- **Retry on failure**: scheduling is a single self-rescheduling timer, not a fixed interval — a successful or unchanged run reschedules 24 hours out and resets the retry backoff, while a failed run schedules a retry instead of waiting out the rest of the day. The retry uses bounded exponential backoff starting at 5 minutes and doubling (5 → 10 → 20 → … minutes), capped at the 24-hour interval; a gateway `Retry-After` (e.g. from a 429) overrides the computed backoff when it asks for longer. Because there is only ever one pending timer, the 24-hour success cadence and the failure retries can never double-fire. Restarting the process after a failed check (`last_error_code` set) is treated the same as a stale snapshot: it retries promptly rather than waiting out `checked_at`'s age.
- **All-or-nothing**: a new version is published only once all 26 letters have fetched and validated. Drinks are deduplicated by `idDrink`, sorted per the frozen wire contract, and hashed (SHA-256 of the canonical JSON) into `version`. A zero-drink total counts as a failure, never an empty publish. Any failure — a 429 cooldown, an upstream error, an invalid envelope, or a storage error — leaves the previously published snapshot untouched; only `checked_at` and a short `last_error_code` move. Provider keys and URLs are never logged, matching the recipe gateway.
- **Storage**: `catalog_recipes` (one row per drink, holding the validated provider record verbatim as `source`) and a single-row `catalog_state` (`version`, `recipe_count`, `published_at`, `checked_at`, `last_error_code`) — migration `drizzle/0002_messy_purple_man.sql`. See [docs/SOURCES.md](../docs/SOURCES.md) for the persistence-rights record.
- **Endpoint**: `200` with a strong `ETag` (the version, quoted) and `Cache-Control: no-cache` (overriding the process-wide `no-store` for this route only); `304` on a matching `If-None-Match` (a comma-separated list, weak `W/"..."` validators, and `*` are all accepted, per RFC 9110's weak-comparison rule for this header); `503 catalog_unavailable` before the first publish; gzip via `node:zlib` when the client sends `Accept-Encoding: gzip`, with `Vary: Accept-Encoding`. The response body is serialized once per published version and held in memory, invalidated automatically once a newer version is read back from storage. State and drinks are read as one consistent pair (retried once if a publish lands between the two reads), so a served body's `version` always matches its `drinks`.
- Never blocks `app.listen`: the refresher starts afterwards and is closed before the database pool, in `server.ts`.

## Run locally

Use Node >=24 (verified on this PC with Node 26.3.0). From `backend/`:

```powershell
npm ci
```

Create your own ignored `.env` using `.env.example` as a template. Set `COCKTAIL_DB_API_KEY` there to your paid key. Do not paste it into chat, source files, frontend defines or terminal commands that could be logged. Without an override the documented public test key `1` is used; an empty/invalid override fails startup.

### Postgres (accounts, collection, home bar, and shopping list)

Start the local database with Docker Compose (Adam runs this; agents never do):

```powershell
docker compose -f docker-compose.dev.yml up -d
```

This runs `postgres:18.6-alpine`, bound to `127.0.0.1:5432` only, with a named volume mounted at `/var/lib/postgresql`. Postgres 18 images keep data in a versioned subdirectory there; mounting the old `/var/lib/postgresql/data` path makes the container fail to start. Credentials come from `.env` (`POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB`), matching `DATABASE_URL`; the defaults in `.env.example` are non-secret local development values, not production secrets.

Apply the committed migrations once the database is up:

```powershell
npm run db:migrate
```

`npm run db:generate` regenerates migrations from `src/accounts/schema.ts` after a schema change (needs no running database); commit the generated files in `drizzle/`.

Photo files are written under `PHOTO_DIR` (default `./data/photos`), one file per entry at `PHOTO_DIR/<userId>/<entryId>`. Both `data/` and `.env` are ignored by git.

Then run the server:

```powershell
npm run dev
```

This user-run watcher binds `HOST` (default `127.0.0.1`) on `PORT` (default `3000`). In another terminal, from `frontend/`:

```powershell
flutter run -d chrome --web-port=5173
```

The web port must match `CORS_ORIGINS`; both `http://localhost:5173` and `http://127.0.0.1:5173` are allowed by default. Different ports require explicit configuration. To change the gateway address, pass Flutter `--dart-define=ZEST_API_BASE_URL=http://127.0.0.1:3000/api/cocktails/` (trailing slash required); the account and sync base is that URL resolved against `../`. Do not set `COCKTAIL_DB_API_KEY` in Flutter: it no longer reads it.

Health: `http://127.0.0.1:3000/api/health`. This checks the local process, not premium credentials, upstream availability, or the database connection.

### Reaching the server from a phone (LAN exposure warning)

By default the server binds `127.0.0.1` and is not reachable from another device. To test from a phone on the same Wi-Fi, set `HOST=0.0.0.0` in `.env` and use the PC's LAN IP (e.g. `http://192.168.1.20:3000/api/cocktails/`) as Flutter's `ZEST_API_BASE_URL`.

**This exposes both the recipe gateway and the accounts/photo endpoints to every device on that Wi-Fi network**, not just the phone being tested — anyone on the same LAN could reach the API (though CORS still blocks browser-origin requests from disallowed origins; it is not access control against other native clients, and there is no TLS). Only do this on a trusted home network, and set `HOST` back to `127.0.0.1` when done. The server also prints a warning at startup whenever `HOST` is not loopback.

### Known gaps before any deployment

- No password reset or email verification (accounts are unrecoverable if the password is lost).
- Registration reveals whether an email is already registered (`email_taken`), an accepted enumeration trade-off for a local, account-required app.
- No HTTPS, so tokens and photos travel in cleartext over the LAN when `HOST=0.0.0.0`.
- No backups of the Postgres volume or photo directory.

## Finite verification

From `backend/`:

```powershell
npm run typecheck
npm test
npm run build
npm run demo
```

Tests use `@electric-sql/pglite` (an in-process Postgres) with the committed migrations applied, a temporary photo directory, and cheap Argon2 parameters — no Docker container or `.env` is read.

From `frontend/`:

```powershell
flutter analyze
flutter test
dart run tool/gateway_demo.dart
```

Both demos use synthetic upstream data. Neither starts a listening server nor uses a real provider key or database. The cross-language demo requires backend dependencies installed.

See [GATEWAY.md](../docs/GATEWAY.md) for the recipe gateway's endpoints, limits and security boundaries, [ACCOUNTS.md](../docs/ACCOUNTS.md) for accounts, collection sync, and photos, and [M10.md](../docs/M10.md) for the home-bar wire and sync rules. Deployment and public-access hardening are future work, not implied by a successful local build.
