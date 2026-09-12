# Zest local recipe gateway

The paid provider key stays here, not in Flutter. Adam approved this development-only prerequisite before M5; accounts/authentication remain M7 decisions. No Docker, deployment files or backend database are required.

## Run locally

Use Node >=24 (verified on this PC with Node 26.3.0). From `backend/`:

```powershell
npm ci
```

Create your own ignored `.env` using `.env.example` as a template. Set `COCKTAIL_DB_API_KEY` there to your paid key. Do not paste it into chat, source files, frontend defines or terminal commands that could be logged. Without an override the documented public test key `1` is used; an empty/invalid override fails startup.

Then run:

```powershell
npm run dev
```

This user-run watcher binds `127.0.0.1:3000`. In another terminal, from `frontend/`:

```powershell
flutter run -d chrome --web-port=5173
```

The web port must match `CORS_ORIGINS`; both `http://localhost:5173` and `http://127.0.0.1:5173` are allowed by default. Different ports require explicit configuration. To change the gateway address, pass Flutter `--dart-define=ZEST_API_BASE_URL=http://127.0.0.1:3000/api/cocktails/` (trailing slash required). Do not set `COCKTAIL_DB_API_KEY` in Flutter: it no longer reads it.

Health: `http://127.0.0.1:3000/api/health`. This checks the local process, not premium credentials or upstream availability. The server is not reachable by another physical device as configured; mobile/LAN deployment is outside this increment.

## Finite verification

From `backend/`:

```powershell
npm run typecheck
npm test
npm run build
npm run demo
```

From `frontend/`:

```powershell
flutter analyze
flutter test
dart run tool/gateway_demo.dart
```

Both demos use synthetic upstream data. Neither starts a listening server nor uses a real provider key. The cross-language demo requires backend dependencies installed. Tests never read `.env`.

See [GATEWAY.md](../docs/GATEWAY.md) for endpoints, limits and security boundaries. Deployment and public-access hardening are future work, not implied by a successful local build.
