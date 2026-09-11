# Verification record

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

Independent review accepted the final implementation after the chip regression and keyboard tests were added; see [M1 review](reviews/M1.md). M2 has not started.

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
