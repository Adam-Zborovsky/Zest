# Ingredient Constellation — M5

The M5 flagship: an on-device, source-preserving recipe catalog with resumable A–Z sync, and the ingredient co-occurrence constellation that leads the home screen. The gateway prerequisite ([GATEWAY.md](GATEWAY.md)) supplies provider access; storage, sync, graph and matching remain client-side. The data-layer contract history is in [DATA.md](DATA.md).

## Catalog storage

`frontend/lib/features/catalog/` holds a drift (SQLite) database opened through the documented cross-platform connection: a native file database on devices, `WasmDatabase` on web with the pinned `sqlite3.wasm` and drift worker committed to `frontend/web/` (provenance and SHA-256 in `frontend/web/README.md`). Tests inject in-memory or temp-file executors.

| Table | Contents |
| --- | --- |
| `recipes` | One row per recipe: `providerId` (TEXT primary key — the provider id is an opaque numeric string up to 20 digits, preserved byte-for-byte), `name`, `firstLetter`, and the full source JSON. `firstLetter` records the browse that last wrote the row, not a name-derived letter; cross-letter shared recipes are last-writer-wins and cannot duplicate usages. |
| `ingredient_usages` | One row per (recipe, normalized ingredient identity) — the prevalence basis. Written at upsert time via the reviewed alias normalization. |
| `letter_sync` | One row per fully applied letter; absence means pending. No status column — completion is row presence. |

Writes are transactional per letter: a letter's recipes, usages and completion row apply together or not at all. Re-syncing a letter replaces its stale rows without touching other letters. Reads rehydrate `Recipe` objects from the stored source JSON and round-trip exactly; `ingredientPrevalence()` and `coverage()` feed the constellation.

## Sync

The sync engine walks pending letters a–z through the shared request-gateway cooldown (`letterRecipes()` — an additive method on `CocktailRequestGateway`; there is no second cooldown). Letters apply transactionally, so progress is durable: a fresh session resumes from the store's pending letters, never re-requesting synced ones. Rapid `start()` calls are settled by a run token that abandons the losing loop without corrupting partial state.

Behavior contract:

- Pacing: a conservative pause between letter browses (injectable; tests run at zero).
- A provider rate limit pauses with the reported remaining seconds; other errors pause resumably. There is **no automatic retry** — resume is always explicit.
- Store failures during start/resume land in the same resumable paused state instead of escaping as unhandled exceptions.
- Coverage counts loaded letters and recipes. Completed A–Z browse is **not** proof of full-catalog completeness, and no surface claims it is.

## Constellation

`frontend/lib/features/constellation/` computes the graph client-side from the stored catalog:

- Nodes are normalized ingredient identities; a recipe contributes an identity at most once. Node prevalence is the distinct-recipe count within the analyzed collection.
- Edges are identity pairs sharing at least one recipe; edge weight is the shared-recipe count.
- The default bounded view keeps the **top 40** nodes by prevalence (alphabetical tie-breaks, deterministic); only edges among kept nodes survive. `totalIdentityCount` preserves the pre-bound identity total so count lines can disclose the bound honestly.
- The layout is a seeded force simulation (fixed seed, 300 iterations, linear cooling) that always produces identical positions for an identical graph.

Home (`/`) leads with the canvas. Node taps select and highlight a neighborhood with a prevalence phrase tied to the analyzed collection; edge taps open a sheet of shared recipes linking to the existing detail route; a search filter narrows visible nodes. The canvas settles once with the standard ease-out entrance token and then stays still. A semantic list view carries the same prevalence and connection information without the graph; the canvas itself is excluded from semantics. Under either reduced-motion flag no animation controller exists and the final layout renders immediately. Core tasks never depend on the graph: discovery and bar routes are unchanged and directly reachable.

Coverage wording everywhere identifies the analyzed collection (letters loaded, recipe count) and states that counts describe the loaded collection, not the full provider catalog.

## Platform and verification notes

- Windows host tests (`flutter test`) require a 64-bit `sqlite3.dll` on PATH — drift's documented requirement; `sqlite3_flutter_libs` covers built apps only. One-time setup: install SQLite on PATH (e.g. `choco install sqlite`) or place the official x64 DLL in a PATH directory.
- Web WASM runtime behavior (browser IndexedDB/OPFS) compiled and builds but has no automated coverage; tests exercise native executors.
- Verification history: [VERIFICATION.md](VERIFICATION.md); independent review: [reviews/M5.md](reviews/M5.md).
