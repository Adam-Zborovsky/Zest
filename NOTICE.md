# Notice

The MIT license in `LICENSE` covers Zest's own source code only — the Flutter
app under `frontend/` and the Fastify backend under `backend/`. It does not
cover the following, which remain under their own terms:

## TheCocktailDB recipe data and images

Zest uses TheCocktailDB as its recipe source. Recipe data and drink images
returned by TheCocktailDB's API remain the property of TheCocktailDB /
TheMealDB and are governed by their own published terms, not by Zest's MIT
license. Zest never stores or commits TheCocktailDB recipe records or images
in this repository — see `docs/SOURCES.md` for the full terms and Zest's
reading of them.

## Bundled fonts

Zest bundles the Fraunces and DM Sans variable fonts under the SIL Open Font
License 1.1. The license text for each font is committed alongside the fonts:

- `frontend/assets/fonts/Fraunces-OFL.txt`
- `frontend/assets/fonts/DMSans-OFL.txt`

See `frontend/assets/fonts/README.md` for provenance (pinned to a specific
`google/fonts` commit).

## Third-party packages

Zest's Flutter and Node dependencies (declared in `frontend/pubspec.yaml` and
`backend/package.json`) are each distributed under their own licenses, set by
their respective authors. Installing or building Zest pulls in those licenses
as-is; none of them are altered or relicensed by Zest's MIT license.
