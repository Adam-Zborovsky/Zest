# M1 art-direction studies

Status: Adam selected **C — Botanical Play**: leafy greens, soft shapes, and cut-paper garnish. These files preserve the static studies presented before implementation. The chosen Flutter foundation is documented in `../../DESIGN.md`; milestone verification is recorded separately in `../../VERIFICATION.md`. Open `index.html` for the comparison, or a `*-mobile.png` for a full offline gallery.

Each study contains the same invented recipe, buttons, chips, empty/loading/error states and a bottom-sheet specimen. No provider records, provider images, or personal photos are used. The illustrations are generated inline vectors. No homepage or constellation placement is decided here.

## Options

| Direction | Signature | Display / body | Tradeoff |
|---|---|---|---|
| A — Citrus Print | Citrus crate labels, ink contours, solid offset shadows | Bricolage Grotesque / DM Sans | Strongest playful identity; borders need restraint on dense screens. |
| B — Midnight Aperitivo | Fine coupe contours, plum surfaces and amber actions | Fraunces / DM Sans | Clear evening atmosphere; less overtly playful. |
| C — Botanical Play | Cut-paper garnish and asymmetric recipe-card corners | Fraunces / DM Sans | Approachable and calm; botanical styling risks a generic wellness association. |

Historical recommendation before Adam's choice: A, for its graphic identity and ability to carry a small signature into ordinary controls and secondary states. Adam selected C; that choice supersedes this recommendation.

Font references: [Bricolage Grotesque](https://fonts.google.com/specimen/Bricolage+Grotesque), [Fraunces](https://fonts.google.com/specimen/Fraunces), [DM Sans](https://fonts.google.com/specimen/DM+Sans). The chosen Fraunces and DM Sans files and licenses are now bundled locally in Flutter; provenance is recorded in `../../../frontend/assets/fonts/README.md`. No font package dependency was added.

## Provenance and local corrections

Generated through Stitch on 2026-09-10 using `GEMINI_3_8_FLASH`, the highest model exposed by this connection (the other choice was `GEMINI_3_5_FLASH_LITE`).

| Study | Stitch project | Screen |
|---|---|---|
| A | 15743765590777796129 | 8da65456c22b484d8905d3c8d90160b0 |
| B | 10212484763663081886 | e938758c9f2940a1bf8243183c44da95 |
| C | 6889591669284971436 | 1b4daf7fecaa4c41a8a17f1c0959b0b0 |

The HTML was downloaded and minimally corrected: removed an invented ABV/volume from B and its unverified accessibility pass claim; removed unnecessary recipe numbering and loading subcopy; renamed ingredient captions; fixed C's malformed font URL; corrected B's horizontal framing; added visible button focus, minimum button targets and reduced-motion overrides in `preview.css`. The `*-mobile.png` files are local Chrome headless captures of the corrected HTML at 412 × 2100. The comparison uses those PNGs and works offline. The individual HTML studies require Tailwind CDN and Google Fonts; those are preview dependencies only and are not app dependencies.

## Review

The main agent inspected all three local captures. A separate review agent checked the source and images, found B's cropped framing and unnecessary C loading copy, and confirmed all required specimen types and no blocking product/data-scope problems. Those two findings were corrected before presentation.

Design judgment using the design-evaluation-scoring rubric (1–5 per dimension). These are subjective review scores, not empirical measurements or accessibility certification:

| Study | Layout | Type | Color | Whitespace | Hierarchy | Consistency | Craft | Expression | Total / 40 |
|---|---|---|---|---|---|---|---|---|---|
| A | 4 | 4 | 3 | 4 | 4 | 4 | 3 | 5 | 31 |
| B | 4 | 4 | 4 | 4 | 4 | 4 | 3 | 4 | 31 |
| C | 4 | 4 | 3 | 4 | 4 | 4 | 3 | 4 | 30 |

First impressions: A is graphic and direct; B is restrained and atmospheric; C is soft and approachable. No broken imagery or missing focal point remains in the corrected captures. Primary content has a clear heading/body/action hierarchy, and errors use text plus icons. Weakest areas are small/faint specimen annotations, occasional decorative borders, and the limitations of static controls. A and C especially need stronger secondary-text contrast. These samples do not validate text scaling, screen readers or widget interaction: some chips and sheet rows are static elements. The chosen Flutter foundation must resolve these issues, test actual interaction and semantics, measure contrast, and verify reduced motion and text scaling.

The Flutter baseline was unchanged when these studies were presented. The selected C foundation now lives in the app; see `../../DESIGN.md`. `flutter analyze` and `flutter test` passed at the start of M1; implementation checks are recorded in `../../VERIFICATION.md`. No later-milestone behavior was added.
