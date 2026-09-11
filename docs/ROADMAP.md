# Zest roadmap

Order matters: each milestone builds on the previous one. Acceptance criteria are the gate; a milestone is done when its criteria are demonstrably met — `flutter analyze` clean, `flutter test` green, plus what is listed below. All Flutter work happens in `frontend/`.

## M0 — Baseline and platform wrappers — DONE (2026-09-10)

- Source foundation authored and independently reviewed; platform wrappers generated on the development PC; the app was built and run there successfully (Adam confirmed the run, 2026-09-10).
- Carry-over items verified closed at the start of M1 (2026-09-10): baseline commits exist, a GitHub origin is configured, `flutter analyze` is clean, and `flutter test` passes the starter widget test on the development PC. See `docs/VERIFICATION.md`.

## M1 — Design system foundation — DONE (2026-09-11)

- Design tokens: color palette, typography scale, spacing, radii, elevation, motion durations and easing — including a reduced-motion policy.
- Theme wired into the app shell; shared primitives: buttons, cards, chips, bottom sheet, empty/loading/error states.
- A temporary gallery screen demonstrating every primitive (removed or hidden before any release).
- `docs/DESIGN.md` documenting the visual language and naming the art direction.
- **Acceptance:** two or three art directions are presented to Adam with sample screens before committing to one; the chosen direction is implemented as tokens and theme; the gallery renders all primitives; the reduced-motion path is defined; widget tests cover theme/token basics.
- **Result:** Adam chose C — Botanical Play after the three sample galleries. Tokens, bundled fonts, Material 3 theme, shared primitives and a debug-only interactive gallery are implemented. Analysis is clean, all 23 tests pass, and a release web build succeeds. See `docs/DESIGN.md`, `docs/VERIFICATION.md`, and `docs/reviews/M1.md` for the demo and independent review.

## M2 — Data layer: TheCocktailDB

- HTTP client with the documented public test key as default and a `--dart-define` override; typed models (Recipe, Ingredient, measure parsing); error types; response caching.
- Ingredient name normalization (aliases, e.g. "Dark Rum" vs brand names) via a reviewed mapping table.
- Tests against synthetic fixtures — no network in tests, no provider data copied into the repository.
- **Acceptance:** client unit-tested with fixtures; models round-trip; rate-limit-friendly caching documented; no key material in the repo.

## M3 — Discovery and recipe detail

- Search by name; browse by ingredient and by first letter; "see all" flows where the API supports them.
- Recipe detail: source image with attribution, ingredients with readable measures, numbered instructions, glass/type metadata.
- **Acceptance:** navigation wired with `go_router`; loading/empty/error states are designed, not default spinners; flows covered by widget tests.

## M4 — "What can I make" (bar matching)

- Ingredient selection UI with no mandatory full pantry setup.
- Matching logic: ready to make / missing N essentials / optional garnish not counted; explicit "reviewed substitution" suggestions, clearly labeled as such.
- **Acceptance:** matching unit tests including edge cases (unselected does not mean available; optional garnish; duplicates after normalization); the results UI distinguishes the three cases.

## M5 — Ingredient Constellation (flagship)

- Co-occurrence graph over the loaded recipe collection: nodes are normalized ingredients (size = distinct-recipe count), edges are shared recipes (weight = shared count).
- Bounded initial view (top-N frequent ingredients); filter and focus interactions; selecting an ingredient highlights its neighborhood; selecting an edge shows shared recipes.
- Playful motion and physics where motion is enabled; a static or reduced-motion alternative plus a textual route to the same information.
- The constellation is the home screen's lead experience (per `docs/PRODUCT.md`); "core tasks never depend on the graph" means non-graph routes to the same information exist — not that the constellation is demoted off home.
- Coverage labeling: counts are collection prevalence, labeled as such, with the analyzed collection identified.
- **Acceptance:** sustains 60 fps (no jank warnings in `flutter run --profile`) on the development device with the default bounded view (top 40 ingredients by prevalence) fully laid out; if the device cannot hold 60 fps at that count, lower it and record the chosen value in `docs/DESIGN.md`. The reduced-motion alternative is fully functional; no invented flavor or compatibility claims; core tasks never depend on the graph.

## M6 — Collection, variations, memory photo

- Save recipes; create personal variations (edits kept clearly distinct from the source recipe); local persistence with `drift`.
- One optional memory photo per saved recipe or variation: add on save or later, replace, remove; stored in app-private storage; no-photo entries are intentionally designed.
- **Acceptance:** CRUD tested; photos never touch the repository or any cloud; variations clearly separate from source; export/backup remains an open decision, not silently implemented.

## M7 — Onboarding and login (gated: Adam decides the auth approach first)

- Swipeable onboarding: animated versions of actual interface components with a small illustrated character as support; Next/Back, visible progress, Skip goes to login; no forced animation waits; completion state persisted (returning signed-in users enter the app; signed-out users land on login).
- Login per Adam's chosen approach (candidates: Supabase, Firebase, local-first with account later). Onboarding must not request photo or camera permissions — only the photo feature does, on first use.
- **Acceptance:** flows tested; reduced-motion variants; the returning-user state machine covered by tests, with states enumerated: fresh user → onboarding; onboarding completed + signed in → app; Skip pressed, never signed in → login on next launch (Skip persists "onboarding seen", not "signed in"); signed out after having signed in → login.

## Post-M7 (not scheduled)

Publication and licensing review, distribution, and the home-bar/shopping/hosting ideas listed in `docs/PRODUCT.md`.

## Open decisions that gate work

- **Art direction** — resolved in M1: Adam selected C — Botanical Play.
- **Auth provider and guest/local-only mode** — Adam decides before M7 starts; this is the decision that determines whether `backend/` gets content.
- **Publication target** (repository visibility, distribution) — after M7.
