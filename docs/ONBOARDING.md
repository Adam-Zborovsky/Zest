# Onboarding and login (M7)

M7 adds a swipeable onboarding and a login page in front of the app. This document is the build contract for the M7 tracks and becomes the feature record once M7 closes. The onboarding flow and launch states remain unchanged in M8, which replaced the local-profile login with email/password accounts (see [docs/ACCOUNTS.md](ACCOUNTS.md)).

## Decisions (Adam, 2026-09-13)

- **Local-first auth.** The login page offers "Continue on this device", which creates or resumes a profile stored only on this device. There is no account, credential, server, or sync. `AuthRepository` is the seam where Supabase or Firebase can replace the local implementation later without changing screens or routing. Copy never implies sync, backup, encryption, or cloud storage.
- **Design from Stitch.** Screens were generated in the Night Garden Stitch project (16214953980663714442) with `GEMINI_3_8_FLASH` and are converted into the existing tokens and primitives, with the corrections listed below.
- **Structure.** Four content pages (constellation, bar, variation, photo), then login as the fifth step. Next on page 4 and Skip on any page both record onboarding as seen and go to login.
- **Persistence.** `shared_preferences` 2.5.x through `SharedPreferencesWithCache`, created in `main()` before `runApp`, so launch state is synchronous and no splash state exists. It is the flags store already named in `AGENTS.md`.
- **Sign-out** lives in a profile sheet opened from the shared top bar next to the collection button. Signing out never deletes the profile or any collection data.

## Launch states

| Onboarding seen | Signed in | Destination |
| --- | --- | --- |
| no | no | onboarding |
| yes | no | login (Skip pressed, or signed out) |
| any | yes | app |

Signing in also records onboarding as seen, so a later sign-out lands on login even for someone who reached login by a direct link. Signed-out people can move between onboarding and login ("Replay the tour"); every other location redirects to their gate. Signed-in people are redirected away from both gates to home.

## Contract (committed before the tracks start)

| File | Status | Holds |
| --- | --- | --- |
| `lib/features/onboarding/domain/launch_destination.dart` | Contract | `LaunchDestination`, `resolveLaunch`, `SessionRoutes`, `launchRedirect` |
| `lib/features/onboarding/domain/local_profile.dart` | Contract | `LocalProfile`, name normalization (trim, blank is none, at most 40 code points), JSON |
| `lib/features/onboarding/data/session_stores.dart` | Contract | `OnboardingStore`, `AuthRepository` and their invariants, `SessionStorageException` |
| `lib/features/onboarding/application/session_controller.dart` | Contract | `SessionController`, the router's `refreshListenable` |
| `lib/features/onboarding/application/session_providers.dart` | Contract; store bodies wired by the state track | Riverpod providers |
| `lib/features/onboarding/presentation/onboarding_screen.dart` | Implemented | `OnboardingScreen` |
| `lib/features/onboarding/presentation/login_screen.dart` | Implemented | `LoginScreen` |
| `test/support/in_memory_session.dart` | Contract | In-memory stores with failure injection, `syntheticProfile`, `sessionTestOverrides` |
| `test/features/onboarding/application/session_controller_test.dart` | Contract | The roadmap state machine, redirect table, and profile rules |

Tracks may not change contract files. A needed change is reported back to the integrator instead.

## Tracks

- **State track.** Adds `shared_preferences` with its stated reason; implements `PrefsOnboardingStore` and `PrefsAuthRepository` over `SharedPreferencesWithCache` with a contract suite run against both the prefs and in-memory implementations; wires the providers and `main()`; gives `createZestRouter` the session redirect, `refreshListenable`, and the `/onboarding` and `/login` routes; adds `sessionTestOverrides()` to every existing test that pumps `ZestApp`; and adds app-level tests that launch into each roadmap state.
- **Onboarding track.** Replaces `OnboardingScreen`: a `PageView` of four pages with Next, Back, Skip, visible progress, keyboard and screen-reader access, no automatic advance and no waits on animation. Each page shows a live demonstration built from the app's real components with synthetic data, never real providers. Adds the lime-wedge character as a `CustomPainter` in `lib/core/widgets/`. Provides reduced-motion variants, flow tests, and goldens.
- **Login track.** Replaces `LoginScreen`: optional name, "Continue on this device", loading and inline error states, a welcome-back variant prefilled from the last profile, "Replay the tour", and the honest local-only note. Adds the profile sheet and its top-bar button with sign-out. Tests and goldens.

## Build record (2026-09-13)

- **State track — merged.** `shared_preferences` 2.5.x with `SharedPreferencesWithCache` created in `main()` before `runApp`. `PrefsOnboardingStore` and `PrefsAuthRepository` with a shared contract suite run against prefs and in-memory implementations. Routes `/onboarding` and `/login` with session-based go_router redirect and `refreshListenable`. App-level tests launch into each roadmap state. Analysis clean, 390 tests pass. See [reviews/M7.md](reviews/M7.md) — Finding 1 (write order) fixed; Finding 2 (startup exception) accepted as limitation; Finding 3 (name length) fixed; Finding 4 (step count) verified intentional.
- **Onboarding track — merged.** Four `PageView` pages with constellation, bar, variation, and photo demonstrations built from the public design primitives (`IngredientGlyph`, `paintIngredientGlyph`, `PaperTag`, `NightBand`, `ZestCard`) with synthetic data; no feature widget was made public, so the demos imitate the real screens rather than reuse them. `LimeSprite` character as `CustomPainter`. Next, Back, Skip, visible "n of 5" progress. No animation waits or automatic advances. Reduced-motion variants. Keyboard and screen-reader access. Goldens included.
- **Login track — merged.** Optional name field, "Continue on this device", returning-user prefilled welcome variant, "Replay the tour" link, honest local-only note. Loading and inline error states. Profile sheet (signed-in top bar) with sign-out (never deletes profile or collection). Goldens included.
- **Integrator polish — merged.** Lime sprite waves on login. Launch-flow tests through real screens. Sprite moved inside band so it does not cover page heading. Night band proportions, fennel page ground, opaque page 2 swap strip, page 4 calendar tiles, constellation label font in goldens, sprite color refinement (commits `cc216a9`, `9ab6ae7`, `e20562f`).
- **Known limitation — startup exception.** If `SharedPreferencesWithCache.create` throws, the app does not render. The app cannot function without its flags store; revisit alongside deferred Android lost-photo recovery.
- **Not verified.** On-device real-platform `shared_preferences`, screen-reader session, Adam's visual approval of the lime character and full screens. M7 is not marked DONE; closeout awaits Adam's on-device check.

## Design references and corrections

Screens: page 1 `ccfd7bf839f34b58a6eefc276810af49`, page 2 `61e1caf4f4f94d1bba9fb66fed297192`, page 3 `6fe00db6c5364881bda9c3d107c0bfff`, page 4 `87844284703948bbb6903d97f2276dd6`, login `7796fee39cf34e68a16d286c319cfdd4`.

Corrections applied in conversion:

- No invented counts (page 1's "142") and no invented substitutions (page 2's "Swap lemon for lime"); demonstrations use only reviewed tables or neutral wording.
- No "Encrypted on device", version, or "Offline ready" labels on login; the collection database is not encrypted.
- No "My spin" chip; variations read "Your variation of <recipe>".
- Stitch's Epilogue headings become Fraunces; its palette and shapes map to the existing tokens.
- No dot texture behind text on the fennel page.
- The night band takes a minimum share of the page height (about 68% on onboarding and 56% on login) with its content centered, so the fennel section below is not left mostly empty. The character renders at about 96 logical pixels on onboarding and 64 on login.

## Out of scope

Cloud accounts and sync, returning to a deep-linked page after login, a settings tour replay for signed-in people, profile deletion, and any camera or photo permission during onboarding.
