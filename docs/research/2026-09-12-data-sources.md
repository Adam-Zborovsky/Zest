# Data-source research — 2026-09-12

Research for the open decisions on recipe coverage and eventual publication: how much data TheCocktailDB actually holds, whether a comparable source exists, and whether an equivalent dataset could be recreated. Requested by Adam after the M4 closeout. No provider data was saved or copied; only public counts and license terms were collected.

## How big TheCocktailDB actually is

The provider's own homepage states **636 total drinks, 489 ingredients, 636 drink images**. Premium access is a one-off $10 lifetime key that unlocks multi-ingredient filtering, popular/latest lists, and "full database listing" endpoints. The database is crowd-sourced and dates to 2015.

Practical implication for Zest: `search.php?f=<letter>` — already wired and tested in our M2 client — returns **full recipe records** on the free test key. The entire catalog is therefore retrievable in roughly 26 letter requests. With the existing batching, cooldown, and cache discipline, a catalog-wide analyzed collection is feasible inside the running app without premium access, while still never redistributing provider content. This re-opens the M5 "analyzed collection" choice beyond per-search scopes.

## Comparable sources checked

| Source | Size | Access | Data license | Verdict |
|---|---|---|---|---|
| TheCocktailDB | 636 drinks, 489 ingredients | Free test key; $10 lifetime premium | Provider terms (ambiguous page); our policy is stricter: no redistribution | Current source; stays for runtime |
| CocktailFYI (cocktailfyi.com) | 636 cocktails, 300+ ingredients | Free REST API, no auth, CORS, OpenAPI spec | None stated for the data (© site; MIT covers the Python engine only) | Closest peer in coverage and structure (adds ABV/calories/families), but reuse rights unstated — not a redistribution-safe source without permission |
| cocktail.glass (jdevalk) | 500 recipes | Free; whole catalogue as JSON, MCP server, no key | **Code MIT; data © all rights reserved, "may not be copied or republished"** | Machine-readable but explicitly non-reusable data |
| opendrinks (alfg, MIT) | ~757 recipe JSON files | GitHub, no key | MIT including contributed recipes | The one genuinely reusable dataset; skews heavily to smoothies/lassis/non-alcoholic drinks, uneven structure, no consistent images |
| IBA cocktail datasets (teijo, lmc2179) | ~100 official IBA recipes | GitHub JSON | None stated; IBA asserts rights over its official list | Small and rights-ambiguous |
| API Ninjas, APIVerve, Solvro, carlagesa/CocktailDB | Various | Mostly key-gated or recruitment/demo projects | Proprietary, or **populated by scraping TheCocktailDB** (the redistribution problem inherited, not solved) | Not improvements |

**Conclusion:** nothing is "as good" for Zest's purposes. TheCocktailDB remains the best free structured cocktail source; the only cleanly licensed alternative (opendrinks) is broader but thinner, and every other candidate either restricts its data or is itself derived from TheCocktailDB.

## Could we recreate it?

- **Inside the app (runtime): effectively yes, without recreating anything.** As above, ~26 polite letter-browse requests load the full 636-drink catalog into the client cache. The app never redistributes it, which is the boundary our terms policy actually draws.
- **As an open dataset (for publication): possible, but it is a content project, not a coding task.** A legally clean rebuild would transcribe recipes from public-domain bar books (everything published through 1930 is US public domain as of 2026 — Jerry Thomas 1862, Harry Johnson, Boothby, the 1930 Savoy), merge the MIT-licensed opendrinks contributions, normalize names against our reviewed identity table, and create original artwork (Botanical Play illustrations would replace provider photography, which is itself a licensing win). Hundreds of recipes × measures, instructions, and review is a multi-week editorial effort with provenance tracking per recipe.

## Recommendation

1. Keep TheCocktailDB as the runtime source; treat CocktailFYI as a possible enrichment reference only if its data licensing is ever clarified in writing.
2. For M5, consider making the analyzed collection the full catalog loaded via letter-browse batching (labeled as "TheCocktailDB collection, 636 recipes") instead of per-search scopes — decide in the M5 plan.
3. Defer any open-dataset rebuild until the publication decision (post-M7); if that decision lands, the public-domain + MIT + original-art path above is the route, tracked as its own project.

Sources consulted 2026-09-12: thecocktaildb.com (homepage counts, API/documentation pages), cocktailfyi.com/developers, github.com/jdevalk/cocktail.glass, github.com/alfg/opendrinks (+ GitHub contents API count: 757 recipe files), github.com/teijo/iba-cocktails, api-ninjas.com/api/cocktail, and the Solvro/carlagesa/APIVerve project pages.
