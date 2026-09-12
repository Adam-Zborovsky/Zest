# Zest design system — Botanical Play

Adam selected **C — Botanical Play** from the three [M1 studies](design/m1/README.md): leafy greens, soft shapes, and cut-paper garnish. The Flutter foundation implements that direction in Material 3. M1 verification is recorded separately in [VERIFICATION.md](VERIFICATION.md); this document describes the implementation, not a certification of accessibility or milestone completion.

## Visual language

Pale fennel backgrounds hold peach cards, dark leaf typography, celery controls, and small grapefruit accents. Fraunces gives headings a soft, irregular character; DM Sans keeps instructions and controls direct. Asymmetric recipe-card corners and original painted citrus, leaves, and glassware carry the identity through ordinary components and loading, empty, and error states. Decorative art is excluded from semantics and never contains essential information.

The app currently has one deliberate light theme, including when the device prefers dark mode. Dark appearance needs its own design and contrast review before implementation. The foundation adds no package dependencies and makes no network requests for fonts or artwork.

## Tokens and theme roles

The source of truth is `frontend/lib/core/design/zest_tokens.dart`; `zest_theme.dart` maps primitives into Material roles. Feature widgets should use `Theme.of(context).colorScheme` and `textTheme` rather than repeat hex values.

| Token | Value | Role |
|---|---|---|
| `fennel` | `#F3F5DF` | Page and low container backgrounds |
| `leaf` | `#193F32` | Primary actions, headings, body text, illustration outlines |
| `celery` | `#DBE9B0` | Secondary controls and primary/secondary containers |
| `grapefruit` | `#F9A58C` | Small illustrative accents and tertiary container |
| `peach` | `#FFF9ED` | Cards, sheets, and text on dark controls |
| `berry` | `#813C4D` | Error ink/actions and tertiary role |
| `secondaryInk`, `outline` | `#496453` | Supporting text and meaningful control boundaries |
| `divider` | `#DCE2CB` | Decorative separators and card outlines |
| `errorSurface` | `#FFF0F3` | Error-state card |
| `disabledSurface` | `#E4E6D7` | Disabled controls |
| `disabledInk` | `#707668` | Disabled control labels |

The stronger secondary ink and outline replace faint treatments in the static study. Use dark leaf text on the pale accents; peach is for text on leaf or berry. Decorative dividers do not convey control identity. Errors include a written explanation, an icon, and a retry action, so color is not the sole signal.

## Typography

Both font families are bundled variable fonts with their OFL licenses; see the [font provenance record](../frontend/assets/fonts/README.md). Fraunces uses weight 600, `SOFT` 60, and `WONK` 1. DM Sans uses weight 400 for body copy and 600 for titles, controls, and small captions. The heavier 14-pixel captions preserve legibility in rendered contrast checks with the bundled font.

| Material styles | Size / line-height multiplier | Family |
|---|---|---|
| `displayLarge`, `displayMedium`, `displaySmall` | 40 / 1.08, 34 / 1.12, 30 / 1.15 | Fraunces |
| `headlineLarge`, `headlineMedium`, `headlineSmall` | 28 / 1.2, 24 / 1.22, 22 / 1.25 | Fraunces |
| `titleLarge` | 20 / 1.3 | Fraunces |
| `titleMedium`, `titleSmall` | 18 / 1.5, 16 / 1.5 | DM Sans 600 |
| `bodyLarge`, `bodyMedium` | 16 / 1.5 | DM Sans 400 |
| `bodySmall` | 14 / 1.5 | DM Sans 600 |
| `labelLarge`, `labelMedium`, `labelSmall` | 16 / 1.5, 14 / 1.5, 12 / 1.5 | DM Sans 600 |

Use `fontWeight` for the variable weight axis. Flutter applies it to `wght` starting in stable 3.41; Zest declares Flutter >=3.44.0 and Dart >=3.12.0 and is developed here with Flutter 3.44.4. Explicit variations are reserved for Fraunces' non-weight axes. [Flutter font-weight change](https://docs.flutter.dev/release/breaking-changes/font-weight-variation).

## Layout, shape, and elevation

Spacing tokens in logical pixels are `xs` 4, `sm` 8, `md` 12, `lg` 16, `page` 20, `xl` 24, `section` 28, and `xxl` 32. Interactive targets have a 48-pixel minimum. The gallery and modal sheets use a 480-pixel maximum content width; text and content determine height.

Controls have 16-pixel corners, ordinary cards 24, and sheets 32 at the top. Recipe cards use directional corners: top-start/bottom-end 36, top-end/bottom-start 14. Controls and cards stay flat at elevation 0; sheets use elevation 4. Surface tint is transparent so Material elevation does not shift the palette.

Allow text scaling without clamping it. Layouts wrap controls, use flexible text, and scroll vertically. Chip labels explicitly override Flutter's single-line fading defaults so selected labels can wrap at large text sizes. The gallery heading stacks when width is under 330 logical pixels or scaled 16-pixel text exceeds 24 pixels. Safe areas and keyboard insets keep sheet content reachable.

## Motion and accessibility

Motion supports immediate feedback and spatial context. Token durations are feedback 140 ms, sheet entrance 260 ms, and sheet exit 180 ms. The reusable ease-out token is `Cubic(0.2, 0.0, 0.0, 1.0)`; Material controls and modal routes retain their framework curves. There is no decorative entrance sequence, recurring loading animation, or forced wait. Loading uses a static botanical marker and a live-region label.

Reduced motion is active when either `MediaQuery.disableAnimations` or `MediaQuery.accessibleNavigation` is true. The gallery can additionally enable reduced motion for comparison; it cannot disable a system request. Reduced motion sets custom control feedback durations to zero, removes ink splashes, and uses `AnimationStyle.noAnimation` for modal sheets. Theme changes are immediate in both modes. The sheet helper uses Flutter's duration and focus APIs. [Flutter modal bottom-sheet reference](https://api.flutter.dev/flutter/material/showModalBottomSheet.html).

Buttons use native Material interaction semantics and visible keyboard focus borders. Chips expose selected state with a checkmark as well as color. The modal requests focus, initially focuses its labelled close button, supplies a labelled dismiss barrier, and keeps content scrollable. Headings are marked semantically; decorative art and drag handles are excluded from reading order. Empty states explain the situation and offer an action. Error and loading states announce relevant text through live regions.

## Shared primitives and gallery

`frontend/lib/core/widgets/` contains `ZestButton` (primary, secondary, quiet, danger, disabled), `ZestCard` (standard or recipe shape), `ZestChip`, `showZestSheet`, `ZestEmptyState`, `ZestLoadingState`, `ZestErrorState`, and `BotanicalArt`.

The temporary `DesignGallery` demonstrates these primitives with invented content. Chip selection, save/unsave, retry feedback, sheet actions, and reset operate only on local specimen state and are discarded on restart. They do not implement recipe discovery, storage, matching, or networking.

From M3, the app launches discovery in all build modes. The gallery requires the explicit `ZEST_DESIGN_GALLERY=true` define in a debug build; profile/release ignore that gallery request. Adam subsequently approved graph-first home for M5; its relationship to the label system remains open. The gateway increment changes no visual components or golden baselines.

## M3 feature application

Discovery pairs a name/ingredient search form with an expandable A–Z index. Returned recipes use asymmetric cut-paper cards; detail puts source measures on a peach ingredient panel alongside plain, numbered source paragraphs. No new palette or fonts were added. Feature pages have an 800-pixel maximum width while retaining the M1 spacing/type roles; returned-results lists build lazily. Loading/empty/error and image fallback states retain botanical artwork and clear recovery text.

Image captions grow outside the fixed image region. Missing/failed imagery is explicitly labelled and never credits Zest's placeholder artwork as provider photography. Native button text semantics include the destination recipe name. Empty/rate-limit outcomes announce separately from controls and countdowns; source-launch failures offer a selectable address. The 140-ms route fade becomes immediate under either reduced-motion flag. See [DISCOVERY.md](DISCOVERY.md) for flow decisions and synthetic renders, and [VERIFICATION.md](VERIFICATION.md) for tested limits.

## M4 feature application

The bar screen reuses the discovery shell, cards, sheet, and state primitives — no new palette, fonts, or shapes. The scope card states the matching boundary in words before any result appears; the selection card holds removable checked chips plus the picker sheet, whose option rows are native checkbox tiles with 48-pixel rows and announced shown/total counts. Matching progress is the static botanical loading marker with a live-region "Checking recipes… X of Y"; a pause reuses the M3 cooldown card with its countdown. Results keep the asymmetric recipe card and add a status line whose meaning is carried by an icon and text together, never color alone: ready, possible-with-substitution (each suggestion spelled out and labeled as reviewed), or missing essentials with the missing list inline and the group sorted by fewest missing. Garnish exclusions are noted per card in small text. Group headings are semantic headers; the completion summary is announced through a live region, and the coverage footnote ("not the full cocktail catalog") is always visible on the page. Readability at 320 logical pixels with 1× and 2× text and reduced motion is tested. See [BAR.md](BAR.md) for the flow contract.
