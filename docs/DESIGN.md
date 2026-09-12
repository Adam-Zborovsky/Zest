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

## Night Garden redesign (2026-09-12)

Adam found the M5 screens flat and crowded, relaxed the M5 "no new tokens, fonts, or shapes" and "single settle only" rules, and picked direction B, "Night Garden", from three Stitch concepts (project 16214953980663714442, generated with `GEMINI_3_8_FLASH`). This section supersedes the M5 canvas colors and the no-new-tokens statements below; the rest of this document stands.

- **Page shell.** Every page opens on a full-bleed leaf-green night band (`NightBand`): the wordmark in a peach disc, an optional celery eyebrow, a peach Fraunces heading with an optional grapefruit accent, and a celery intro. The band ends in a deterministic torn-paper edge and the fennel page continues below. Band and body share one sliver, so large text never leaves the body unbuilt. Selected controls on the band invert to peach with leaf ink.
- **New tokens.** `night` (leaf), `moss` `#2E5E4C` for raised night surfaces and spirit glyphs, `nightInk` (peach), `nightMuted` (celery), `pageWidth` 800, `ZestShape.pill`, `ZestShadow.hard` (an unblurred offset shadow), and `ZestMotion.pop` 320 ms.
- **Depth means pressable.** Hard shadows are reserved for primary and danger buttons, action tiles, recipe cards, and the home search field. Ordinary cards stay flat. Secondary buttons are celery with a 1.5-pixel leaf outline. Inputs are peach with a 1.5-pixel leaf outline and a 3-pixel focus outline.
- **Constellation.** The canvas sits unboxed on the night field over a star-dot texture (`NightDotField`), which is kept out from behind text so rendered contrast checks stay meaningful. Nodes are cut-paper glyph discs grouped by ingredient name: spirits are moss with a bottle, liqueurs and bitters berry with a dropper, citrus grapefruit with a wheel, sweeteners peach with cubes, herbs and spice celery with a leaf, and everything else a quiet ringed disc. Lines are peach string, the selected neighborhood is celery, and the selected edge and node halo are grapefruit. Labels are peach pills. A legend under the search field names only the groups present and states "Colors group ingredients by name, not by flavor."
- **Home order.** The night band holds the heading, the Graph/List switch, and the canvas. The page then carries search with its count line, the legend, selection details, two action tiles (grapefruit "Find recipes" and night "What can I make?", side by side from 340 pixels and stacked below that or at large text), the sync card, and attribution. A finished sync collapses to one identified coverage line with an "About these counts" sheet holding the completeness guidance, instead of repeating it on the page. The "graph is decorative" caption is gone; the canvas, including its gesture layer, stays excluded from semantics, and the list view remains the full textual equivalent.
- **Recipe detail.** Metadata appears as inked paper tags. Ingredients sit in a recipe card as glyph rows with measures in celery tags (dashed when not provided) and twine dividers. Steps use grapefruit seals announced as "Step n".
- **Bar.** Match status sits in a tinted strip (celery ready, grapefruit substitution, error surface for missing essentials); meaning still comes from the icon and text.
- **Motion.** Added a one-shot pop on the newly selected node and a press-sink on shadowed buttons and tiles at the feedback duration. Nothing loops. Under either reduced-motion flag no pop controller is created and sinks are immediate; the settle rules below are unchanged.
- **Verification.** A new `home-night-garden` golden renders a synthetic collection with the tap-target and text-contrast guidelines; the discovery and gallery goldens were regenerated and reviewed. Dark appearance and the on-device profile check remain open.

## M5 feature application

Home leads with the constellation. The graph canvas applies the existing palette through the theme (no new tokens, fonts, or shapes): leaf-toned nodes on the fennel background, celery connection lines, grapefruit selection accents. Node radius maps prevalence to area — roughly linear in distinct-recipe count — bounded to 10–26 logical pixels; edge weight carries through stroke width and opacity. Labels follow a priority order (search matches, then the selected neighborhood, then the top eight by prevalence) and are greedily collision-filtered so nothing overlaps. Count lines disclose the bound: "Showing the top 40 of N ingredients by prevalence."

The default bounded view is **top 40 ingredients by prevalence**. If the development device cannot hold 60 fps at that count in the profile run, lower the value and record the chosen number here.

Motion is a single settle: positions animate once with the sheet-entrance duration and the standard ease-out token, then stay still — no loops, no recurring animation. Under either reduced-motion flag no animation controller is created and the final deterministic layout renders immediately; both flags are tested. The canvas is excluded from semantics; a list view carries the same prevalence and connection information, meeting the app-wide 48-pixel target for its rows. Node taps pad to a 48-pixel effective target; the canvas edge corridor is a recorded 32-pixel exception, deliberate because every edge also has three non-canvas equivalents (the info-surface button, list-view connection rows, and the shared-recipes sheet).

The sync card reuses the loading, error, and cooldown-card patterns from M3/M4 with the botanical marker and live-region progress. Coverage copy identifies the analyzed collection and never equates completed A–Z browse with full-catalog completeness. See [CONSTELLATION.md](CONSTELLATION.md) for the storage and graph contracts.

## M4 feature application

The bar screen reuses the discovery shell, cards, sheet, and state primitives — no new palette, fonts, or shapes. The scope card states the matching boundary in words before any result appears; the selection card holds removable checked chips plus the picker sheet, whose option rows are native checkbox tiles with 48-pixel rows and announced shown/total counts. Matching progress is the static botanical loading marker with a live-region "Checking recipes… X of Y"; a pause reuses the M3 cooldown card with its countdown. Results keep the asymmetric recipe card and add a status line whose meaning is carried by an icon and text together, never color alone: ready, possible-with-substitution (each suggestion spelled out and labeled as reviewed), or missing essentials with the missing list inline and the group sorted by fewest missing. Garnish exclusions are noted per card in small text. Group headings are semantic headers; the completion summary is announced through a live region, and the coverage footnote ("not the full cocktail catalog") is always visible on the page. Readability at 320 logical pixels with 1× and 2× text and reduced motion is tested. See [BAR.md](BAR.md) for the flow contract.
