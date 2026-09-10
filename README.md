# Zest

A source-only Flutter foundation for an expressive cocktail companion. The current screen is deliberately small: it proves the authored app root and test shape only. Product capabilities described in [PRODUCT.md](PRODUCT.md) are planned requirements, not implemented features.

## This host does not run Zest

This repository was authored on a production host where Flutter and Dart are intentionally absent. Do not install or run SDK tooling here. Use a separate development PC with a current stable Flutter SDK. iOS development requires macOS with Xcode.

## First setup on the development PC

Start from the repository root. The commands below are shell-neutral Flutter CLI commands; use PowerShell, Terminal, or another shell as appropriate.

1. Preserve an untouched copy of this source checkout before generating platform wrappers. The authored files are initially untracked, so `git diff` alone cannot show whether they changed; it only becomes useful after a tracked baseline exists. Do not create a Git commit solely for this setup.

   Use `git status --short` to understand the checkout state:

   ```text
   git status --short
   ```

2. Generate only the required native/web wrappers for this existing source project:

   ```text
   flutter create --project-name=zest --platforms=android,ios,web --no-pub .
   ```

   Flutter documents `flutter create . --platforms web` for adding web support to an existing project and the same `--platforms` pattern for desktop support. This command generates `android/`, `ios/`, and `web/` (plus Flutter tool metadata as needed) but does not resolve dependencies because of `--no-pub`.

   Do not add `--overwrite`. Flutter's `Template.render` skips an existing destination when overwrite is false, and `CreateCommand` passes the `--overwrite` flag (false by default) to that rendering path. Therefore the authored source files are preserved by the no-overwrite behavior; keep the untouched copy as the independent recovery point. Source: [Template.render](https://github.com/flutter/flutter/blob/master/packages/flutter_tools/lib/src/template.dart) and [CreateCommand](https://github.com/flutter/flutter/blob/master/packages/flutter_tools/lib/src/commands/create.dart).

   `.metadata` and the application `pubspec.lock` are generated on the development PC. Review them and normally include them in a later user-approved commit; this source-only handoff does not create that commit.

3. Resolve dependencies and validate the source:

   ```text
   flutter pub get
   flutter analyze
   flutter test
   ```

4. List available targets, then run one by its listed device ID:

   ```text
   flutter devices
   flutter run -d DEVICE_ID
   ```

   Replace `DEVICE_ID` with an ID reported by `flutter devices` (for example, an attached Android serial, an iOS simulator UUID, or another listed target). `flutter run -d chrome` is also a valid web-specific example because `chrome` is its device ID. Select only targets supported by the development PC.

## Project files

- `lib/main.dart` — minimal `ZestApp` starter screen.
- `test/widget_test.dart` — matching starter-screen widget test.
- `PRODUCT.md` — canonical agreed product requirements and explicit implementation boundary.
- `VERIFICATION.md` — host-side static verification and its limits.
- `analysis_options.yaml` — self-contained analyzer configuration with no package include.
- `.gitignore` — ignores tool outputs, local native settings, secrets, and local personal-media paths.

## Source boundary

The future app will use TheCocktailDB as its recipe source, but no provider data, images, API key, network integration, or content-license grant is included here. Personal photos are a planned private archive feature and must not be tracked in the public repository. See [PRODUCT.md](PRODUCT.md) for the full boundary and unresolved decisions.

## References

- [Flutter: create a new app](https://docs.flutter.dev/reference/create-new-app)
- [Flutter: add web support to an existing app](https://docs.flutter.dev/platform-integration/web/building)
- [Flutter: add desktop support to an existing app](https://docs.flutter.dev/platform-integration/desktop)
