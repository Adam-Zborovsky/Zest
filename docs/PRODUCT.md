# Zest product brief

## Status

Zest is a Flutter cocktail companion planned for personal use; open-source publication remains an open decision. It has a Botanical Play design system, tested TheCocktailDB data layer, discovery/recipe-detail interface with generated Android and web wrappers, and "what can I make" bar matching over the chosen discovery results. The starter app was built and run on the development PC (Adam confirmed the run on 2026-09-10). Discovery supports name and ingredient searches, first-letter browsing, returned-result lists, full recipe detail and source attribution. Bar matching (M4) offers a session-only ingredient selection with no pantry setup, runs in explicit batches of ten lookups through the shared cache and cooldown, and sorts the chosen results into ready, substitution-possible, and missing-essentials groups using reviewed garnish and substitution tables; it never modifies source recipes. Source-preserving models, conservative ingredient identities and memory-only response caching underpin these flows. The temporary design gallery requires explicit debug opt-in. Milestone verification is recorded separately in `docs/VERIFICATION.md`. There is **no** login, onboarding, Ingredient Constellation, saved recipes, personal variations, photo handling, persistent recipe storage, pantry persistence, or authentication. Gallery interactions remain temporary specimens, not saved-product features.

Development and execution happen on the development PC, where the Flutter SDK is installed. Run all Flutter commands from `frontend/`.

## Confirmed product direction

- **Recipe gateway decision (2026-09-12):** Adam purchased premium access and reports confirming the provider terms. A local Node/TypeScript/Fastify gateway is authorized before M5 to hold the paid key, forward allowlisted recipe requests and share bounded memory caching/cooldowns. Flutter keeps its local matching and future drift/graph work. No deployment configuration, backend database, authentication or accounts are included; M7 still gates auth. See [GATEWAY.md](GATEWAY.md).
- **M5 direction confirmed:** the constellation will lead home, over an on-device source-preserving recipe collection; drift is authorized early from M6. Catalog sync, graph and performance verification are separate work after the gateway prerequisite, not implemented by it. A paid key does not itself verify a particular full-catalog retrieval contract.

- **Name and source:** The product is Zest; its Dart package name is `zest`. TheCocktailDB is the recipe source; the M2 integration contract is documented in `docs/DATA.md`.
- **Purpose:** Combine discovery, ingredient matching, guided making, saved recipes, and personal variations. Home-bar, shopping, and hosting features are later possibilities, not current implementation scope.
- **Visual direction:** Adam selected **C — Botanical Play**: leafy greens, soft shapes, and cut-paper garnish. Fraunces headings, DM Sans body text, and the palette and component rules in `docs/DESIGN.md` establish the foundation. Expressive visual flair is a first-class, app-wide requirement. It must carry through discovery, recipes, making, collections, secondary, and empty states—not be isolated to a single showcase.
- **Accessibility:** Preserve readable content, direct access to core tasks, reduced-motion equivalents, and a logical screen-reader experience. Constant motion is not a requirement.

## Ingredient Constellation

The flagship exploration concept is an interactive ingredient co-occurrence graph derived from a clearly identified recipe collection. It is a proposal, not a data set or implemented feature.

- Nodes represent normalized ingredients; node size reflects the number of distinct recipes in the analyzed collection containing that ingredient.
- An edge represents ingredients appearing together; edge weight reflects their shared recipe count.
- Start with a bounded subset of frequent ingredients and strong connections, with filtering and focus rather than an unreadable full graph.
- Selecting an ingredient emphasizes its neighborhood; selecting a connection may reveal associated recipes.
- Label the collection and coverage. Counts are collection prevalence, not real-world popularity, taste compatibility, or personal consumption.
- Ingredient aliases and duplicate records require handling before meaningful counts. Do not invent flavor relationships or numeric claims.
- Offer a static/reduced-motion view and a textual route to related ingredients and recipes. Core tasks must not depend on the graph.
- Motion and spatial exploration may be playful in their own right; not every visual interaction needs to open a recipe or complete a task.

## Collection and private photo

A saved recipe or personal variation supports one optional personal photo of the drink or occasion for private archiving. The image remains distinct from a recipe-source reference image and does not alter source content. The intended experience allows an image to be chosen while saving or editing, replaced, or removed; no-photo entries remain intentionally designed. Personal media must stay private and outside the public repository. This does not authorize a public feed, cloud upload, multi-photo gallery, repeated-occasion journal, or consumption tracking.

Media storage, permissions, backup, and export are unresolved and unimplemented.

## Onboarding and login

Onboarding is planned as a rich, swipeable introduction with light animation, visible progress, explicit Next/Back controls, and reachable Skip. It ends at an actual login page; Skip goes to login and does not bypass authentication. There are no automatic advances or waits for animation completion.

The selected art direction uses animated versions of actual interface components, supported by a small illustrated character. The interface leads; the character is a supporting presence. A proposed sequence introduces constellation exploration, available-ingredient discovery, making a personal variation, saving one illustrative personal photo, and login. Examples are demonstrations only and must not imply account sync, backup, cloud photo storage, or personalized recommendations.

The planned behavior persists onboarding completion/skip state: signed-in returning users go to the app; signed-out returning users go directly to login; a settings replay may be added later. Do not request camera or photo permission during onboarding—only when adding a photo.

Authentication provider, guest access, account requirements, storage, and sync benefits are open decisions. No login UI or authentication is implemented now.

## Source and publication boundary

TheCocktailDB remains the chosen dependency, but a development/education test key and a future public-app release do not grant rights to redistribute provider data or photos. Only the explicitly allowed public test key `1` is included in code; no private API key, database dump, source image, public binary distribution, or content license grant belongs in this repository. Confirm provider terms and distribution rights when a publication method is chosen. Future app-code licensing remains separate from upstream content rights.

## Open decisions

- Constellation placement is resolved as home-first for M5. Its relationship to the label system remains open.
- M4 remains client-side matching within chosen discovery results. M5 is approved for an on-device collection and resumable letter sync; exact catalog completeness must be verified, not inferred from premium access. Publication/distribution remains separate from Adam's reported confirmation of provider terms for this development.
- Initial mobile targets and eventual distribution method.
- Authentication, guest access, storage, and synchronization.
- Media storage, backup/export, and permissions.
- Pantry persistence: M4 selections are session-only by design; making them durable belongs to the M6 storage milestone's decisions.
