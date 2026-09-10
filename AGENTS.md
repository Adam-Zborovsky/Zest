# Zest — agent operating instructions

Zest is a personal, playful cocktail companion: a Flutter app using TheCocktailDB as its recipe source. A personal project first; open-source publication is under consideration as an open decision in `docs/PRODUCT.md`. This file is the working agreement for any coding agent (or human) contributing to this repository.

Read, in order:

1. `docs/PRODUCT.md` — the agreed product scope, boundaries, and open decisions. It is the source of truth for what Zest is. Do not contradict it; propose changes instead.
2. This file — how to work.
3. `docs/ROADMAP.md` — milestone order and acceptance criteria. Work milestone by milestone.

## Working agreements

- **Definition of done (every change):** `flutter analyze` is clean and `flutter test` is green. New behavior or logic gets a test; bug fixes get a regression test first.
- **Milestone loop:** start each milestone by proposing a short plan to Adam; implement in small, conventional commits; demo the result at the end. Do not run ahead into later milestones.
- **Design is a feature, not a garnish.** Every screen — including loading, empty, and error states — gets the same expressive treatment defined by the design system. Accessibility (reduced motion, contrast, text scaling, logical focus order) is part of done.
- **Dependencies:** start from the default stack below. Any addition needs a stated reason in the commit or PR. Keep the dependency list small.
- **Secrets and personal data:** no API keys in the repository, no personal photos in the repository, no provider data dumps. Tests use synthetic fixtures that imitate API shapes, not copied provider records.
- **TheCocktailDB terms:** the app uses the documented public test key by default (personal/educational use). Respect rate limits; cache responses client-side. Redistributing provider data or images outside the running app is not permitted. If publication beyond personal use is planned, licensing must be reviewed with Adam first.
- **Memory photos** are stored in app-private storage — never in the repo, never in any cloud without an explicit decision.
- **Author/reviewer discipline:** substantive changes get a second look — a fresh agent instance or an Adam-routed review — before being considered final.
- **Monorepo discipline:** the Flutter app lives in `frontend/`; run every Flutter command from there. `backend/` is intentionally empty until the M7 auth decision (see `backend/README.md`) — do not scaffold a server and do not proxy TheCocktailDB calls behind one.

## Default stack (propose changes, don't silently deviate)

| Concern | Default | Notes |
|---|---|---|
| UI | Flutter stable, Material 3 | Seed-based theming already in `frontend/lib/main.dart` |
| State | `flutter_riverpod` | Providers per feature; keep widgets dumb |
| Navigation | `go_router` | Official routing; needed for the onboarding/login redirect flow |
| HTTP | `http` | Thin client around TheCocktailDB; `dio` only if interceptors earn it |
| Persistence | `shared_preferences` (flags), `drift` (from M6) | Local-first; no cloud sync without a decision |
| Photos | `image_picker` + `path_provider` | Store under the app documents directory; DB keeps relative paths |
| Constellation | custom `CustomPainter` + simple force layout | Full aesthetic control; add graph packages only with justification |
| Models | hand-written `fromJson`/`toJson` | Add codegen only when the boilerplate hurts |

API key handling: default in code to the documented public test key; allow override with `--dart-define=COCKTAIL_DB_API_KEY=...`. A premium key, if ever obtained, never enters the repo — dart-define or an untracked local file only.

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
backend/             # intentionally empty until the M7 auth decision (see backend/README.md)
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
