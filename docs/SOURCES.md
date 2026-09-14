# Sources and distribution rights

This is Zest's distribution-rights record for its one external data source,
TheCocktailDB. It quotes the published terms Zest relies on, maps Zest's
behavior against them, and records the risks Adam accepted when deciding to
make the repository public (2026-09-14). It is Zest's reading of the
published terms, not legal advice, and not a claim of legal permission.

The MIT license at `LICENSE` covers Zest's own code only; see `NOTICE.md` for
what it does not cover.

## Published terms (fetched 2026-09-14)

### `https://www.thecocktaildb.com/terms_of_use.php`

The page header reads "TheMealDB Terms of Service". TheCocktailDB is a sister
site to TheMealDB and links to this page as its own terms; the terms appear to
be shared across the sister sites rather than written per-site. This is
recorded as a fact, not resolved further.

Quoted:

> "You can scrape, copy and modify any content returned from the API, as long
> as you use the official end points. Please do not scrape our website."

> "You also cannot remove or alter any copyright or trademark notices."

> "You may use our API to lookup data and artwork for your development
> projects. You cannot publish apps to an appstore unless you are a paid
> subscriber."

> "You may use our API to develop apps and services as long as you stay
> within the rate limit."

> "You can use our custom artwork in your projects but must mention us as the
> source of the data."

> "Most of our artwork is custom and is created by our users, you must not
> pass it off as your own and should link back to our website where
> appropriate... You can check the 'strCreativeCommons' tag on artwork to
> make sure its CC licensed."

> "You cannot resell our API in any way without specific permission."

No clause on this page addresses caching or storing data.

### `https://www.thecocktaildb.com/api.php`

> "You can use the test API key "1" during development of your app or for
> educational use"

> "However you must sign up to Premium API for a small one-off fee if you
> want a production API key if releasing publicly on an appstore."

### `https://www.thecocktaildb.com/faq.php`

> "Are there any limits on the API?" — "No limits, the API is unlimited
> usage."

> "I'm have a commercial app, can I use the database?" — "Yes! But we expect
> you to sign up on Patreon. We are non-profit and all support goes towards
> the site."

The FAQ says nothing about open source, caching, or screenshots.

### Adam's status

Adam purchased Premium API access (recorded in `AGENTS.md` and
`docs/PRODUCT.md`). The paid key lives only in the backend's runtime
environment (`COCKTAIL_DB_API_KEY`) and is never committed; the repository
ships only the documented public test key `1` as a default. No email was sent
to TheCocktailDB requesting permission for repository publication — see
"Accepted risks" below.

## Zest's behavior against the published terms

| Zest behavior | Governing clause | Verdict |
| --- | --- | --- |
| Calling only the official API endpoints through the backend gateway (`docs/GATEWAY.md`) | "You can scrape, copy and modify any content returned from the API, as long as you use the official end points." | Within terms |
| The gateway's in-memory response cache (10-minute TTL, memory-only, never persisted; `docs/GATEWAY.md`) | No clause addresses caching or storing data | Not addressed by terms |
| The on-device A–Z catalog stored in drift, holding the verbatim source JSON (`docs/CONSTELLATION.md`) | No clause addresses caching or storing data | Not addressed by terms |
| Drink images loaded from TheCocktailDB URLs at runtime, never downloaded or bundled (`docs/GATEWAY.md`, `docs/DATA.md`) | "You can use our custom artwork in your projects but must mention us as the source of the data." | Within terms |
| The collection's stored source snapshot (`Recipe.toJson()`), synced to Zest's own server per user (`docs/ACCOUNTS.md`) | No clause addresses server-side storage of API-derived data | Not addressed by terms |
| Attribution shown in the app (canonical provider detail link on every recipe; `docs/DATA.md`) | "You must mention us as the source of the data... should link back to our website where appropriate" | Within terms |
| Public test key `1` as the shipped default, Premium key only in the backend environment (`AGENTS.md`) | "You can use the test API key '1' during development of your app or for educational use" | Within terms |
| No provider data or images committed to the repository (`AGENTS.md`) | "You also cannot remove or alter any copyright or trademark notices." (and the absence of any redistribution grant) | Within terms |
| README screenshots limited to screens without TheCocktailDB drink photos | No clause addresses screenshots; Zest's own stricter policy | Out of scope of the terms; within Zest's own policy |
| No reselling or exposing the API to third parties; the gateway is loopback by default, LAN exposure is a documented development-only setting (`docs/GATEWAY.md`, `docs/ACCOUNTS.md`) | "You cannot resell our API in any way without specific permission." | Within terms |

Two rows need a caveat rather than a plain "within terms": the appstore
clause ("You cannot publish apps to an appstore unless you are a paid
subscriber") is satisfied by Adam's Premium purchase for a future app-store
release, but Zest has not released to an app store yet, so this has not been
tested in practice; and the Premium terms page does not itself restate a
public-repository allowance, so publishing the source code relies on the
absence of a prohibition rather than an explicit grant.

## Accepted risks and open points

- **Caching and storage are not addressed by the published terms.** The
  gateway's in-memory cache, the on-device drift catalog, and the synced
  collection snapshot on Zest's server all persist API-derived content beyond
  a single request/response. None of the quoted clauses grants or forbids
  this; Adam accepted the risk rather than requesting clarification.
- **Server-side sync of source snapshots is not addressed.** Storing a
  user's saved-recipe `source` JSON on Zest's own backend (`docs/ACCOUNTS.md`)
  is a form of storage the terms do not mention.
- **Shared server-side catalog (M11, Adam's decision 2026-09-14).** Zest's
  backend will persist the full set of provider recipe records fetched through
  the official letter-browse endpoint, refresh it at most daily, and serve it
  as one snapshot to Zest clients. Images are never mirrored; attribution
  travels with the snapshot and stays in the app. The terms do not address
  this form of storage; Adam accepted the risk. It must be revisited before
  any deployment reachable outside Adam's own LAN, where it bears directly on
  the "cannot resell our API" clause. See `docs/M11.md`.
- **The terms page identifies as TheMealDB.** The terms Zest relies on are
  hosted at TheCocktailDB's own terms URL but the page content names TheMealDB.
  Zest treats this as the terms TheCocktailDB has chosen to publish for
  itself, not as an error to work around.
- **No written confirmation was requested.** By Adam's decision (2026-09-14),
  no email was sent to TheCocktailDB asking for explicit permission to
  publish this repository. This record relies solely on the published terms
  quoted above.
- **What would require revisiting this record:** a public app-store release
  (the appstore clause becomes directly load-bearing rather than
  prospective); a public deployment reachable outside Adam's own LAN (changes
  the "resell/expose the API" analysis); or bundling TheCocktailDB data or
  images directly into the repository or a build artifact (currently never
  done, and would need its own review against the artwork/attribution
  clauses).

## Repository-publication checklist

Verified by the integrator on 2026-09-14:

- [x] The full git history was scanned: no API keys, tokens, private keys, or
      real `.env` files are committed. Only `backend/.env.example` is
      committed, containing non-secret local development defaults (the public
      test key `1`, and Docker Compose Postgres credentials documented as
      "non-secret development values" in `docs/ACCOUNTS.md`).
- [x] Committed images are app icons, golden test renders built from
      synthetic fixture data, and the M1 design studies, which use invented
      recipes and invented art — no TheCocktailDB images and no real personal
      photos.
- [x] Two early commits (`018a4738`, `871999565`) carry Adam's personal Gmail
      address as the commit author, rather than his GitHub noreply address.
      Adam decided on 2026-09-14 to keep them as-is (no history rewrite).

Current GitHub state, verified on 2026-09-14:

- [x] The repository is public.
- [x] `Development` is the default branch.

Left for Adam:

- [ ] Set the repository description and topics.
