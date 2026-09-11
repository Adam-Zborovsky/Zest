# Bundled typefaces

Zest bundles the upright variable fonts below for offline rendering. Both come from [`google/fonts`](https://github.com/google/fonts) pinned to commit `8e44913e4ff26fc997e6856c1ec40ff4791c98c5`. The local filenames are shortened; the font contents are not modified.

| Local file | Original upstream filename | Source and license |
|---|---|---|
| `Fraunces.ttf` | `Fraunces[SOFT,WONK,opsz,wght].ttf` | [Pinned Fraunces directory](https://github.com/google/fonts/tree/8e44913e4ff26fc997e6856c1ec40ff4791c98c5/ofl/fraunces); `Fraunces-OFL.txt` |
| `DMSans.ttf` | `DMSans[opsz,wght].ttf` | [Pinned DM Sans directory](https://github.com/google/fonts/tree/8e44913e4ff26fc997e6856c1ec40ff4791c98c5/ofl/dmsans); `DMSans-OFL.txt` |

Each companion license is the upstream `OFL.txt` under the SIL Open Font License 1.1. The files are declared as app assets and registered with Flutter's license registry. Preserve them when redistributing the fonts.

The theme names are `Fraunces` and `DM Sans`. Fraunces display text uses weight 600, softness (`SOFT`) 60, and wonk (`WONK`) 1. Body text uses DM Sans weights 400 and 600. No italic file is bundled. No runtime font download or font package dependency is required.
