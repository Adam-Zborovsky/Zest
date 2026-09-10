> **Note (2026-09-10):** after these reviews, the repository was reorganized into a monorepo — the Flutter app moved to `frontend/`, PRODUCT.md and VERIFICATION.md moved to `docs/`. Paths below are as they were at review time and are preserved unchanged as a historical record.

# Review: Zest source scaffold and dev-PC setup (t_3969d1a0)

Reviewer profile: reviewer (claude-fable-5-1, anthropic). Author: orchestrator-lane worker for t_b754f86c.

## Verdict: REVISE (documentation defects only; source scaffold itself is sound)

The Dart source, test, pubspec, analysis options, gitignore, PRODUCT.md and git state all pass.
Two items in README.md are hard errors in developer instructions and must be fixed before this
is handed to the dev PC. No implementation code changes are required.

## Hard errors (fix required)

1. README.md "Run on an available target": `flutter run -d android` and `flutter run -d ios`
   are presented as working device selectors. They are not. Flutter resolves `-d` by exact or
   prefix match against a *device id or device name* (`getDevicesById` in
   `packages/flutter_tools/lib/src/device.dart`: `exactlyMatchesDeviceId` / `startsWithDeviceId`).
   Android device ids are serials or `emulator-5554`, names are model names; iOS simulator ids
   are UUIDs. Neither "android" nor "ios" matches in the common case, so the command fails with
   "No supported devices found with name or id matching". `-d chrome` is valid (the web device
   id is literally `chrome`). Fix: instruct `flutter devices`, then `flutter run -d <device-id>`;
   keep `-d chrome` as the one literal example.
   Source: https://github.com/flutter/flutter/blob/master/packages/flutter_tools/lib/src/device.dart

2. README.md step 2 relies on `git diff -- lib/main.dart test/widget_test.dart pubspec.yaml` to
   detect overwrites, and step 1 on `git status --short` to confirm a clean checkout. The repo as
   delivered has zero commits and every file is untracked (`git status`: "No commits yet on main",
   all `??`). `git diff` prints nothing for untracked files, so the guard is a no-op until a
   baseline commit exists. Fix: add an explicit first step on the dev PC — commit the authored
   files as the baseline (`git add -A && git commit -m "Zest source foundation"`) — before running
   `flutter create`, so `git status`/`git diff` become meaningful. Also reword "If an installed
   Flutter release proposes changes": `flutter create` does not propose; without `--overwrite` it
   silently skips existing files (see next section), and with it deletes and rewrites them.

## Verified from Flutter tool source (no SDK run)

- No-overwrite behavior IS established: `Template.render` with `overwriteExisting: false` hits
  `finalDestinationFile.existsSync()` -> logs "(existing - skipped)" and returns. `CreateCommand`
  passes `overwriteExisting: overwrite` (the `--overwrite` flag, default false). So
  `flutter create --platforms=android,ios,web .` will not touch lib/main.dart,
  test/widget_test.dart, pubspec.yaml, analysis_options.yaml or .gitignore; it adds android/,
  ios/, web/ and .metadata. README's "do not add --overwrite" is correct; README should cite this
  rather than imply a diff-based safety net.
  Sources:
  https://github.com/flutter/flutter/blob/master/packages/flutter_tools/lib/src/template.dart
  https://github.com/flutter/flutter/blob/master/packages/flutter_tools/lib/src/commands/create.dart
- `--project-name` is not required: `CreateBase.projectName` falls back to the `name` field of an
  existing pubspec.yaml (`zest`) when the flag is absent.
  Source: https://github.com/flutter/flutter/blob/master/packages/flutter_tools/lib/src/commands/create_base.dart
- `flutter create` runs `pub get` by default (`--pub` defaults true). README step 3's separate
  `flutter pub get` is therefore redundant but harmless.

## Checks run on this host (static, non-SDK)

- git status --short --branch: branch main, no commits, 8 untracked authored files, nothing else.
  No .dart_tool, build, pubspec.lock, .metadata, platform dirs, IDE files.
- File inventory matches parent handoff (8 files).
- lib/main.dart: `ZestApp` root, `ZestHomePage`, two Text widgets, no buttons/inputs/network/
  fake data. Names all Zest/zest. Material 3 seed theme. No counter template remnants.
- test/widget_test.dart: imports `package:zest/main.dart`, pumps `ZestApp`, asserts the two exact
  strings present in main.dart. `find.text('Zest')` -> findsOneWidget is correct (MaterialApp
  `title` is not a Text widget). No phantom default counter test.
- pubspec.yaml: name zest, publish_to none, sdk '>=3.3.0 <4.0.0', only flutter/flutter_test SDK
  deps, uses-material-design. Coherent with analysis_options.yaml, which has no
  `package:flutter_lints` include (flutter_lints is not declared, so an include would have broken
  analyze — correctly avoided).
- .gitignore: covers .dart_tool, build, native ephemeral dirs, IDE, .env*, *.pem, *.key,
  personal-media paths. `git check-ignore` not re-run (parent did).
- grep for secrets/keys/tokens: none. grep for counter/MyApp/cocktail_companion: none.
- PRODUCT.md vs brief (/home/ubuntu/.hermes/profiles/orchestrator/plans/cocktail-app-brief.md):
  name/package, TheCocktailDB, app-wide visual flair, Ingredient Constellation semantics
  (collection-prevalence caveat, no invented numbers, reduced-motion route), one private photo
  per entry, swipeable onboarding with Skip -> login, interface-led small illustrated character,
  persisted onboarding state, open auth decisions, source-rights boundary — all faithfully
  represented; "not implemented" boundary is explicit.
- VERIFICATION.md: truthful about what was and was not run.

## Not run (Flutter/Dart intentionally absent on this production host)

Dart compilation, flutter pub get, flutter analyze, flutter test, flutter create wrapper
generation, any build or runtime. All source-level correctness claims above are static reading,
not compiler proof.

## Suggestions (non-blocking)

- Add `--no-pub` to the `flutter create` command if the intent is to keep dependency resolution
  as a separately controlled step (matches the README's own step 3).
- .gitignore: add `android/key.properties`, `*.jks`, `*.keystore` now so release-signing secrets
  can never be committed later. `.packages` is obsolete but harmless.
- Consider adding `flutter_lints` as a dev dependency with the standard include once pub get is
  available on the dev PC; the current lint-free config is coherent but minimal.
- Note in README that `.metadata` (generated by flutter create) should be committed.

---

# Recheck: Zest handoff corrections (t_369d2dde)

Reviewer profile: reviewer (claude-fable-5-1, anthropic). Author of corrections: t_008cfc0b worker.

## Verdict: PASS

Both hard errors from the initial review are resolved. Scope of the repair was limited to
README.md, .gitignore and VERIFICATION.md; no implementation or source change occurred.

## Initial findings — status

1. Device selectors — RESOLVED. README step 4 now instructs `flutter devices` followed by
   `flutter run -d DEVICE_ID`, with `-d chrome` kept as the only literal example. `-d android` /
   `-d ios` no longer appear anywhere in README.md.
2. Untracked-file guard — RESOLVED without requiring a host commit. README step 1 states plainly
   that the authored files are initially untracked, that `git diff` cannot show changes until a
   tracked baseline exists, and directs the developer to keep an untouched copy of the checkout as
   the recovery point. No-overwrite behavior is explained from the already-verified upstream
   source (`Template.render` skip on existing destination; `CreateCommand` passes the
   `--overwrite` flag, default false) rather than implied by a diff-based safety net. The
   "proposes changes" wording is gone. No commit is made or demanded on this host.

## Checks run on this host (static, non-SDK)

- git status --short --branch: "No commits yet on main"; only authored paths untracked
  (.gitignore, PRODUCT.md, README.md, VERIFICATION.md, analysis_options.yaml, docs/, lib/, test/,
  pubspec.yaml). No .dart_tool, build, .metadata, pubspec.lock, platform dirs.
- Source untouched by the repair: lib/main.dart, test/widget_test.dart, pubspec.yaml,
  analysis_options.yaml, PRODUCT.md all carry 11:45 mtimes (authoring pass); only README.md,
  .gitignore, VERIFICATION.md carry 11:53 mtimes (repair pass).
- README grep: `flutter devices` and `flutter run -d DEVICE_ID` present; no `-d android`, `-d ios`.
- README: SDK work is explicitly dev-PC-only; host section says do not install or run SDK here.
- .gitignore: `git check-ignore --no-index -v` matches android/key.properties (line 11), *.jks
  (line 32), *.keystore (line 33). Prior suggestion adopted.
- README step 2 now uses `--no-pub`, consistent with the separate `flutter pub get` in step 3
  (prior suggestion adopted). `--project-name=zest` is redundant with pubspec `name` but harmless.
- VERIFICATION.md: states no SDK present, nothing installed/downloaded/run, static checks are not
  compile/analyze/test/build proof, and that no-overwrite was documented from source review, not
  executed. Truthful.
- Secret grep across .md/.yaml/.dart: no tokens, keys or credentials.

## Not run (unchanged limitation)

Flutter/Dart are intentionally absent on this production host. Dart compilation, pub get,
analyze, test, `flutter create` wrapper generation, build and runtime remain unverified here and
must be exercised on the development PC per README.

## Suggestions (non-blocking)

- README step 1 says "preserve an untouched copy" but does not give the mechanical step; a
  one-liner such as copying the checkout directory before `flutter create` would remove ambiguity.
