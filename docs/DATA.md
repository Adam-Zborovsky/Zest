# M2 data contract

The data layer is ready for M3 to consume; it is not connected to the gallery or a discovery screen. No backend, bulk ingestion, persistence, provider content bundle, substitutions, or graph coverage decision is introduced here.

## Client

`frontend/lib/features/discovery/data/cocktail_db_client.dart` exposes:

| Method | V1 request | Result |
| --- | --- | --- |
| `searchByName(name)` | `search.php?s=…` | Immutable `List<Recipe>` |
| `browseByFirstLetter(letter)` | `search.php?f=…` | Immutable `List<Recipe>` |
| `filterByIngredient(name)` | `filter.php?i=…` | Immutable `List<RecipeSummary>` |
| `lookupRecipe(id)` | `lookup.php?i=…` | `Recipe?`; null means no match |

Queries are URL encoded and trimmed. First-letter browse accepts one ASCII letter; lookup accepts a numeric ID. Empty search/filter queries are rejected without a request. Filter summaries must be looked up before displaying a complete recipe. Nothing claims to represent the entire provider catalog.

The default host is HTTPS TheCocktailDB V1. The documented public development key `1` is the default. A build can override it with `--dart-define=COCKTAIL_DB_API_KEY=…`; never commit a private key, generated key file, or build artifact containing one. A client-side define is configuration, **not secret storage**: values can be extracted from a distributed app. Future distribution still requires Adam's licensing/key decision. The constructor also supports injected HTTP clients and keys for isolated tests.

`http` 1.6.0 is the only new direct dependency and belongs to the agreed stack. The client owns and closes only a transport it creates itself. Call `close()` when disposing the data layer; callers remain responsible for closing injected transports. Android's main manifest now includes Internet permission for release as well as debug networking.

## Caching and failures

- Per-client, memory-only cache: at most 64 successful responses, expiring 10 minutes after completion. Access updates least-recently-used eviction order, not the expiry time. Defaults are configurable for tests; zero TTL disables reuse.
- Identical concurrent requests share one in-flight operation. Valid no-match results are cached too. HTTP, transport, parsing and schema failures are never cached. There is no background prefetch, full-catalog crawl or automatic retry.
- Response bodies are limited to 2 MiB before JSON parsing; ingredient/result collections are immutable. The entry count bounds cache growth, but is not an exact byte cap on decoded Dart objects. Nothing persists to disk.
- A 10-second deadline covers request headers and body streaming. Timeout and close send an abort signal; built-in mobile/web transports support it. Late results cannot become successful cached entries. Injected transports should honor abort signals to release their own underlying resources.
- `CocktailApiException` distinguishes network, timeout, HTTP, rate-limited, invalid-response and closed-client failures. Exceptions never include raw request URLs, keys, response bodies or transport causes. Invalid caller input uses argument errors.
- HTTP 429 exposes status and a nonnegative integer-seconds `Retry-After`, when provided; HTTP-date values are currently left unspecified. No automatic retry occurs. A future UI must respect the supplied interval and must not retry in a tight loop. These defaults are Zest's conservative policy, not a claimed provider quota.
- Missing/wrong-shaped `drinks` envelopes and malformed records are errors, not empty successes. `drinks: null` and `drinks: []` are valid empty results. Unexpected redirects are not followed. A lookup returning multiple records or a different ID is rejected.

## Models and source preservation

`RecipeSummary` contains ID, name and optional thumbnail URL. `Recipe` adds original instructions, glass/category/alcoholic metadata, original source/image attribution fields and ordered ingredients. Full records must contain `strInstructions` and `strIngredient1` keys, although either value may be null. Null content is not invented. Both models expose a canonical provider detail link for M3 attribution.

Slots 1–15 are paired by index, including gaps; an ingredient at slot 15 is not paired with a measure from an earlier empty slot. `Ingredient` preserves its slot, raw name and raw measure. Its trimmed display name and normalized identity are separate from that raw source.

Round-tripping is semantic: supported metadata and **named ingredient pairs** survive `fromJson` → `toJson` → `fromJson`. Empty/unnamed slots (including orphan measures) and unknown provider fields are excluded. Serialization is not a lossless archive of every provider field. Instructions and recognized attribution notices are not rewritten. Image URLs are references only; no image downloads are part of M2.

`Measure` always retains its original nullable string. Positive integers, decimals, fractions, mixed fractions and common Unicode fractions are parsed when unambiguous. Recognized units include oz, ml, cl, l, tsp, tbsp, cup, dash, drop and part, plus the explicit singular/plural spellings in code. An amount without a unit remains unitless. No unit conversion occurs. Ranges, prose, unsupported units, malformed punctuation and invalid amounts remain unparsed; their original display text is still available. Parsing is not a claim about garnish optionality or pantry availability.

## Reviewed ingredient identities

All names receive lowercase, trim and repeated-whitespace collapse. Only these additional aliases are applied:

| Input identity | Canonical identity | Rationale |
| --- | --- | --- |
| dark rums | dark rum | Grammatical plural only |
| light rums | light rum | Grammatical plural only |
| white rums | white rum | Grammatical plural only |
| mint leaves | mint leaf | Grammatical plural only; not merged with generic mint |
| ice cubes | ice cube | Grammatical plural only; not merged with crushed ice |

Brand names remain distinct, as do dark/light/white/spiced rum, fruit/juice/peel/cordial, and sugar/syrup. Underscores are not removed from source identities merely because the API permits them in filter queries. The roadmap's brand-name example does not authorize guessed equivalence: ingredient classification/substitution needs separate reviewed evidence in M4. This deliberately small table was independently reviewed in M2; tests guard every alias and distinct-name example.

## Demo and tests

From `frontend/`:

```text
dart run tool/m2_demo.dart
dart run tool/m2_demo.dart --live
flutter analyze
flutter test
```

The default demo reads an authored synthetic fixture and makes **zero network calls**. It demonstrates parsing, normalization, gapped ingredient slots and a cache hit. `--live` opts into one public-key lookup repeated through the cache; it prints only decoding/cache status, never provider recipe content or request URLs, and writes no files. Ordinary tests never call the live service; their URLs use `example.invalid` and their recipes are invented.

## Official references checked 2026-09-11

- [TheCocktailDB API](https://www.thecocktaildb.com/api.php) — development key and endpoint/access distinctions.
- [Provider integration guide](https://www.thecocktaildb.com/AGENTS.md) — summary versus detail workflow, numbered slots, attribution and original measures.
- [Provider terms page](https://www.thecocktaildb.com/terms_of_use.php) — the page currently contains TheMealDB wording despite being linked by TheCocktailDB. This ambiguity does not broaden Zest's stricter no-redistribution policy; publication/licensing remains gated, not resolved by M2.
- [Dart HTTP package](https://pub.dev/packages/http) — injected clients, platform transports and abortable requests.
- [Flutter networking setup](https://docs.flutter.dev/cookbook/networking/fetch-data) — HTTP dependency and Android Internet permission.
