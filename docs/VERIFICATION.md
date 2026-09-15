# Verification record

## M11 — Independent review fixes — 2026-09-15

Commands ran from their owning directories on the development PC, addressing all 20 findings in [reviews/M11.md](reviews/M11.md):

- Frontend: `flutter analyze` — no issues; `flutter test` — all **583 tests** passed; `test/features/catalog/application/catalog_update_controller_test.dart` run 3× — all **16 tests** passed each time.
- Backend: `npm run typecheck` and `npm run build` — clean; `npm test` — all **99 tests** passed; `npm run demo` — exits 0, no network/server/Docker.
- No Docker container, server, watcher, provider network call, key, or personal data was used.

Tracks covered:

- **Backend (findings 1, 16, 17, 18):** CORS `allowedHeaders` includes `If-None-Match`; the conditional-GET route appends to an existing `Vary` instead of overwriting it; `Accept-Encoding` q-values are parsed (`gzip;q=0` is not accepted); `GET /api/catalog` answers a 304 from `catalog_state` alone, without reading the recipes table.
- **Backend retry fix (finding 13):** the dead `filter.php`/`list.php` gateway `Endpoint` variants, their `validateEnvelope` branches, and the matching fake branches in `contract_fixture.ts` and `bar_flow_test.dart` are removed; `npm run demo` now exercises `lookup.php` in-process with a synthetic fetcher instead of the removed `search.php`-based flow that made it exit 1.
- **Catalog-update controller (findings 2, 3, 5, 6, 20):** the 6h resume gate keys off the last *attempted* check (success or failure) and is skipped entirely while the on-device catalog is empty, so an offline-first-launch-then-reconnect applies immediately instead of staging; `checkOnLaunch` is triggered once from `app/zest_app.dart` after the first frame rather than from Home, and the controller invalidates every catalog-derived provider (coverage, the shared recipe decode that both the search index and the id→Recipe map build from, the constellation graph, and the home-bar catalog providers) directly after any apply; every repository call in the controller is wrapped so a thrown error lands a retryable `failed(unknown)` state instead of escaping a fire-and-forget lifecycle callback; a staged snapshot is cleared on every immediate apply and discarded if the applied version moved on since staging; `lookupRecipeLocalFirst` uses `ref.read`. A latent `UnmountedRefException` this surfaced across unrelated widget-test suites — a fire-and-forget lifecycle callback still writing `Notifier.state` after the provider (and its test container) was torn down — is fixed by guarding every state write with `ref.mounted`, not just the staleness token.
- **Notice hosting (finding 7):** the staged/applied catalog-update notice moved from a screen-local listener to the app shell via `ref.listenManual`, reachable via `navigatorKey.currentState?.overlay` (not `Overlay.of(context)` from the Navigator's own ancestor context, which threw "No Overlay widget found"); staged copy reads "Catalog update available · …" with an **Update** action, distinct from the applied "Catalog updated · …".
- **Suggestion field (findings 4, 8, 9):** `ZestSuggestionField` gained an optional `labelText` rendered as a floating label like other Zest inputs, wired into the variation editor's ingredient rows; the options panel now announces `semanticLabelFor(option)` via the current `SemanticsService.sendAnnouncement` API on a user-driven (keyboard-touched) highlight change; the "N suggestions" live region is a visually-hidden, zero-layout-impact `Semantics` node, cleared immediately on Escape or selection and never triggered by a selection's own programmatic controller rewrite.
- **Search index (findings 10, 11):** `recipeIdsMatchingName` includes typo-tier matches only when tiers 1–4 return nothing at all; the equal-length-prefix typo rule needs query words of 5+ characters (the full-word one-edit rule is unaffected, staying at 4+); an ingredient identity with no direct normalized match now resolves by exact folded match against every entry's label, identity and reviewed aliases.
- **Client data docs (finding 14, this entry):** [DATA.md](DATA.md) marks the M2–M10 `searchByName`/`browseByFirstLetter`/`filterByIngredient`/`listIngredientNames` table historical and documents the current single-method (`lookupRecipe`) surface; [CONSTELLATION.md](CONSTELLATION.md) corrects its invalidation description (no more `catalogFreshnessProvider`/`homeBarCatalogFreshnessProvider` — the controller invalidates directly) and the resume-gate/notice-hosting wording, and fixes a "fpr" typo.
- **Wiring/review fixes (finding 19):** `CatalogStatusCard` moved to `lib/features/catalog/presentation/catalog_status_card.dart`; its two call sites (home, Discover/results) updated.

Goldens changed or added between `165410c` and this record's `HEAD` (`git diff --name-only 165410c..HEAD -- '*.png'`), each regenerated with `--update-goldens` and inspected with the Read tool before acceptance:

- `frontend/test/core/widgets/goldens/zest-suggestion-field-open.png` (added — unchanged visually; the new live region is invisible)
- `frontend/test/features/constellation/presentation/goldens/home-night-garden.png` and `home-night-garden-desktop.png` (the "downloaded catalog" copy wording)
- `frontend/test/features/discovery/presentation/goldens/discovery-results.png`
- `frontend/test/features/home_bar/presentation/goldens/home-bar-shelf.png` and `home-bar-shopping.png` (`CatalogStatusCard` move and copy wording)
- `frontend/test/features/onboarding/presentation/goldens/profile-sheet-offline.png` and `profile-sheet-synced.png`

`frontend/test/features/collection/presentation/goldens/collection-variation-editor.png` (the floating "Ingredient" label, finding #4) was also inspected this pass, but nets to no byte diff against `165410c` — an earlier, since-reverted attempt at the same fix had already produced an identical render at that commit.

Limits: no physical-device, TalkBack/VoiceOver, live browser-history, real PostgreSQL/Docker, provider-network, or deployment run was performed.

## M11 — Shared catalog and search suggestions — 2026-09-14

Commands ran from their owning directories on the development PC:

- Frontend: `flutter analyze` — no issues; `flutter test` — all **571 tests** passed.
- Backend: `npm run typecheck` and `npm run build` — clean; `npm test` — all **95 tests** passed.
- No Docker container, server, watcher, provider network call, key, or personal data was used.

Coverage added/changed for the search-surfaces and gateway-cleanup track: `catalogSearchIndexProvider` building from the on-device catalog and rebuilding once the update controller applies a new snapshot; Discover's per-mode suggestions, local name/ingredient/letter results, a keyboard-only type → Down → Enter flow that opens a recipe, an ingredient suggestion running results, Enter with no highlight still submitting free text, and the M11 acceptance strings ("old fash", "creme", "lime jiuce") in the real screen; recipe detail and M4 bar-matching detail reads local-first with a `lookup.php` fallback and its shared cooldown, exercised via a scope whose ids were removed from the local catalog to force the fallback path; an empty local catalog showing the shared download/failed-with-Retry state instead of a false empty result; a constellation suggestion selecting the same node a tap would and keeping the live filter text; the home-bar picker's catalog options ranked by the search index for a query; a variation-editor ingredient row suggesting a catalog label while free text stays valid; and backend coverage that the removed `search.php`/`filter.php`/`list.php` routes 404 while `lookup.php` keeps working, rewriting the gateway behavior tests (caching, cooldown, CORS, timeouts) to exercise `lookup.php` instead of the removed routes. Updated goldens (`discovery-results.png`, `collection-variation-editor.png`) were visually reviewed before acceptance.

Limits: no physical-device, TalkBack/VoiceOver, live browser-history, real PostgreSQL/Docker, provider-network, or deployment run was performed. Independent review of this track is still pending (`docs/ROADMAP.md`).

## M10 — Home-bar inventory and shopping list — 2026-09-14

Commands ran from their owning directories on the development PC:

- Frontend: `flutter analyze` — no issues; `flutter test` — all **493 tests** passed.
- Backend: `npm run typecheck` and `npm run build` — clean; `npm test` — all **66 tests** passed.
- Drift generation completed for schema 5. The committed backend migration was applied by every PGlite backend test; no Docker container, server, watcher, provider call, key, or personal data was used.

M10 coverage includes normalized binary inventory, mutually exclusive stocked/shopping locations, idempotent moves, restorable tombstones, millisecond timestamps, schema-4-to-5 migration, owner changes, independent cursors, deterministic dirty pushes, revision paging, equal-timestamp conflict retry, offline and expired-session states, authentication and cross-user isolation, strict request validation, and a local move made while an older PUT is in flight. That race now uses an atomic compare-and-apply and automatically schedules one trailing pass when its debounce expires during an active sync.

Presentation coverage includes direct catalog-backed `/bar`, discovery-scoped matching against the same durable shelf, `/bar/shopping` and Back, manual catalog search, move/remove actions, recipe and match-result shopping actions that exclude optional garnishes, loading protection before recipe shopping writes, rate-limit resume, keyboard operation, 320-pixel layouts at 2× text, and three reviewed synthetic goldens. Catalog counts state the locally loaded recipe/letter coverage and do not claim provider completeness.

The fresh Terra review initially blocked on the in-flight PUT overwrite, then identified the missing automatic trailing pass after the atomic fix. Both defects received regressions and were re-reviewed. Final verdict: no blocking or major findings. See [M10 review](reviews/M10.md).

Limits: no physical-device, TalkBack/VoiceOver, live browser-history, real PostgreSQL/Docker, provider-network, or deployment run was performed. The schema migration test starts from a minimal synthetic schema-4 fixture rather than a full copied production database. Deployment, HTTPS, backups, password recovery, email verification, and account deletion remain later work.

## Web catalog connection fixed — 2026-09-12

Adam's browser run surfaced `ArgumentError: When compiling to the web, the 'web' parameter needs to be set` from `driftDatabase` — the catalog connection passed only `DriftNativeOptions`, so the web branch of the documented cross-platform opener threw at runtime. Neither `flutter analyze` nor `flutter build web --release` can catch this: the missing parameter is a runtime error on the browser platform only, the exact untested path the M5 review flagged.

Fix: `openCatalogConnection` now passes `DriftWebOptions` pointing at the committed `web/sqlite3.wasm` and `web/drift_worker.js` (relative URIs per the installed drift_flutter 0.3.1 source). Browser-platform tests cannot run in this toolchain (`flutter test -p chrome` is gone; `-d chrome` finds no browser tests), so the runtime check is the browser session itself: run with `flutter run -d chrome --web-port 5173` so the app origin matches the gateway's allowlisted CORS origins, then resume the sync. VM verification after the fix: `flutter analyze` — no issues; `flutter test` — **186 passed**; `flutter build web --release` — succeeds.

## Gateway upstream moved to the V2 API — 2026-09-12

Adam's catalog sync surfaced the resumable error state ("recipe source is unavailable"). Live diagnosis (direct provider probes with the paid key, value never read into any record): V1 letter browse returns empty 0-byte `text/html` 200 bodies for the purchased key — which the gateway correctly rejects as a malformed envelope (502) and the app correctly pauses on. The purchase email confirms the key is a **V2 API key**; all five allowlisted operations, the full-record letter browse (109 records for `f=a`), and the `{"drinks":null}` no-data shape were verified live on the V2 base with the paid key, and the public test key also works on V2 with smaller result sets.

Fix: the gateway's fixed upstream moves from `v1` to `v2` (one URL constant); local routes, envelopes, parameters, Flutter client and letter-based sync are unchanged. Development PC, commands run in the owning directories:

- Backend: `npm run typecheck` and `npm run build` — clean; `npm test` — **23 passed** (the synthetic-upstream URL assertion now pins the V2 base).
- `dart run tool/gateway_demo.dart` — Flutter client through real Fastify routes with the synthetic upstream: all five operations pass, source measures retained, no socket or key use.
- Flutter: `flutter analyze` — no issues; `flutter test` — **186 passed**.

An independent reviewer passed the change after checking scope, key handling, the allowlist pin, and doc accuracy, catching two stale V1 references in DATA.md that were folded in. The on-device restart-and-resume run is Adam's step. Browser/WASM runtime behavior remains unverified.

## M5 — Ingredient Constellation — 2026-09-12

Development PC: Flutter 3.44.4/Dart 3.12.2; all Flutter commands ran from `frontend/`. Windows host tests require a 64-bit `sqlite3.dll` on PATH (drift's documented requirement for host-run tests; `sqlite3_flutter_libs` covers built apps).

- `flutter analyze` — no issues found.
- `dart run build_runner build` — drift code generation succeeded; generated files are committed.
- `flutter test` — all **186 tests** passed (126 gateway-era baseline + 60 M5: 20 catalog, 32 constellation, 8 review hardening). All prior milestone regressions retained; visual baselines unchanged.
- `flutter build web --release` — succeeds with the documented tree-shaken-icons notice only; the drift WASM assets ship in `build/web/`.

M5 coverage includes: source round-trip fidelity (Recipe → store → Recipe), transactional per-letter upsert with re-sync replacement and no duplicates, alias normalization applied to usages, coverage counts; sync completion of a–z, live progress, pause-on-cooldown with resume, pause-on-error with resume, empty letters as valid completions, no automatic retries, preamble store failures landing in resumable paused state, and restart resumability (a genuinely new repository over the same database file re-requests only pending letters); graph building (normalization merging, per-recipe identity dedupe, top-40 bounding with deterministic tie-breaks, wider-than-bound count disclosure, neighborhood and shared-recipe queries, empty/single-recipe cases); layout determinism (identical positions for identical graphs); home flows (constellation lead, empty state before sync, sync card states, edge-sheet navigation to detail, textual list parity, deep links to `/discover` and `/bar` unchanged); reduced motion under **both** flags with zero transient callbacks; 320-pixel readability at 1× and 2× text under reduced motion; and graph-rebuild coalescing during active sync.

### Demo

Run `flutter test test/features/constellation test/features/catalog` from `frontend/` for the feature suites; [CONSTELLATION.md](CONSTELLATION.md) describes the storage and graph contracts. Tests use invented records only.

An independent reviewer initially returned **BLOCK**: the home copy overclaimed graph coverage without disclosing the top-40 bound, and a "Check for updates" button was a permanent no-op after completion. Both were fixed along with the remaining findings (paint-data disposal, per-frame Paint allocations, sub-48px list rows, unhandled preamble errors, per-letter catalog re-decode, ticking fallback, stale comments, missing flag/readability tests) in one commit; the main agent then re-ran the clean analysis, all 186 tests, and the release web build. See [M5 review](reviews/M5.md).

Limits: the on-device **60 fps profile run has not been performed** — the roadmap acceptance check (`flutter run --profile`, default top-40 view fully laid out, no jank warnings) remains Adam's step, with the full-catalog decode during sync already coalesced as the flagged code-level risk. No live gateway/paid-key traffic, no browser WASM runtime session, no physical screen-reader session, and no native device run were performed. `docs/DISCOVERY.md` carries an unrelated uncommitted formatting change from Adam that M5 did not touch.


## Local recipe gateway — M5 prerequisite — 2026-09-12

Development PC: Node 26.3.0, npm 11.18.0, Flutter 3.44.4/Dart 3.12.2. Commands ran in the owning `backend/` or `frontend/` directory.

- Backend: `npm test` — **23 passed**; `npm run typecheck` and `npm run build` — clean. Initial install audit reported zero vulnerabilities. npm reported an unapproved esbuild postinstall hook; no approval/bypass was applied, and typecheck/build/tsx demos all worked with the installed platform package.
- `npm run demo` — real Fastify injection, synthetic upstream, two identical searches use one upstream call; health passes.
- Flutter: `flutter analyze` — no issues; `flutter test --reporter expanded` — **126 passed**, retaining all M4 regressions and unchanged visual baselines.
- `flutter build web --no-pub` — succeeds; Wasm dry run succeeds. Existing missing Cupertino icon-font warning remains, with ordinary MaterialIcons tree shaking. No suppression.
- `dart run tool/gateway_demo.dart` — Flutter client through real Fastify routes and invented upstream; all five operations pass, original measure retained, repeated lookup client-cached. Uses one-shot Node processes, not a listening server.
- `dart run tool/m2_demo.dart` — original synthetic model/cache demo still passes.

A separate Luna reviewer independently passed all 23 backend tests/typecheck/build after checking the origin/preflight regression fix. See [review](reviews/GATEWAY.md). No Docker/Compose/Nginx files, real provider calls, private key access, dev servers, physical-device runs or live browser interaction. Manual local setup is documented in [backend README](../backend/README.md). This closes the gateway prerequisite, not M5's catalog/graph work.

## M4 — "What can I make" (bar matching) — 2026-09-12

Executed on the development PC with Flutter 3.44.4 stable and Dart 3.12.2; all Flutter commands ran from `frontend/`:

- `flutter analyze` — no issues found.
- `flutter test --reporter compact` — all **124 tests** passed. This retains the 90 M3-era tests and adds 34 M4 tests (16 classifier/domain, 8 run-engine providers, 8 widget-flow, 2 client) plus the extended endpoint assertion; one M3 golden was regenerated after review.
- `flutter build web --release` — release web build succeeded with the documented tree-shaken-icons notice only.

M4 coverage includes: empty/partial selection and distinct-name strictness ("unselected is not available"), aliased selections, duplicate slots after normalization, every reviewed garnish form plus suffix scoping (`orange peel syrup` stays essential), substitution pairs in both directions and their deliberate limits, mixed missing-plus-substitution classification, zero-ingredient recipes; the `list.php` names contract (sorted, deduplicated, cached, malformed-rejected, URL shape); batch-of-ten runs with checked/total progress, pause on rate limit with partial-result retention, resume after the shared cooldown, lookup misses counted as unavailable, selection/scope resets, fresh re-runs replacing previous results, and abandonment of an in-flight run when starting again; UI coverage of the empty-scope state, picker search and toggling, the three result buckets with substitution and garnish copy, cooldown pause/resume, detail round trips, a fully keyboard-driven selection-and-match run with Escape sheet dismissal, and 320-pixel readability at 1× and 2× with reduced motion.

### Demo

Run `flutter test test/features/bar` from `frontend/` for the flow suite; [BAR.md](BAR.md) describes the matching contract and manual exploration. Tests use invented records only — no provider content, image, or key is a test asset or was saved.

An independent reviewer initially returned BLOCK: re-running matching duplicated results, and the contract docs were uncommitted. Both were fixed (see [M4 review](reviews/M4.md)); the main agent then re-ran the clean analysis, the full 124-test suite, and the release web build.

Limits: no live provider traffic, physical screen-reader session, or device run was performed; no server or watcher was launched. The regenerated `discovery-results` golden reflects the new "What can I make" entry point and was visually inspected. Selections and scopes are session-only by design; persistence is a later milestone decision. M5 has not started.

## M3 — Discovery and recipe detail — 2026-09-12

Executed on the development PC with Flutter 3.44.4 stable and Dart 3.12.2; all Flutter commands ran from `frontend/`:

- `flutter analyze` — no issues found.
- `flutter test --reporter expanded` — all **90 tests** passed. This retains the 50 M2-era tests (the starter-shell assertion now verifies discovery launch) and adds 40 M3 tests.
- `flutter build web --no-pub` — release web build succeeded; Wasm dry run succeeded. The previously documented warning mentioning `packages/cupertino_icons/CupertinoIcons` remains. No warning or lint was suppressed.
- `flutter test test/features/discovery/presentation/discovery_visual_test.dart --update-goldens --reporter expanded` — generated the three M3 renders. They were visually inspected, and the ordinary full suite then passed against them. M1 gallery baselines were not changed.

M3 coverage includes query validation/equality and malformed deep links, three search endpoints, filter-summary lookup, zero-request idle/empty submission, preview/all/detail/Back query preservation, typed-draft preservation across modes and submissions, keyboard-only activation, out-of-order responses, explicit retry, shared and overlapping 429 cooldowns, absolute-deadline expiry/remount, original instruction paragraphs, missing recipes, source-launch fallback, image loading/success/failure via in-memory synthetic providers, unsafe image-URL rejection, named buttons/live outcomes, and zero-duration reduced-motion routes. Bundled-font 320-pixel layouts pass at 1×, 2× and 3× text. The rendered demo screens pass Flutter's labelled-target, Android tap-target and text-contrast guidelines.

### Demo

- [Discovery screen](../frontend/test/features/discovery/presentation/goldens/discovery-mobile.png)
- [Synthetic search results](../frontend/test/features/discovery/presentation/goldens/discovery-results.png)
- [Synthetic recipe detail](../frontend/test/features/discovery/presentation/goldens/recipe-detail.png)

These are actual Flutter test renders of invented content, not provider records or photographs. The flow tests exercise name/ingredient/letter → results → full recipe → Back. For a one-shot repeatable demo, run `flutter test test/features/discovery/presentation` from `frontend/`; see [DISCOVERY.md](DISCOVERY.md) for manual exploration commands and the explicit gallery opt-in.

Terra implemented state and closeout edge tests. A separate reviewer independently ran 22 provider/cooldown/flow tests and inspected the rendered screens, approving the implementation after review findings were addressed. The main agent ran final analysis, all 90 tests and the web build. See [M3 review](reviews/M3.md).

Limits: M3 tests make no real recipe/image requests or external-browser launches. The M2 live client smoke remains recorded below, but it is not a live M3 UI test. No Android APK, native device run, real browser history/CORS or deployment rewrite test, or physical TalkBack/VoiceOver session was performed. No server or watcher was launched. Generated golden-comparison diagnostics remain local and are ignored; only reviewed baseline PNGs are tracked. No backend code, private key, personal photo or provider asset was added. M4 has not started.

## M2 — TheCocktailDB data layer — 2026-09-11

Verified on the development PC with Flutter 3.44.4 stable and Dart 3.12.2. Every Flutter command ran from `frontend/`:

- `flutter analyze` — no issues found.
- `flutter test --reporter expanded` — all **50 tests** passed: 23 existing foundation tests, 10 domain tests and 17 client tests.
- `flutter build web --no-pub` — release build succeeded; Wasm dry run succeeded. The existing M1 warning mentioning `packages/cupertino_icons/CupertinoIcons` reappeared. No icon code changed, no dependency was added to mask it, and no warning was suppressed.
- `dart run tool/m2_demo.dart` — synthetic parsing/normalization/cache checks passed with zero network calls.
- `dart run tool/m2_demo.dart --live` — one live public-key lookup decoded successfully; the repeated lookup came from cache. Provider content/images were not saved or printed.

The ordinary test suite never calls the service. Synthetic coverage includes all four endpoint/query contracts, source/attribution and named-pair round trips, blank/gapped/null slots, measure fallback and malformed-punctuation regression, each lexical alias and distinct brands/types, no-match responses, invalid input and schema, HTTP/rate-limit metadata, URI/key redaction, response-size limits, stream failure and timeout after headers, cooperative and non-cooperative abort/close, late-result rejection, immutable collections, TTL including zero, LRU eviction, in-flight deduplication and retry after malformed responses. M1 accessibility and rendered golden tests remain green and unchanged.

This is data-layer verification, not M3 navigation/UI or a new Android/device run. The main Android manifest's Internet permission was inspected but no Android release APK was built. The web shell build is not a browser-network/CORS runtime test because discovery is not wired into the app yet. No server, watcher or interactive app session was launched.

### Demo

Run `dart run tool/m2_demo.dart` from `frontend/`:

```text
Synthetic lookup: full recipe decoded.
Two lookups; 1 HTTP request; second served from cache.
Synthetic ingredient slots: 1, 3, 4, 15.
Original: "  Mint Leaves  "; normalized: mint leaf.
Measure: 1.5 tsp; source text retained.
No provider content or images written to disk.
```

The synthetic HTTP request is intercepted locally. The explicitly opted-in live demo produced:

```text
Live lookup: full recipe decoded.
Two lookups; 1 HTTP request; second served from cache.
No provider content or images written to disk.
```

The Terra subagent implemented the client/cache and its tests; independent model and final integration reviews accepted the result after fixes and test hardening. See [M2 review](reviews/M2.md) and [data contract](DATA.md). No backend code, private key, source photo or provider record was added. At this checkpoint, M3 had not started.

## M1 — Botanical Play — 2026-09-11

Verified on the development PC using Flutter 3.44.4 stable and Dart 3.12.2, with all Flutter commands run from `frontend/`:

- `flutter analyze` — no issues found.
- `flutter test` — all 23 tests passed.
- `flutter build web --no-pub` — release build succeeded; Wasm dry run also succeeded. No server or watcher was started.

Coverage includes semantic color contrast, visible control outlines, theme/type roles, platform text scaling, disabled actions, preview save/unsave and chip selection, retry/reset, sheet results, explicit close and Escape, modal keyboard focus containment/restoration, keyboard insets, system reduced-motion precedence, and immediate reduced-motion sheet/chip transitions. The actual bundled fonts are loaded for the gallery's 320-pixel layout tests at 1×, 2× and 3× text. A regression checks both horizontal and vertical bounds of a selected chip's entire label at 3×; merely checking for overflow exceptions did not catch the original fading/clipping behavior.

Flutter's labelled-target, Android 48-pixel tap-target, and text-contrast guidelines pass for the gallery and modal. These automated checks are not a substitute for future testing with TalkBack/VoiceOver on physical devices. No fresh device run was performed for M1.

### Demo

These are Flutter widget-test renders using bundled Fraunces, DM Sans and Material Icons, not the earlier HTML studies:

- [Mobile gallery](../frontend/test/app/goldens/botanical-mobile.png)
- [Full component gallery](../frontend/test/app/goldens/botanical-gallery.png)
- [Recipe-options sheet](../frontend/test/app/goldens/botanical-sheet.png)

The visual regression test compares all three images. Baselines were generated with `flutter test test/app/design_gallery_golden_test.dart --update-goldens`, visually inspected, then checked by the ordinary test suite. Rendering baselines reflect this Windows Flutter engine and may require review on a different host/engine.

To explore manually, run `flutter run -d chrome` from `frontend/`. Select ingredients, save/unsave the illustrative recipe, open/close its options, try the error action, and enable Reduce motion under Preview controls. Changes are temporary. The gallery is enabled by default only in debug builds; release/profile launches retain the small branded foundation screen.

The initial web build reported an expected-font mismatch mentioning `packages/cupertino_icons/CupertinoIcons`; all authored icons use Material Icons and their rendered glyphs were checked. The final incremental web build completed without repeating that warning. No dependency was added and no build warnings were suppressed.

Independent review accepted the final implementation after the chip regression and keyboard tests were added; see [M1 review](reviews/M1.md). At this checkpoint, M2 had not started.

## Development-PC baseline — 2026-09-10

At the start of M1, the development checkout was on `Development` at `018a473` with a clean worktree. Baseline commits and a GitHub origin were present; Android and web wrappers, `frontend/.metadata`, and `frontend/pubspec.lock` were tracked.

Executed from `frontend/` on the development PC:

- `flutter analyze` — no issues found.
- `flutter test` — all tests passed (1 starter-screen widget test).

The roadmap separately records Adam's successful starter-app build and run on 2026-09-10. The checks above verify analysis and the widget test; they are not a new device run or a claim that M1 is implemented.

The following sections preserve the original scaffold verification history from the production host. Their host constraints do not describe the current development PC.

## Original production-host constraint

This production host intentionally has no Flutter or Dart executable available. No SDK was installed or downloaded, and no `pub get`, `flutter analyze`, `flutter test`, build, or application run was attempted.

## Static checks completed

The source scaffold was checked with Python standard-library structure assertions and Git inspection. These checks confirm expected authored paths, `zest` package/import naming, direct Flutter SDK dependencies, matching starter-screen test strings, no tracked files in the new repository, and ignore coverage for local signing material.

These static checks are **not** Dart compilation, Flutter analyzer, widget-test, dependency-resolution, native build, or runtime proof. Run the development-PC commands in `README.md` before treating this as a working Flutter application.

## Documentation consulted

- Flutter create reference: https://docs.flutter.dev/reference/create-new-app
- Flutter web support: https://docs.flutter.dev/platform-integration/web/building
- Flutter desktop support: https://docs.flutter.dev/platform-integration/desktop
- Flutter `Template.render` no-overwrite implementation: https://github.com/flutter/flutter/blob/master/packages/flutter_tools/lib/src/template.dart
- Flutter create-command overwrite wiring: https://github.com/flutter/flutter/blob/master/packages/flutter_tools/lib/src/commands/create.dart

The web and desktop documentation explicitly describes `flutter create` with `--platforms` in an existing project to add generated platform directories. The development-PC handoff uses `flutter create --project-name=zest --platforms=android,ios,web --no-pub .`, followed separately by `flutter pub get`, analysis, tests, and a device-ID-based run. The Flutter source references above establish that omitting `--overwrite` skips existing authored files; this was documented from source review, not executed on this host. Commands and generated outputs remain intentionally deferred to the development PC.
