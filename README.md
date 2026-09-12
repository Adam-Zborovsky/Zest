# Zest

A personal, playful cocktail companion: a Flutter app (TheCocktailDB as recipe source) with an expressive, app-wide visual language. This repository is a monorepo.

## Repository layout

- `frontend/` — the Flutter application (run Flutter commands here).
- `backend/` — local Node/TypeScript/Fastify recipe gateway. Run npm commands here. It holds the provider key; accounts and authentication remain M7 decisions. See [local setup](backend/README.md).
- `docs/` — product brief, roadmap, review records, and the development-agent prompt.
- `AGENTS.md` — operating instructions for development agents working in this repository.

## This host does not run Zest

This repository is also present on a production server where Flutter and Dart are intentionally absent. Do not install or run SDK tooling there. Development happens on the development PC with a current stable Flutter SDK.

## First setup on the development PC

For live recipe discovery, first follow [backend setup](backend/README.md). Start Flutter web with `flutter run -d chrome --web-port=5173` so its origin matches the gateway allowlist. No Docker or deployment setup is required. The default recipe API address is `http://127.0.0.1:3000/api/cocktails/`.

All Flutter commands run from the repository's `frontend/` directory. Start from the repository root, then:

1. Preserve an untouched copy of this source checkout before generating anything. The authored files may be untracked in a fresh clone; `git diff` alone cannot show whether they changed until a tracked baseline exists.

   Use `git status --short` to understand the checkout state:

   ```text
   git status --short
   ```

2. If any platform wrapper directory (`android/`, `web/`) is missing, regenerate it from `frontend/`:

   ```text
   cd frontend
   flutter create --project-name=zest --platforms=android,web --no-pub .
   ```

   Do not add `--overwrite`. Flutter's `Template.render` skips an existing destination when overwrite is false, and `CreateCommand` passes the `--overwrite` flag (false by default) to that rendering path. Therefore the authored source files are preserved; keep the untouched copy as the independent recovery point. Source: [Template.render](https://github.com/flutter/flutter/blob/master/packages/flutter_tools/lib/src/template.dart) and [CreateCommand](https://github.com/flutter/flutter/blob/master/packages/flutter_tools/lib/src/commands/create.dart).

   `.metadata` and the application `pubspec.lock` are generated on the development PC. Review them and normally include them in a later user-approved commit.

3. Resolve dependencies and validate the source:

   ```text
   flutter pub get
   flutter analyze
   flutter test
   ```

4. List available targets, then run one by its listed device ID:

   ```text
   flutter devices
   flutter run -d DEVICE_ID
   ```

   Replace `DEVICE_ID` with an ID reported by `flutter devices` (for example, an attached Android serial, an iOS simulator UUID, or another listed target). `flutter run -d chrome` is also a valid web-specific example because `chrome` is its device ID. Select only targets supported by the development PC.

## Project files

- `frontend/lib/main.dart` — Botanical Play app shell and debug-only design gallery.
- `frontend/lib/features/discovery/` — discovery/detail UI, Riverpod state, recipe models and cached TheCocktailDB client.
- `frontend/tool/m2_demo.dart` — one-shot synthetic data/cache demo; optional `--live` smoke check.
- `frontend/test/` — design/accessibility regressions and synthetic data-layer tests.
- `docs/PRODUCT.md` — canonical agreed product requirements and explicit implementation boundary.
- `docs/ROADMAP.md` — milestone order and acceptance criteria.
- `docs/DATA.md` — M2 API, source preservation, ingredient aliases, cache policy and demo commands.
- `docs/DISCOVERY.md` — M3 routes, interface behavior, source attribution and rendered demos.
- `docs/AGENT_PROMPT.md` — kick-off prompt for the development-PC agent.
- `docs/review.md` — review records for the foundation and handoff.
- `docs/VERIFICATION.md` — host-side static verification and its limits.
- `AGENTS.md` — agent operating instructions and default stack.
- `.gitignore` — ignores tool outputs, local native settings, secrets, and local personal-media paths.

## Source boundary

Flutter calls the local recipe gateway; the provider key exists only in the backend process environment or ignored `backend/.env`. The gateway defaults to documented public test key `1`. No provider records, images, private API keys, or content-license grant are included in this repository. Tests and synthetic demos use invented fixtures; provider responses are cached in memory only. Personal photos remain a planned private archive feature. See [gateway contract](docs/GATEWAY.md) and `docs/PRODUCT.md` for boundaries and unresolved decisions.
