# Zest — agent operating instructions

Zest is a personal, playful cocktail companion: a Flutter app using TheCocktailDB as its recipe source. A personal project first; the repository is public and Zest's own app code is MIT licensed (`LICENSE`, `docs/SOURCES.md`). This file is the working agreement for any coding agent (or human) contributing to this repository.

Read, in order:

1. `docs/PRODUCT.md` — the agreed product scope, boundaries, and open decisions. It is the source of truth for what Zest is. Do not contradict it; propose changes instead.
2. This file — how to work.
3. `docs/ROADMAP.md` — milestone order and acceptance criteria. Work milestone by milestone.

## Working agreements

- **Definition of done (every change):** `flutter analyze` is clean and `flutter test` is green. Backend changes also require `npm run typecheck`, `npm test`, and `npm run build` from `backend/`. New behavior or logic gets a test; bug fixes get a regression test first.
- **Milestone loop:** start each milestone by proposing a short plan to Adam; implement in small, conventional commits; demo the result at the end. Do not run ahead into later milestones.
- **Design is a feature, not a garnish.** Every screen — including loading, empty, and error states — gets the same expressive treatment defined by the design system. Accessibility (reduced motion, contrast, text scaling, logical focus order) is part of done.
- **Dependencies:** start from the default stack below. Any addition needs a stated reason in the commit or PR. Keep the dependency list small.
- **Secrets and personal data:** no API keys in the repository, no personal photos in the repository, no provider data dumps. Tests use synthetic fixtures that imitate API shapes, not copied provider records. README screenshots must not show TheCocktailDB drink photos or personal memory photos.
- **TheCocktailDB terms:** Adam purchased premium access. The published terms, quoted and mapped to Zest's behavior, live in `docs/SOURCES.md`. The local gateway defaults to the documented public test key; a private key belongs only in backend runtime configuration. Respect rate limits and retain attribution. Do not commit provider records/images or infer permission for additional distribution.
- **Memory photos** are stored in the app's private on-device cache and, since M8 (Adam's decision, 2026-09-13), on Zest's own backend server disk readable only by their owner. They never go in the repo or in any third-party cloud without a new decision.
- **Author/reviewer discipline:** substantive changes get a second look — a fresh agent instance or an Adam-routed review — before being considered final.
- **Monorepo discipline:** run Flutter commands from `frontend/` and npm commands from `backend/`. Adam explicitly authorized a local Node/TypeScript/Fastify recipe gateway before M5, superseding the old empty-until-M7 rule. For M8 (2026-09-13), Adam authorized accounts, a PostgreSQL database run with Docker Compose on the development PC, and photo files on the server disk; see `docs/ACCOUNTS.md`. Deployment, HTTPS, Nginx, and backups remain out of scope. Adam runs `npm run dev` and `docker compose up`; agents use finite tests and builds (backend tests use in-process PGlite, not Docker), never servers, watchers, or long-running containers.

## Default stack (propose changes, don't silently deviate)

| Concern | Default | Notes |
|---|---|---|
| UI | Flutter stable, Material 3 | Seed-based theming already in `frontend/lib/main.dart` |
| State | `flutter_riverpod` | Providers per feature; keep widgets dumb |
| Navigation | `go_router` | Official routing; needed for the onboarding/login redirect flow |
| HTTP | `http` | Thin client around TheCocktailDB; `dio` only if interceptors earn it |
| Recipe gateway | Node >=24, TypeScript, Fastify + `@fastify/cors` | Local development; backend holds provider key. `tsx` runs development/test TypeScript. |
| Persistence | `shared_preferences` (flags), `drift` (from M6) | On-device cache; since M8 it syncs to Zest's own backend (`docs/ACCOUNTS.md`) |
| Accounts backend | PostgreSQL 18 (Docker Compose, local), `drizzle-orm`/`drizzle-kit`, `argon2`, `@fastify/rate-limit` | M8; opaque bearer sessions; photos on server disk; tests use PGlite |
| Session token | `flutter_secure_storage` | M8; account JSON stays in `shared_preferences` |
| Photos | `image_picker` + `path_provider` | Store under the app documents directory; DB keeps relative paths |
| Constellation | custom `CustomPainter` + simple force layout | Full aesthetic control; add graph packages only with justification |
| Models | hand-written `fromJson`/`toJson` | Add codegen only when the boilerplate hurts |

API key handling: backend `COCKTAIL_DB_API_KEY` environment variable, default public test key `1`. An ignored `backend/.env` is supported. Flutter accepts only `--dart-define=ZEST_API_BASE_URL=...`, not a provider key. Never put private keys in source, frontend builds, logs, or chat.

## Project layout (target)

```
frontend/            # the Flutter application — run commands from here
  lib/
    app/             # app shell, routing, theme wiring
    core/            # design tokens, network, error types
    features/
      discovery/     # search, browse, recipe detail
      bar/           # "what can I make" matching
      constellation/ # ingredient co-occurrence graph
      collection/    # saved recipes, variations, memory photo
      onboarding/    # intro scenes + login
  test/
    fixtures/        # synthetic API-shaped JSON
    features/        # mirrors lib structure
backend/             # local recipe gateway; accounts/auth remain gated on M7
docs/                # PRODUCT.md, ROADMAP.md, DESIGN.md (created in M1), review records
```

## Everyday commands

Run all of these from `frontend/`:

```
flutter devices                 # list valid device IDs
flutter run -d <device-id>      # run on a chosen target (chrome is a valid web id)
flutter analyze
flutter test
```

When something in `docs/PRODUCT.md` or the roadmap no longer matches reality, stop and raise it with Adam instead of improvising a silent scope change.
