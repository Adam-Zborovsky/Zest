import 'package:flutter_test/flutter_test.dart';
import 'package:zest/features/catalog/domain/catalog_snapshot.dart';
import 'package:zest/features/discovery/domain/recipe.dart';

import 'discovery_fixtures.dart';

/// Invented provider-shaped records in the discovery fixture style, shaped
/// for catalog tests. No provider recipes or images are test assets.
Map<String, dynamic> catalogRecipe({
  String id = '98001',
  String name = 'Testbench Tonic',
  String? thumbnailUrl,
  String? instructions =
      'Stir the invented ingredients.\nServe in a test glass.',
  List<(String, String?)> ingredients = const [
    ('Imaginary leaf syrup', '1 1/2 oz'),
  ],
}) {
  final json = <String, dynamic>{
    ...discoveryRecipe(id: id, name: name, thumbnailUrl: thumbnailUrl),
    'strInstructions': instructions,
    'strSource': 'https://example.invalid/test-source',
    'strImageSource': null,
    'strImageAttribution': null,
    'strCreativeCommonsConfirmed': null,
  };
  for (var slot = 1; slot <= 15; slot++) {
    json['strIngredient$slot'] = null;
    json['strMeasure$slot'] = null;
  }
  for (var index = 0; index < ingredients.length; index++) {
    json['strIngredient${index + 1}'] = ingredients[index].$1;
    json['strMeasure${index + 1}'] = ingredients[index].$2;
  }
  return json;
}

Recipe catalogRecipeModel({
  String id = '98001',
  String name = 'Testbench Tonic',
  List<(String, String?)> ingredients = const [
    ('Imaginary leaf syrup', '1 1/2 oz'),
  ],
}) => Recipe.fromJson(catalogRecipe(id: id, name: name, ingredients: ingredients));

/// A deterministic, format-valid 64-lowercase-hex "version" for snapshot
/// fixtures — not a real SHA-256, just something that satisfies the wire
/// contract's shape so tests never need the `crypto` package.
String fakeCatalogVersion(String seed) {
  final buffer = StringBuffer();
  var value = seed.codeUnits.fold<int>(7, (acc, c) => (acc * 31 + c) & 0xFFFFFFFF);
  while (buffer.length < 64) {
    value = (value * 1103515245 + 12345) & 0xFFFFFFFF;
    buffer.write(value.toRadixString(16).padLeft(8, '0'));
  }
  return buffer.toString().substring(0, 64);
}

/// A raw `GET /api/catalog` envelope, invented provider-shaped drinks only —
/// for the snapshot client's HTTP-level tests.
Map<String, dynamic> catalogSnapshotEnvelope({
  String? version,
  DateTime? publishedAt,
  List<Map<String, dynamic>> drinks = const [],
  int? recipeCount,
  String attributionName = 'TheCocktailDB',
  String attributionUrl = 'https://www.thecocktaildb.com',
}) => {
  'version': version ?? fakeCatalogVersion('default'),
  'publishedAt': (publishedAt ?? DateTime.utc(2026, 9, 14, 8)).toIso8601String(),
  'recipeCount': recipeCount ?? drinks.length,
  'attribution': {'name': attributionName, 'url': attributionUrl},
  'drinks': drinks,
};

/// A parsed [CatalogSnapshot] fixture — for repository/controller tests that
/// work above the wire format.
CatalogSnapshot catalogSnapshotFixture({
  String? version,
  DateTime? publishedAt,
  List<Recipe>? drinks,
}) {
  final list = drinks ?? [catalogRecipeModel()];
  return CatalogSnapshot(
    version: version ?? fakeCatalogVersion('default'),
    publishedAt: publishedAt ?? DateTime.utc(2026, 9, 14, 8),
    recipeCount: list.length,
    attribution: CatalogAttribution(
      name: 'TheCocktailDB',
      url: Uri.parse('https://www.thecocktaildb.com'),
    ),
    drinks: list,
  );
}

/// One invented recipe per letter, so sync tests can cover the full alphabet
/// with distinct synthetic content. Ingredients exercise alias normalization
/// and Unicode fractions on every letter.
List<Recipe> catalogLetterRecipes(String letter, {int count = 1}) => [
  for (var index = 1; index <= count; index++)
    Recipe.fromJson(
      catalogRecipe(
        id: '${letter.codeUnitAt(0)}$index'.padLeft(6, '0'),
        name: '${letter.toUpperCase()}arden Spritz $index',
        ingredients: const [
          ('Mint Leaves', '6'),
          ('Ice Cubes', null),
          ('Invented Botanical Syrup', '½ oz'),
        ],
      ),
    ),
];

/// Field-by-field comparison for the source round-trip guarantee: `Recipe`
/// has no structural equality, so the store's fidelity test spells it out.
void expectSameRecipe(Recipe actual, Recipe expected) {
  expect(actual.id, expected.id);
  expect(actual.name, expected.name);
  expect(actual.instructions, expected.instructions);
  expect(actual.thumbnailUrl, expected.thumbnailUrl);
  expect(actual.category, expected.category);
  expect(actual.glass, expected.glass);
  expect(actual.alcoholic, expected.alcoholic);
  expect(actual.sourceUrl, expected.sourceUrl);
  expect(actual.imageSource, expected.imageSource);
  expect(actual.imageAttribution, expected.imageAttribution);
  expect(actual.creativeCommonsConfirmed, expected.creativeCommonsConfirmed);
  expect(actual.ingredients, hasLength(expected.ingredients.length));
  for (var index = 0; index < expected.ingredients.length; index++) {
    final stored = actual.ingredients[index];
    final original = expected.ingredients[index];
    expect(stored.sourceSlot, original.sourceSlot);
    expect(stored.rawName, original.rawName);
    expect(stored.measure.raw, original.measure.raw);
    expect(stored.measure.amount, original.measure.amount);
    expect(stored.measure.unit, original.measure.unit);
  }
}
