# Zest local recipe gateway, accounts, and personal-data sync

The paid provider key stays here, not in Flutter. The service also holds accounts, sessions, each person's synced collection, and their M10 home-bar and shopping-list records — see [docs/ACCOUNTS.md](../docs/ACCOUNTS.md) and [docs/M10.md](../docs/M10.md) for the contracts. Everything below is development-only: there is no deployment, HTTPS, Nginx, or backup story yet.

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
