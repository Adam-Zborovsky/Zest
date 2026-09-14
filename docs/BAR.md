# Bar matching and persistent home bar (M4 + M10)

Zest matches the person's persistent stocked ingredients against either a chosen set of discovery results or every full recipe currently stored in the on-device catalog. It never modifies source recipes or claims coverage beyond the measured local collection. This document records the matching flow; the classification tables live in [DATA.md](DATA.md), the M10 persistence and sync contract in [M10.md](M10.md), and visual application in [DESIGN.md](DESIGN.md).

## Coverage decision

The provider reserves multi-ingredient filtering (`filter.php?i=A,B,C`) for premium keys; Zest therefore keeps matching client-side. The preview on `/discover` and the full-results screen each offer "What can I make from these results?", which records the current result set as the match scope and opens `/bar`. That scope remains explicit and bounded.

M10 adds a second, direct path: `/bar` without a discovery scope matches every full recipe already stored by the resumable A–Z catalog sync. The screen displays the stored recipe count and completed-letter coverage and says that this is a local collection, not the full provider catalog. `/bar/shopping` is a real route for the shopping list. Scoped matching still labels its chosen result set and shows checked/total progress while missing details are fetched.

## Inventory and shopping

- Ingredient choices are derived from the on-device recipe catalog. M10 does not create free-form identities that cannot match a stored recipe.
- One durable row per normalized identity is either `stocked` or `shopping`; it cannot appear in both. No quantity, brand, price, expiry, or assumed staple is stored. **Not stocked is not available.**
- Identities use the same normalization as recipe ingredients (see [DATA.md](DATA.md)), so stocked "Dark rums" covers a recipe's "Dark Rum" while rum types stay distinct.
- Adding an existing identity is idempotent. Moving it between the shelf and shopping is one write. Removing creates a syncable tombstone; a later explicit add can restore it.
- Recipe and match actions add only missing essentials to shopping. Optional garnishes are excluded, and a reviewed substitution remains advice rather than an automatic replacement.
- The catalog picker supports search and announces shown/total counts. The shelf and shopping list expose visible, labeled move and remove actions.

## Matching runs

- A run fetches any recipe details missing from the cache in **explicit batches of ten lookups**, awaiting each batch before starting the next, through the same shared rate-limit gateway and response cache as discovery. Progress is visible as "Checking recipes… X of Y" with a live-region announcement; partial matches render as each batch lands.
- A rate limit or network failure **pauses** the run: partial matches stay on screen, the shared cooldown is surfaced with its countdown, and "Try again" resumes from the last checked recipe rather than restarting.
- A lookup that returns no recipe counts as checked and is reported separately ("could not be opened from the source"), never as a match.
- Changing stocked inventory or the scope invalidates any finished or paused scoped run; an in-flight run is abandoned by the same mechanism.
- Results group into **Ready to make**, **Possible with a substitution**, and **Missing essentials** (sorted by fewest missing). Substitution suggestions and "garnish not counted" notes are shown per recipe, clearly labeled as reviewed suggestions rather than identity merges. Every result links to the unchanged source recipe detail.

## Feature coupling

Scoped bar matching imports the discovery request gateway and shared presentation widgets (`DiscoveryFrame`, `DiscoveryHeading`, `DiscoveryFailure`). `openBarMatching` in `features/bar/presentation/bar_widgets.dart` remains the discovery entry point and keeps scope-state ownership inside the bar feature. Direct home-bar matching reads the catalog repository and persistent home-bar providers. Both paths use the same classifier and normalized identities.

## Tests

From `frontend/`: `flutter analyze`, `flutter test`. Coverage includes classifier tests; scoped batching, pause/resume, cancellation, unavailable lookups, inventory/scope resets, and detail round-trips; Drift migration and local-write tests; sync ownership, paging, conflicts, ties, restoration, offline, and expired-session tests; and widget tests for both routes, picker search, move/remove actions, missing-essential shopping, keyboard operation, semantics, reviewed goldens, and 320-pixel readability at 2× text. Backend tests cover authentication, user isolation, validation, independent revisions, paging, last-edit-wins, tombstones, and restoration. Fixtures are invented records; no provider content is a test asset.
