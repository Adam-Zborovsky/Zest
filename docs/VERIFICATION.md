# Verification record

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
