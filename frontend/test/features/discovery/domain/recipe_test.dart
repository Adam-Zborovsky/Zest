import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zest/features/discovery/domain/ingredient.dart';
import 'package:zest/features/discovery/domain/recipe.dart';

Map<String, dynamic> fixture() {
  final envelope =
      jsonDecode(File('test/fixtures/synthetic_drinks.json').readAsStringSync())
          as Map<String, dynamic>;
  return (envelope['drinks'] as List).single as Map<String, dynamic>;
}

void main() {
  test('unnamed slots and orphan measures are not recipe ingredients', () {
    final recipe = Recipe.fromJson({
      ...fixture(),
      'strIngredient2': ' ',
      'strMeasure2': 'orphan source text',
    });
    expect(recipe.ingredients.map((i) => i.sourceSlot), [1, 3, 4, 15]);
    expect(recipe.toJson()['strIngredient2'], isNull);
    expect(recipe.toJson()['strMeasure2'], isNull);
  });

  test(
    'full recipe preserves original text, attribution and numbered pairs',
    () {
      final json = fixture();
      final recipe = Recipe.fromJson(json);
      expect(recipe.id, '900001');
      expect(recipe.name, json['strDrink']);
      expect(recipe.instructions, json['strInstructions']);
      expect(recipe.thumbnailUrl, json['strDrinkThumb']);
      expect(recipe.category, 'Synthetic category');
      expect(recipe.glass, 'Test glass');
      expect(recipe.alcoholic, 'Non alcoholic');
      expect(recipe.sourceUrl, json['strSource']);
      expect(recipe.imageSource, json['strImageSource']);
      expect(recipe.imageAttribution, json['strImageAttribution']);
      expect(recipe.creativeCommonsConfirmed, 'No');
      expect(
        recipe.attributionUrl.toString(),
        'https://www.thecocktaildb.com/drink/900001',
      );
      expect(recipe.ingredients.map((i) => i.sourceSlot), [1, 3, 4, 15]);
      expect(recipe.ingredients.first.rawName, '  Mint Leaves  ');
      expect(recipe.ingredients.first.name, 'Mint Leaves');
      expect(recipe.ingredients.first.normalizedName, 'mint leaf');
      expect(recipe.ingredients.first.measure.raw, ' 1 1/2 tsp ');
      expect(recipe.ingredients[1].measure.amount, .5);
      expect(recipe.ingredients[2].measure.amount, isNull);
      expect(recipe.ingredients.last.measure.raw, isNull);
      expect(() => recipe.ingredients.clear(), throwsUnsupportedError);
    },
  );

  test('models round-trip supported semantic fields through JSON encoding', () {
    final recipe = Recipe.fromJson(fixture());
    final copy = Recipe.fromJson(
      jsonDecode(jsonEncode(recipe.toJson())) as Map<String, dynamic>,
    );
    expect(copy.toJson(), recipe.toJson());
    for (final ingredient in recipe.ingredients) {
      expect(
        Ingredient.fromJson(ingredient.toJson()).toJson(),
        ingredient.toJson(),
      );
    }
    final summary = RecipeSummary.fromJson(fixture());
    expect(RecipeSummary.fromJson(summary.toJson()).toJson(), summary.toJson());
    expect(summary.attributionUrl, recipe.attributionUrl);
  });

  test('nullable full record is not fabricated or confused with a summary', () {
    final full = {
      'idDrink': '900002',
      'strDrink': 'Empty synthetic recipe',
      'strInstructions': null,
      'strIngredient1': null,
    };
    final recipe = Recipe.fromJson(full);
    expect(recipe.instructions, isNull);
    expect(recipe.ingredients, isEmpty);
    final summary = RecipeSummary.fromJson(full).toJson();
    expect(() => Recipe.fromJson(summary), throwsFormatException);
  });

  test('rejects invalid required fields and nullable field types safely', () {
    for (final entry in <String, Object?>{
      'idDrink': 'bad/id',
      'strDrink': ' ',
      'strInstructions': 1,
      'strIngredient3': false,
      'strMeasure15': <String>[],
      'strImageAttribution': {},
      'strDrinkThumb': false,
    }.entries) {
      expect(
        () => Recipe.fromJson({...fixture(), entry.key: entry.value}),
        throwsFormatException,
      );
    }
    for (final field in [
      'idDrink',
      'strDrink',
      'strInstructions',
      'strIngredient1',
    ]) {
      final json = fixture()..remove(field);
      expect(() => Recipe.fromJson(json), throwsFormatException);
    }
    expect(
      () => RecipeSummary.fromJson({'idDrink': 2, 'strDrink': 'Test'}),
      throwsFormatException,
    );
    expect(
      () => Ingredient.fromJson({'sourceSlot': 16, 'rawName': 'Test'}),
      throwsFormatException,
    );
    expect(
      () => Ingredient.fromJson({'sourceSlot': 1, 'rawName': ' '}),
      throwsFormatException,
    );
  });

  test('invalid fields do not appear in parsing errors', () {
    try {
      Recipe.fromJson({...fixture(), 'idDrink': 'SENSITIVE_SENTINEL'});
      fail('Expected invalid ID.');
    } on FormatException catch (error) {
      expect(error.toString(), isNot(contains('SENSITIVE_SENTINEL')));
      expect(error.source, isNull);
    }
  });
}
