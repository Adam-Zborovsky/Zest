# M3 — Discovery and recipe detail

Discovery is now the normal launch screen, using the approved Botanical Play design. This milestone consumes the M2 client directly from the app; it adds no backend, ingestion job, account, matching logic or saved collection.

## Flow and coverage

- Submit a cocktail name or ingredient name; merely typing does not call the service. An empty submission gives a labelled field error and returns focus to the field.
- Expand **Browse A–Z** and select a letter to request that letter's results. Ingredient browsing is a free-text filter, not a claimed complete ingredient catalog.
- Preview up to six returned recipes. **See all N results** opens a lazily built list of that response, not a full-database crawl or invented pagination. Detail lookup supplies full recipes for ingredient-filter summaries.
- Detail displays the source image when available, original ingredient names and readable source measures, glass/category/alcoholic metadata, and instructions. Instruction paragraphs are numbered without splitting sentences or abbreviations; existing source numbering is kept. Missing fields have explicit fallbacks, not inferred quantities or instructions.
- **Open source recipe** opens the canonical TheCocktailDB detail URL. Original attribution notices remain visible. Launch failure offers the selectable URL. No arbitrary provider text is interpreted as executable markup or an external-launch target.

## Routes and state

| Route | Meaning |
| --- | --- |
| `/discover` | Idle discovery; no recipe request |
| `/discover?mode=name&q=…` | Name results |
| `/discover?mode=ingredient&q=…` | Ingredient-filter results |
| `/discover?mode=letter&q=a` | First-letter results |
| `/discover/results?mode=…&q=…` | All results returned for the current query |
| `/discover/recipe/ID` | Direct recipe lookup |

Result/detail navigation preserves query parameters. In-app Back returns to the originating list and keeps the query; direct detail links have a discovery parent. Invalid IDs, malformed/duplicate query parameters and unknown pages receive branded recovery screens. `go_router` reflects pushed detail routes in the web URL; these URLs are independently reconstructible. Hosting still needs normal Flutter web configuration; real browser history and deployment rewrites are separate from widget navigation tests.

`DiscoveryQuery` is a normalized, value-equal provider-family key. Different queries have separate asynchronous states, so a slow older response cannot replace the current query. Auto-disposed query/detail providers do not close the app-scoped client. The client is closed when its owning provider scope is disposed.

Riverpod's implicit retry is explicitly disabled. M2 remains the authority for TTL/LRU response caching and in-flight deduplication. A shared request gateway respects 429 cooldowns across queries and detail requests. Missing Retry-After seconds uses a conservative 30-second fallback; overlapping failures preserve the longest deadline. Errors carry that absolute deadline so the UI does not restart the wait on remount or count only foreground timer ticks. The countdown does not auto-submit or announce every second; retry remains an explicit action.

## Accessibility and source images

The existing semantic colors, type roles, soft card shapes, 48-pixel targets and original painted garnish are reused. Search fields have accessible names and validation, recipe buttons include their recipe name, and result/loading/empty/error outcomes expose live-region status. Actions are outside the live-region outcomes. Focus remains inside the route after submission; mode changes and navigation do not discard the draft or routed query.

Routes use a short opacity transition, removed when either system reduced-motion flag is active. There are no decorative loading loops or forced waits. Text is not clamped; controls and captions grow and content scrolls. Tests load the bundled fonts and exercise 320-pixel layouts at 1×, 2× and 3×.

Recipe images accept HTTPS references without embedded credentials. They load at runtime via Flutter's image provider; no provider assets are bundled. Loading, absent and failed images show original botanical artwork and an explicit caption, not a false attribution for that artwork. Captions sit outside the fixed image region so large text remains readable. The all-results list only constructs cards as needed; the six-result preview is deliberately bounded. Flutter/platform memory and HTTP caches may apply; M3 introduces no app-managed disk image store.

## Dependencies and implementation choices

- `go_router` 18.0.1 and `flutter_riverpod` 3.4.3 implement the agreed navigation/state stack, without code generation.
- `url_launcher` 6.3.2 is the one addition outside the default stack. Its reason was stated before implementation: actionable provider attribution in the system browser across mobile and web. It is called directly on user activation, handles failure, and needs no speculative `canLaunchUrl` manifest queries.
- Existing generated Android/web wrappers remain. No SDK upgrade, backend scaffold, secrets file, personal photo or provider fixture was introduced.

The composed-skills path was approved instead of new Stitch generation: frontend-design kept the established Botanical Play direction; design-system reused semantic roles; accessibility guided focus, semantics and text-scaling checks. Architecture and design remained in the main thread. Terra handled the state layer and additional edge tests, with separate read-only review.

## Demo

From `frontend/`, `flutter test test/features/discovery/presentation` runs the synthetic flow and rendered demos without network calls. The reviewed renders are:

- [Discovery](../frontend/test/features/discovery/presentation/goldens/discovery-mobile.png)
- [Search results](../frontend/test/features/discovery/presentation/goldens/discovery-results.png)
- [Recipe detail](../frontend/test/features/discovery/presentation/goldens/recipe-detail.png)

For manual exploration on the development PC, follow [gateway setup](../backend/README.md), run `npm run dev` from `backend/`, then `flutter run -d chrome --web-port=5173` from `frontend/`. Search, open all results when offered, open a recipe, use Back, browse a letter and follow source attribution. Recipe calls go through the local gateway, which holds the provider key; source images/links remain direct. These commands are for Adam to run; the agent did not launch a server/watcher.

The M1 gallery now requires explicit debug opt-in: `flutter run -d chrome --dart-define=ZEST_DESIGN_GALLERY=true`. Release builds ignore that gallery request. Authentication remains undecided; Adam subsequently approved graph-first home for M5, which is not implemented by this gateway increment.

## Official references consulted

- [go_router configuration](https://pub.dev/documentation/go_router/latest/topics/Configuration-topic.html) and [transitions](https://pub.dev/documentation/go_router/latest/topics/Transition%20animations-topic.html).
- [Riverpod 3 migration](https://riverpod.dev/docs/3.0_migration), including automatic retry changes.
- [url_launcher](https://pub.dev/packages/url_launcher), including user-initiated launching and failure handling.
- [Flutter network images](https://api.flutter.dev/flutter/widgets/Image/Image.network.html).

SDK/package APIs were checked against the versions installed on the development PC. See [VERIFICATION.md](VERIFICATION.md) for executed checks and their limits.
