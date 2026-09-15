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

## M6 — Collection, variations, memory photo — DONE (2026-09-13)

- Save recipes; create personal variations (edits kept clearly distinct from the source recipe); local persistence with `drift`.
- One optional memory photo per saved recipe or variation: add on save or later, replace, remove; stored in app-private storage; no-photo entries are intentionally designed.
- **Acceptance:** CRUD tested; photos never touch the repository or any cloud; variations clearly separate from source; export/backup remains an open decision, not silently implemented.
- **Status (2026-09-13): done.** Adam confirmed on 2026-09-13 that the collection, variations, and memory photos work in his own use. The implementation and independent review are complete. The independent review approved with fixes: storage failures are now stated instead of dropped, the back tooltip and collection-button stacking were corrected, and a concurrent-save test was added (see `docs/reviews/M6.md`). After the fixes, analysis is clean and all 301 tests pass. Android lost-photo recovery remains a documented, deferred limitation.
- **Follow-up (2026-09-13): drink calendar.** At Adam's request the collection became a dated calendar: every save is a new entry on today's date that can be moved, days show the drink's photo or floating circles for several drinks, and the collection database migrated to schema 2 without losing existing entries or photos. See `docs/COLLECTION.md`. Adam chose photos in the local database (container object storage deferred until Docker and auth are decided), full-copy variations, and a separate collection database. Built by parallel Sonnet subagent tracks against a committed contract: a drift collection database with a shared contract suite run against the drift and in-memory repositories, an `image_picker` photo picker for web and Android, and the collection screens (save, variations, entry detail with photo add, replace, and remove, and the variation editor). Analysis is clean, all 294 tests pass, and the release web build succeeds. Photos live only in the on-device collection database; no export or backup exists. Open items: Android lost-photo recovery is deferred, and the Android photo picker, camera, and web file picker still need a device check. See `docs/COLLECTION.md`. The same session also fixed the gateway 502 for no-match ingredient searches (`docs/GATEWAY.md`).

## M7 — Onboarding and login — implementation and review complete; on-device check pending

- Swipeable onboarding: animated versions of actual interface components with a small illustrated character as support; Next/Back, visible progress, Skip goes to login; no forced animation waits; completion state persisted (returning signed-in users enter the app; signed-out users land on login).
- Login per Adam's chosen approach. Onboarding must not request photo or camera permissions — only the photo feature does, on first use.
- **Decision (2026-09-13): Local-first auth.** The login page offers "Continue on this device", which creates or resumes a profile stored only on this device. There is no account, credential, server, or sync. `AuthRepository` is the seam where Supabase or Firebase can replace the local implementation later without changing screens or routing.
- **Status (2026-09-13):** flows tested; reduced-motion variants; the returning-user state machine covered by tests over all four states; independent review approved with fixes (all acceptance criteria met). Analysis clean, 390 tests pass. No photo/camera permission requested during onboarding. One known limitation: no fallback if `SharedPreferencesWithCache.create` throws at startup; revisit alongside Android lost-photo recovery. Adam's on-device check of the screens and lime character drawing is pending. M8 replaced the local-profile login with email/password accounts. See [docs/ONBOARDING.md](ONBOARDING.md) and [docs/reviews/M7.md](reviews/M7.md).

## M8 — Accounts and synced collection — DONE (2026-09-14)

- **Decision (2026-09-13):** Zest's own Fastify backend (not Supabase/Firebase). Account required: email and password. Offline-first sync with last edit wins per entry. Existing device data uploads on first sign-in. PostgreSQL 18 with Drizzle. Photos on server disk, owner-readable only. Local-first: Docker Compose on Adam's PC, LAN access. Email verification and password reset deferred. Opaque bearer tokens; server stores SHA-256 hash. See [docs/ACCOUNTS.md](ACCOUNTS.md).
- **Status (2026-09-14):** Backend auth/entry/sync/photo routes, Flutter HTTP account repository with secure token storage, Drift schema 4 with sync flags, tombstones, and millisecond timestamps, sync engine with last-edit-wins and retry logic, sign in/create account UI, profile sheet with sync status and email. Two independent reviews and integrator review complete; all findings resolved. Analysis clean, 469 Flutter tests pass, 60 backend tests pass. Remaining: Adam's local Docker Postgres run with sign-up, photo, and sync check. See [docs/reviews/M8.md](reviews/M8.md).

## M9 — Distribution rights, public repository, and README

- **Decisions (Adam, 2026-09-14):**
  - The repository goes public on GitHub, and Zest's own code is MIT licensed.
  - Zest does not ask TheCocktailDB for written permission. Instead, the published terms are documented and Zest stays within them.
  - The README uses real app screenshots, limited to screens without TheCocktailDB drink photos or personal memory photos. The rule against provider images in the repository stays.
  - The two early commits that carry the owner's personal email stay as they are, with no history rewrite.
- **Scope:**
  - `docs/SOURCES.md`: quoted terms, each Zest behavior mapped to the clause that governs it, accepted risks, and a pre-publication checklist.
  - `LICENSE` and a third-party content notice covering TheCocktailDB content, the OFL fonts, and dependencies.
  - An in-app attribution audit, with fixes, covering every surface that shows provider data or images.
  - A rewritten `README.md` with Adam's screenshots.
  - Publication updates to `docs/PRODUCT.md` and `AGENTS.md`.
- **Acceptance:**
  - The full git history has been checked for secrets and personal media.
  - Every provider image or data surface credits TheCocktailDB and links back, and this is covered by tests.
  - The README describes current reality: M8 accounts and sync, Docker setup, phone access over Wi-Fi, tests, and credits.
  - Adam switches repository visibility himself after reviewing the checklist.
- **Status (2026-09-14):** Acceptance is complete in the working tree. The repository is public with `Development` as its default branch; the history and committed media were audited; licensing, notices, source-rights analysis, and publication boundaries are documented. The README now describes the M8 system and uses two provider-free screenshots. The final in-app audit added conditional calendar-image attribution and source attribution to both variation-editor paths; the profile sheet received its pending responsive polish. Analysis is clean and all 472 Flutter tests pass. Repository description and topics remain optional GitHub metadata. See [docs/reviews/M9.md](reviews/M9.md).

## M10 — Home-bar inventory and shopping list — DONE (2026-09-14)

- **Decision (Adam, 2026-09-14):** persistent binary inventory of normalized catalog ingredients; local-catalog matching into ready, reviewed-substitution, and missing-essential groups; a manual and recipe-fed shopping list; one-action moves between shopping and stocked; offline-first account sync. Quantities, brands, prices, expiry, barcode scanning, party planning, shared bars, automatic ordering, and “buy next” ranking are deferred. See [M10.md](M10.md).
- **Implementation:** Drift schema 5 stores stocked/shopping rows and an isolated sync cursor; the backend stores owner-scoped rows with a separate monotonic `bar_revision`; the account sync coordinator runs collection and home-bar passes together. `/bar` is the durable catalog-backed shelf, `/bar/shopping` is route-backed, and discovery-scoped matching reads the same persistent shelf. Recipe and match actions add missing essentials without optional garnishes or implicit substitutions.
- **Verification:** Flutter analysis is clean and all 493 tests pass. Backend typecheck, all 66 tests, and build pass. Tests cover migration, local writes, restoration, account isolation, paging, timestamp ties, an edit during an in-flight PUT with its automatic trailing pass, offline/session-expiry behavior, scoped and catalog matching, shopping actions, route-backed Back behavior, keyboard flow, 320-pixel/2× text, and reviewed goldens. Independent review found and blocked on the in-flight-write race; the atomic compare-and-apply and trailing-pass fixes were re-reviewed with no blocking or major findings. See [reviews/M10.md](reviews/M10.md).

## M11 — Shared catalog and search suggestions — implemented; independent review fixes applied

- **Decision (Adam, 2026-09-14):** the backend owns one shared, daily-refreshed catalog served as a versioned snapshot; clients store it on-device and search locally; suggestions in Discover, constellation, home-bar picker, and variation-editor ingredients; Discover results become local; catalog updates apply on launch with an in-app notice. Per-keystroke server search rejected. Server-side persistence risk accepted in [SOURCES.md](SOURCES.md). See [M11.md](M11.md).
- **Implementation:** `catalogSearchIndexProvider`/`CatalogSearchIndex` rank every recipe name and ingredient identity from the on-device catalog, alongside an id→Recipe map so a query never re-decodes the whole catalog; both rebuild whenever the update controller applies a new snapshot. `ZestSuggestionField` wires that index into Discover (name/ingredient suggestions, local name/ingredient/letter results including `/discover/results`, and the catalog download state in place of a false empty result), the constellation search field (suggestions restricted to graph nodes), the home-bar picker (ranked inline list, substring fallback for ingredients outside the index), and the variation editor's ingredient rows (suggestion plus free text, with a floating label). Recipe detail and M4 bar-matching detail reads are local-first, falling back to the gateway's `lookup.php` only when an id has left the catalog. The client-facing `search.php`, `filter.php` and `list.php` gateway routes and their `CocktailDbClient`/`CocktailRequestGateway` methods are removed; `lookup.php` remains, and the refresher still calls the gateway's `search.php` support internally.
- **Independent review (2026-09-14, [reviews/M11.md](reviews/M11.md)):** 20 findings. All fixed: backend CORS/Vary/gzip-q-value/304-without-recipes handling (1, 16, 17, 18); dead `filter.php`/`list.php` gateway support and a broken `npm run demo` (13); the catalog-update controller's resume gate now keys off the last *attempted* check and is skipped while the catalog is empty (2); `checkOnLaunch` moved to the app shell so a cold deep link to any route triggers it, with the controller invalidating every catalog-derived provider directly after an apply (3, 20); a floating `labelText` on `ZestSuggestionField` (4); the staged snapshot is cleared on every immediate apply and discarded if the applied version moved on since staging (5); repository failures in the controller land a retryable `failed(unknown)` instead of an unhandled error (6); the staged/applied notice is hosted at the app shell with distinct staged/applied copy (7); `ZestSuggestionField` announces highlight changes and hides the suggestion-count live region without layout impact (8, 9); the recipe-name search index's typo tier is a real fallback only, and its equal-length-prefix rule needs 5+ character words (10); free-text ingredient identities resolve by exact folded match (11); `/discover/results` shares Discover's empty-catalog gate (12); `CatalogStatusCard` moved to `lib/features/catalog/presentation/` (19); this document.
- **Verification:** Flutter analysis is clean and all 587 tests pass (up from 571 before the review-fix pass), including the resume-gate/empty-catalog controller tests (run 3× green), the app-shell launch-check and staged/applied notice widget tests, the suggestion-field announcement and live-region tests, the search-index typo-fallback and ingredient-fold tests, and reviewed goldens. Backend typecheck, all 99 tests (up from 95), and build pass, including a dedicated check that the removed routes 404 while `lookup.php` keeps working; `npm run demo` exits 0 with no network or server. See [VERIFICATION.md](VERIFICATION.md) for the full command output and golden list.

## Later (not scheduled)

- Deployment: HTTPS, backups, email verification, password reset, account deletion, and a review of whether sign-up reveals which emails already have accounts.
- The hosting ideas listed in `docs/PRODUCT.md`.

## Open decisions that gate work

- **Art direction** — resolved in M1: Adam selected C — Botanical Play.
- **Auth provider and guest/local-only mode** — resolved in M8 (2026-09-13): Zest's own backend with email/password accounts, offline-first sync, local Docker Compose. The recipe gateway is separately authorized before M5; it does not settle auth or cloud storage.
- **Media storage and sync** — resolved in M8 (2026-09-13): photos on Zest's server disk, owner-readable only, synced with collection entries.
- **Repository publication** — resolved for M9 (2026-09-14): public on GitHub, MIT for app code, content governed per `docs/SOURCES.md`.
- **Deployment and app-store distribution** (HTTPS, backups, email verification, password reset, account deletion, enumeration review) — open.
- **Home-bar inventory and shopping list scope and sync** — resolved in M10 (2026-09-14); see [M10.md](M10.md).
