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

## M2 — Data layer: TheCocktailDB — DONE (2026-09-11)

- HTTP client with the documented public test key as default and a `--dart-define` override; typed models (Recipe, Ingredient, measure parsing); error types; response caching.
- Ingredient name normalization (aliases, e.g. "Dark Rum" vs brand names) via a reviewed mapping table.
- Tests against synthetic fixtures — no network in tests, no provider data copied into the repository.
- **Acceptance:** client unit-tested with fixtures; models round-trip; rate-limit-friendly caching documented; no key material in the repo.
- **Result:** typed full recipes and filter summaries, source-preserving ingredient/measure models, reviewed lexical aliases, four discovery endpoints, safe error types and bounded TTL/LRU caching are implemented. Only the explicitly allowed public test key is in code. Analysis is clean, all 50 tests pass, and the one-shot live demo confirms two lookups use one HTTP request without saving provider content. Discovery UI remains M3. See `docs/DATA.md`, `docs/VERIFICATION.md`, and `docs/reviews/M2.md`.

## M3 — Discovery and recipe detail — DONE (2026-09-12)

- Search by name; browse by ingredient and by first letter; "see all" flows where the API supports them.
- Recipe detail: source image with attribution, ingredients with readable measures, numbered instructions, glass/type metadata.
- **Acceptance:** navigation wired with `go_router`; loading/empty/error states are designed, not default spinners; flows covered by widget tests.
- **Result:** discovery now launches normally, with name/ingredient searches, A–Z browse, bounded previews and all-returned-results navigation. Recipe detail preserves source measures/instructions and attribution, with explicit image and missing-data fallbacks. Riverpod owns the client and shared rate-limit cooldown; routing supports query-preserving Back and direct links. Analysis is clean, all 90 tests pass, and the release web build succeeds. See `docs/DISCOVERY.md`, `docs/VERIFICATION.md`, and `docs/reviews/M3.md`. M4 has not started.

## M4 — "What can I make" (bar matching) — DONE (2026-09-12)

- Ingredient selection UI with no mandatory full pantry setup.
- Matching logic: ready to make / missing N essentials / optional garnish not counted; explicit "reviewed substitution" suggestions, clearly labeled as such.
- **Acceptance:** matching unit tests including edge cases (unselected does not mean available; optional garnish; duplicates after normalization); the results UI distinguishes the three cases.
- **Result:** matching runs client-side within the chosen discovery results (multi-ingredient filtering is provider-premium), with a searchable ingredient picker over the provider's list endpoint, batch-of-ten lookups through the shared cache and cooldown, pause/resume, and a three-bucket results UI with reviewed garnish/substitution tables documented in `docs/DATA.md`. Analysis is clean, all 124 tests pass, and the release web build succeeds. An independent review blocked on a result-duplication defect and the uncommitted contract; both were fixed and re-verified. See `docs/BAR.md`, `docs/VERIFICATION.md`, and `docs/reviews/M4.md`. M5 has not started.

## M5 prerequisite — local recipe gateway — DONE (2026-09-12)

- Approved after Adam purchased premium access: Node/TypeScript/Fastify in `backend/`, local `npm run dev`, paid key in backend environment only.
- Preserve current discovery/bar operations through a configurable Flutter gateway address; strict routes, explicit localhost CORS, bounded memory caching, request deadlines and shared provider cooldown.
- Acceptance: synthetic backend tests, typecheck/build, Flutter analyze/tests, cross-language synthetic contract demo and independent review. No Docker, Compose, Nginx, deployment, accounts or backend database.
- Contract and local setup: [GATEWAY.md](GATEWAY.md). This prerequisite does not complete M5.
- Result: allowlisted local gateway and key-free Flutter transport implemented; 23 backend tests and 126 Flutter tests pass, analysis/typecheck/builds clean, synthetic cross-language demo passes. Independent review: [GATEWAY review](reviews/GATEWAY.md). Live paid-key behavior was verified 2026-09-12 after moving the upstream to the V2 API (purchased keys are V2 keys; V1 letter browse returns empty bodies for them) — all five allowlisted operations and the null no-data shape confirmed with the paid key. Browser/WASM runtime behavior remains unverified.

## M5 — Ingredient Constellation (flagship)

- Adam approved source-preserving on-device catalog storage with drift brought forward from M6, and resumable 26-letter sync with visible coverage/progress. The gateway supplies provider access; graph/matching remain client-side. Do not equate completed A–Z sync with proven full-catalog completeness.

- Co-occurrence graph over the loaded recipe collection: nodes are normalized ingredients (size = distinct-recipe count), edges are shared recipes (weight = shared count).
- Bounded initial view (top-N frequent ingredients); filter and focus interactions; selecting an ingredient highlights its neighborhood; selecting an edge shows shared recipes.
- Playful motion and physics where motion is enabled; a static or reduced-motion alternative plus a textual route to the same information.
- The constellation is the home screen's lead experience (per `docs/PRODUCT.md`); "core tasks never depend on the graph" means non-graph routes to the same information exist — not that the constellation is demoted off home.
- Coverage labeling: counts are collection prevalence, labeled as such, with the analyzed collection identified.
- **Acceptance:** sustains 60 fps (no jank warnings in `flutter run --profile`) on the development device with the default bounded view (top 40 ingredients by prevalence) fully laid out; if the device cannot hold 60 fps at that count, lower it and record the chosen value in `docs/DESIGN.md`. The reduced-motion alternative is fully functional; no invented flavor or compatibility claims; core tasks never depend on the graph.
- **Result (implementation + review complete; on-device profile check pending):** drift catalog with source-preserving, transactional per-letter storage and a resumable A–Z sync through the shared gateway cooldown; deterministic co-occurrence graph (top-40 bounded view, disclosed in copy) and seeded force layout; graph-first home with a fully semantic list alternative, reduced motion guaranteed static under both flags, and honest coverage labeling throughout. Analysis is clean, all 186 tests pass, and the release web build succeeds. An independent review initially blocked on overclaiming copy and a no-op updates button; all findings were fixed and re-verified. Remaining for closeout: Adam's `flutter run --profile` run confirming 60 fps with the top-40 view. See `docs/CONSTELLATION.md`, `docs/VERIFICATION.md`, and `docs/reviews/M5.md`. M6 has not started.

## M6 — Collection, variations, memory photo

- Save recipes; create personal variations (edits kept clearly distinct from the source recipe); local persistence with `drift`.
- One optional memory photo per saved recipe or variation: add on save or later, replace, remove; stored in app-private storage; no-photo entries are intentionally designed.
- **Acceptance:** CRUD tested; photos never touch the repository or any cloud; variations clearly separate from source; export/backup remains an open decision, not silently implemented.
- **Status (2026-09-13): implementation and independent review complete; on-device photo checks pending.** The independent review approved with fixes: storage failures are now stated instead of dropped, the back tooltip and collection-button stacking were corrected, and a concurrent-save test was added (see `docs/reviews/M6.md`). After the fixes, analysis is clean and all 301 tests pass. Remaining for closeout: Adam's on-device check of the Android photo picker, camera, and web file picker. Adam chose photos in the local database (container object storage deferred until Docker and auth are decided), full-copy variations, and a separate collection database. Built by parallel Sonnet subagent tracks against a committed contract: a drift collection database with a shared contract suite run against the drift and in-memory repositories, an `image_picker` photo picker for web and Android, and the collection screens (save, variations, entry detail with photo add, replace, and remove, and the variation editor). Analysis is clean, all 294 tests pass, and the release web build succeeds. Photos live only in the on-device collection database; no export or backup exists. Open items: Android lost-photo recovery is deferred, and the Android photo picker, camera, and web file picker still need a device check. See `docs/COLLECTION.md`. The same session also fixed the gateway 502 for no-match ingredient searches (`docs/GATEWAY.md`).

## M7 — Onboarding and login (gated: Adam decides the auth approach first)

- Swipeable onboarding: animated versions of actual interface components with a small illustrated character as support; Next/Back, visible progress, Skip goes to login; no forced animation waits; completion state persisted (returning signed-in users enter the app; signed-out users land on login).
- Login per Adam's chosen approach (candidates: Supabase, Firebase, local-first with account later). Onboarding must not request photo or camera permissions — only the photo feature does, on first use.
- **Acceptance:** flows tested; reduced-motion variants; the returning-user state machine covered by tests, with states enumerated: fresh user → onboarding; onboarding completed + signed in → app; Skip pressed, never signed in → login on next launch (Skip persists "onboarding seen", not "signed in"); signed out after having signed in → login.

## Post-M7 (not scheduled)

Publication and licensing review, distribution, and the home-bar/shopping/hosting ideas listed in `docs/PRODUCT.md`.

## Open decisions that gate work

- **Art direction** — resolved in M1: Adam selected C — Botanical Play.
- **Auth provider and guest/local-only mode** — Adam decides before M7 starts. The recipe gateway is separately authorized before M5; it does not settle auth or cloud storage.
- **Publication target** (repository visibility, distribution) — after M7.
