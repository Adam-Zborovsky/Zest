# M4 bar-matching contract

"What can I make?" matches a user-selected ingredient shelf against a chosen set of discovery results. It does not search or claim the provider's whole catalog, and it never modifies source recipes. This document records the flow decisions; the classification tables and endpoint behavior live in [DATA.md](DATA.md), and visual application in [DESIGN.md](DESIGN.md).

## Coverage decision

The provider reserves multi-ingredient filtering (`filter.php?i=A,B,C`) for premium keys; Zest uses the documented public test key. Matching therefore runs **client-side against the discovery results the user chose**: the preview on `/discover` and the full-results screen each offer "What can I make from these results?", which records the current result set as the match scope and opens `/bar`.

The bar screen labels the scope ("Recipes for “gin”", with its recipe count), states that matches cover these results and not the full cocktail catalog, and shows checked/total counts while recipes are examined. A direct `/bar` visit with no scope shows a designed empty state linking back to discovery. Catalog-wide matching remains unimplemented and would require a premium key or an ingestion decision.

## Selection

- The ingredient options come from the provider's ingredient list endpoint (`list.php?i=list`), cached like every other response. Nothing is preselected; there is no mandatory pantry setup and no assumed staples — **unselected is not available**.
- Selection is session-only memory state: it does not survive restart and is not persisted. Persistence belongs to a later milestone decision.
- Identities use the same normalization as recipe ingredients (see [DATA.md](DATA.md)), so a selected "Dark rums" covers a recipe's "Dark Rum" while rum types stay distinct.
- The picker sheet supports search, announces the shown/total counts, and toggles immediately; selected ingredients appear as removable chips on the bar screen. "Find matches" stays disabled, with a visible explanation, until at least one ingredient is selected.

## Matching runs

- A run fetches any recipe details missing from the cache in **explicit batches of ten lookups**, awaiting each batch before starting the next, through the same shared rate-limit gateway and response cache as discovery. Progress is visible as "Checking recipes… X of Y" with a live-region announcement; partial matches render as each batch lands.
- A rate limit or network failure **pauses** the run: partial matches stay on screen, the shared cooldown is surfaced with its countdown, and "Try again" resumes from the last checked recipe rather than restarting.
- A lookup that returns no recipe counts as checked and is reported separately ("could not be opened from the source"), never as a match.
- Changing the selection or the scope invalidates any finished or paused run; an in-flight run is abandoned by the same mechanism.
- Results group into **Ready to make**, **Possible with a substitution**, and **Missing essentials** (sorted by fewest missing). Substitution suggestions and "garnish not counted" notes are shown per recipe, clearly labeled as reviewed suggestions rather than identity merges. Every result links to the unchanged source recipe detail.

## Feature coupling

Bar matching imports the discovery feature's data client, request gateway, and shared presentation widgets (`DiscoveryFrame`, `DiscoveryHeading`, `DiscoveryFailure`). `openBarMatching` in `features/bar/presentation/bar_widgets.dart` is the single entry point discovery screens call, keeping scope-state ownership inside the bar feature. A future third consumer should prompt extracting the shared shell into `core/`; that refactor was deliberately not taken in M4 to avoid reworking reviewed M3 structure.

## Tests

From `frontend/`: `flutter analyze`, `flutter test`. Bar coverage includes classifier unit tests (empty/partial selection, distinct names, aliases, deduplicated slots, every garnish form, substitution directions and limits, zero-ingredient recipes), provider tests (batching counts, pause/resume with the shared cooldown, unavailable lookups, selection/scope resets), and widget tests (empty-scope state, picker search and toggles, the three result buckets with substitution and garnish copy, cooldown pause and resume, detail round trip, keyboard-only picker access, and 320-pixel readability at 1× and 2× with reduced motion). Fixtures are invented records; no provider content is a test asset.
