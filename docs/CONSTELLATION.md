# Ingredient Constellation — M5 / M11

The M5 flagship: an on-device recipe catalog and the ingredient co-occurrence constellation that leads the home screen. M11 replaced the client-driven A–Z browse with a single shared catalog snapshot downloaded from the backend (`docs/M11.md`); storage, update behavior, graph and matching remain client-side. The data-layer contract history is in [DATA.md](DATA.md).

## Catalog storage (schema 2)

`frontend/lib/features/catalog/` holds a drift (SQLite) database opened through the documented cross-platform connection: a native file database on devices, `WasmDatabase` on web with the pinned `sqlite3.wasm` and drift worker committed to `frontend/web/` (provenance and SHA-256 in `frontend/web/README.md`). Tests inject in-memory or temp-file executors.

| Table | Contents |
| --- | --- |
| `recipes` | One row per recipe: `providerId` (TEXT primary key — the provider id is an opaque numeric string up to 20 digits, preserved byte-for-byte), `name`, and the full source JSON. |
| `ingredient_usages` | One row per (recipe, normalized ingredient identity) — the prevalence basis. Written whenever a snapshot is applied, via the reviewed alias normalization. |
| `catalog_snapshot` | Single row (id 1): `version` (64 lowercase hex, the SHA-256 of the canonical snapshot body), `publishedAt`, `recipeCount`, `appliedAt`. Absence means no snapshot has ever been applied. |

The migration from schema 1 drops and recreates all three catalog tables — the catalog is re-downloadable provider data, not personal data, so schema-1 rows are never carried forward. `CatalogRepository.applySnapshot(CatalogSnapshot)` replaces `recipes`, `ingredient_usages`, and the `catalog_snapshot` row in one transaction, returning a `CatalogDiff` (added/removed/changed counts, plus added recipe names for the update notice); a failure partway through leaves the previous catalog completely intact. Reads rehydrate `Recipe` objects from the stored source JSON and round-trip exactly; `ingredientPrevalence()` and `coverage()` feed the constellation.

## Update behavior

`CatalogSnapshotClient` (`catalog/data/catalog_snapshot_client.dart`) does a conditional `GET` against the backend's `/api/catalog` (resolved from `ZEST_API_BASE_URL` the same way the account/sync base is, via `resolveCatalogSnapshotUrl`), sending `If-None-Match` with the locally applied version. It validates the envelope and every drink record (64-hex version, `recipeCount == drinks.length`, numeric `idDrink`, non-empty `strDrink`, every `str*` field string-or-null, no duplicate ids) before ever handing back a `CatalogSnapshot`; invalid, oversized (>8 MB decompressed), rate-limited, unavailable, offline, or timed-out responses all surface as typed `CocktailApiException`s, never a partial snapshot.

`CatalogUpdateController` (Riverpod `Notifier`, `catalog/application/catalog_update_controller.dart`) drives the whole lifecycle per the states `idle`, `checking`, `downloading`, `upToDate`, `updated`, `staged`, `failed`:

| Moment | Behavior |
| --- | --- |
| Launch, empty catalog | `checkOnLaunch()` downloads and applies automatically; the home card shows progress in place of a manual action, and a failure there shows the branded error with Retry. |
| Launch, catalog exists | The same `checkOnLaunch()` checks in the background; a new version is downloaded and applied automatically, then a notice reports the measured diff ("Catalog updated · N new recipes"). |
| App resumed 6+ hours after the last check | `checkAfterResume()` checks and downloads, but **stages** rather than applies a found update, and the notice carries an **Update** action; tapping calls `applyStaged()`, otherwise the next full launch re-downloads and applies it automatically. |
| Manual | `checkNow()` (the profile sheet's "Check for catalog updates" row) always applies immediately, returning a `CatalogUpdateOutcome` (`CatalogUpdateUpToDate` / `CatalogUpdateApplied` / `CatalogUpdateStaged` / `CatalogUpdateFailed`) for that row's own inline wording. |
| 304 / identical version, or any failure with an existing catalog | Silent: no notice, and (fpr a failure) the previous catalog keeps working; only the profile sheet's own status reflects it. |

A run token (`_run`) makes concurrent triggers coalesce into the one in-flight run and lets a stale run — abandoned when a watched dependency rebuilds the controller — return without ever overwriting fresher state; there is no automatic retry loop. After every apply, `catalogFreshnessProvider` (constellation) and `homeBarCatalogFreshnessProvider` (home bar) invalidate the providers that read the catalog, so both screens refresh. The update notice itself is `ZestNotice` (`core/widgets/zest_notice.dart`): a dismissable, screen-reader-announced Botanical Play card shown via the nearest `Overlay`, with a keyboard-reachable action and no animation under reduced motion.

## Constellation

`frontend/lib/features/constellation/` computes the graph client-side from the stored catalog:

- Nodes are normalized ingredient identities; a recipe contributes an identity at most once. Node prevalence is the distinct-recipe count within the analyzed collection.
- Edges are identity pairs sharing at least one recipe; edge weight is the shared-recipe count.
- The default bounded view keeps the **top 40** nodes by prevalence (alphabetical tie-breaks, deterministic); only edges among kept nodes survive. `totalIdentityCount` preserves the pre-bound identity total so count lines can disclose the bound honestly.
- Glyph groups come from `ingredientKindOf` in `constellation/domain/ingredient_kind.dart`: whole-word matching applied in a fixed order (liqueurs and bitters, spirits, mixers to the neutral group, citrus, sweeteners, herbs and spice). It is a display grouping only, never flavor or compatibility, and unrecognized names stay in the neutral group. See the Night Garden section of [DESIGN.md](DESIGN.md).
- The layout is a seeded force simulation (fixed seed, 300 iterations, linear cooling) that always produces identical positions for an identical graph. It starts from a golden-angle spiral over an ellipse filling the canvas, scales edge springs down by the graph's mean degree so a nearly fully connected top-40 set cannot collapse into the center, adds a gentle elliptical pull toward the center so repulsion does not press the outer ring flat against the walls, stretches the settled shape to span the canvas on both axes within an 18-pixel margin, and finishes with at most 120 collision rounds that keep every pair of discs apart by their painted radii plus an 8-pixel gap. Regression tests cover a dense synthetic collection on desktop and phone canvas sizes.

Home (`/`) leads with the canvas. Node taps select and highlight a neighborhood with a prevalence phrase tied to the analyzed collection; edge taps open a sheet of shared recipes linking to the existing detail route; a search filter narrows visible nodes. The canvas settles once with the standard ease-out entrance token and then stays still. A semantic list view carries the same prevalence and connection information without the graph; the canvas itself is excluded from semantics. Under either reduced-motion flag no animation controller exists and the final layout renders immediately. Core tasks never depend on the graph: discovery and bar routes are unchanged and directly reachable.

Coverage wording everywhere identifies the source and recency ("TheCocktailDB catalog, N recipes, updated <date>") and states that counts describe the downloaded catalog, not a proven-complete provider dump.

## Platform and verification notes

- Windows host tests (`flutter test`) require a 64-bit `sqlite3.dll` on PATH — drift's documented requirement; `sqlite3_flutter_libs` covers built apps only. One-time setup: install SQLite on PATH (e.g. `choco install sqlite`) or place the official x64 DLL in a PATH directory.
- Web WASM runtime behavior (browser IndexedDB/OPFS) compiled and builds but has no automated coverage; tests exercise native executors.
- Verification history: [VERIFICATION.md](VERIFICATION.md); independent review: [reviews/M5.md](reviews/M5.md).
