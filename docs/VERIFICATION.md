# Verification record

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
