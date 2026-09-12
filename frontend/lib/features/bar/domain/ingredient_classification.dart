import '../../discovery/domain/ingredient.dart';

/// Reviewed garnish classification for M4 bar matching. Only these forms are
/// excluded from a recipe's missing essentials; everything the recipe names
/// that is not selected counts as missing. Rationale per entry lives in
/// docs/DATA.md and this table was reviewed with docs/reviews/M4.md.
///
/// These forms are garnish presentations of a fruit or herb — a twist, peel,
/// wedge, slice, or sprig completes the serve rather than measuring into the
/// drink. Known edge cases (a peel defining a Horse's Neck, for example) are
/// accepted and documented rather than silently reclassified.
const _garnishSuffixes = <String>[
  ' twist',
  ' peel',
  ' wedge',
  ' slice',
  ' sprig',
];

/// Whole-item garnishes: aromatic spice dusted on top and cherries dropped in.
/// Plain fruit and herb names (lemon, mint leaf) stay essential.
const _garnishNames = <String>{
  'nutmeg',
  'ground nutmeg',
  'cherry',
  'maraschino cherry',
};

bool isOptionalGarnish(String normalizedName) =>
    _garnishNames.contains(normalizedName) ||
    _garnishSuffixes.any(normalizedName.endsWith);

/// Reviewed substitution suggestions for M4, applied in table order. A pair
/// means either side may be suggested when the recipe names the other and the
/// selection contains its partner. These are suggestions for the reader to
/// review — never an identity merge; both names stay distinct ingredients.
const ingredientSubstitutionPairs = <(String, String)>[
  ('fresh lime juice', 'lime juice'),
  ('fresh lemon juice', 'lemon juice'),
  ('fresh orange juice', 'orange juice'),
  ('fresh grapefruit juice', 'grapefruit juice'),
  ('fresh pineapple juice', 'pineapple juice'),
  ('fresh cranberry juice', 'cranberry juice'),
  ('granulated sugar', 'sugar'),
  ('superfine sugar', 'sugar'),
  ('soda water', 'sparkling water'),
];

/// Returns the normalized selected ingredient that could stand in for
/// [missing], or null when no reviewed pair applies.
String? substitutionFor(String missing, Set<String> available) {
  for (final (a, b) in ingredientSubstitutionPairs) {
    if (missing == a && available.contains(b)) return b;
    if (missing == b && available.contains(a)) return a;
  }
  return null;
}

/// Normalizes a user- or provider-supplied ingredient name for selection
/// identity. Same rules as recipe ingredients; throws on blank input.
String normalizeSelection(String name) => normalizeIngredientName(name);
