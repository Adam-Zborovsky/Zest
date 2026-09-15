import 'package:flutter_test/flutter_test.dart';
import 'package:zest/features/catalog/domain/catalog_search_index.dart';
import 'package:zest/features/discovery/domain/recipe.dart';

/// Builds a synthetic [Recipe] with invented data — never copied provider
/// records — for [id]/[name]/[ingredients] (one measure per ingredient,
/// numbered from slot 1).
Recipe _recipe(String id, String name, List<String> ingredients) {
  final json = <String, dynamic>{
    'idDrink': id,
    'strDrink': name,
    'strInstructions': 'Combine the invented ingredients and serve.',
  };
  for (var slot = 1; slot <= 15; slot++) {
    if (slot <= ingredients.length) {
      json['strIngredient$slot'] = ingredients[slot - 1];
      json['strMeasure$slot'] = '1 oz';
    } else {
      json['strIngredient$slot'] = null;
      json['strMeasure$slot'] = null;
    }
  }
  return Recipe.fromJson(json);
}

CatalogSuggestion? _find(
  List<CatalogSuggestion> suggestions,
  CatalogSuggestionKind kind,
  String id,
) {
  for (final suggestion in suggestions) {
    if (suggestion.kind == kind && suggestion.id == id) return suggestion;
  }
  return null;
}

void main() {
  // A small invented cocktail catalog exercising every ranking tier.
  final oldFashioned = _recipe('1001', 'Old Fashioned', [
    'Bourbon',
    'Sugar Cube',
    'Angostura Bitters',
    'Orange Peel',
  ]);
  final ginFizz = _recipe('1002', 'Gin Fizz', [
    'Gin',
    'Lemon Juice',
    'Sugar',
    'Soda Water',
  ]);
  final pinkGinSour = _recipe('1003', 'Pink Gin Sour', [
    'Gin',
    'Lime Juice',
    'Pink Grapefruit Syrup',
  ]);
  final ginRickey = _recipe('1004', 'Gin Rickey', [
    'Gin',
    'Lime Juice',
    'Soda Water',
  ]);
  final margarita = _recipe('1005', 'Margarita', [
    'Tequila',
    'Lime Juice',
    'Triple Sec',
  ]);
  final mojito = _recipe('1006', 'Mojito', [
    'White Rum',
    'Lime Juice',
    'Mint Leaves',
    'Soda Water',
  ]);
  final cassisFizz = _recipe('1007', 'Cassis Garden Fizz', [
    'Crème de Cassis',
    'Soda Water',
  ]);
  final rumOldFashioned = _recipe('1008', 'Rum Old Fashioned', [
    'Dark Rum',
    'Sugar Cube',
    'Angostura Bitters',
  ]);

  final recipes = [
    oldFashioned,
    ginFizz,
    pinkGinSour,
    ginRickey,
    margarita,
    mojito,
    cassisFizz,
    rumOldFashioned,
  ];

  late CatalogSearchIndex index;

  setUp(() {
    index = CatalogSearchIndex.fromRecipes(recipes);
  });

  group('foldSearchText', () {
    test('lowercases, folds diacritics and treats punctuation as separators', () {
      expect(foldSearchText('Crème de Cassis'), 'creme de cassis');
      expect(foldSearchText('OLD-FASHIONED'), 'old fashioned');
      expect(foldSearchText('  Gin   Fizz  '), 'gin fizz');
      expect(foldSearchText('Ångström Café'), 'angstrom cafe');
    });

    test('preserves non-Latin letters and digits', () {
      expect(foldSearchText('7 Up'), '7 up');
      expect(foldSearchText('מרגריטה'), 'מרגריטה');
    });
  });

  group('suggest — ranking tiers', () {
    test(
      'diacritic folding: "creme" finds the invented Crème de Cassis ingredient',
      () {
        final results = index.suggest('creme');
        final match = _find(
          results,
          CatalogSuggestionKind.ingredient,
          'crème de cassis',
        );
        expect(match, isNotNull);
        expect(match!.label, 'Crème de Cassis');
      },
    );

    test('typo tolerance: "lime jiuce" finds Lime Juice', () {
      final results = index.suggest('lime jiuce');
      final match = _find(results, CatalogSuggestionKind.ingredient, 'lime juice');
      expect(match, isNotNull);
      expect(match!.label, 'Lime Juice');
    });

    test('typo tolerance: "margarta" finds Margarita', () {
      final results = index.suggest('margarta');
      expect(_find(results, CatalogSuggestionKind.recipe, '1005'), isNotNull);
    });

    test('word-prefix tier: "old fash" finds Old Fashioned via full-label prefix', () {
      final results = index.suggest('old fash');
      expect(results.first.id, '1001');
      expect(results.first.kind, CatalogSuggestionKind.recipe);
    });

    test('word-prefix tier: a lone later word still matches in order', () {
      // "fash" is not a prefix of the whole label "old fashioned", so this
      // only succeeds through the word-prefix tier.
      final results = index.suggest('fash');
      expect(_find(results, CatalogSuggestionKind.recipe, '1001'), isNotNull);
    });

    test(
      'exact ingredient "Gin" ranks above the prefix-matching recipe '
      '"Gin Fizz" and the substring-matching recipe "Pink Gin Sour"',
      () {
        final results = index.suggest('gin', limit: 20);
        final ginIndex = results.indexWhere(
          (s) => s.kind == CatalogSuggestionKind.ingredient && s.id == 'gin',
        );
        final ginFizzIndex = results.indexWhere(
          (s) => s.kind == CatalogSuggestionKind.recipe && s.id == '1002',
        );
        final pinkGinSourIndex = results.indexWhere(
          (s) => s.kind == CatalogSuggestionKind.recipe && s.id == '1003',
        );
        expect(ginIndex, greaterThanOrEqualTo(0));
        expect(ginFizzIndex, greaterThanOrEqualTo(0));
        expect(pinkGinSourIndex, greaterThanOrEqualTo(0));
        expect(ginIndex, lessThan(ginFizzIndex));
        expect(ginFizzIndex, lessThan(pinkGinSourIndex));
      },
    );

    test('prevalence tie-break: Lime Juice (4 recipes) outranks Lemon Juice (1) on a substring tier', () {
      final results = index.suggest('juice', limit: 20);
      final limeIndex = results.indexWhere(
        (s) => s.kind == CatalogSuggestionKind.ingredient && s.id == 'lime juice',
      );
      final lemonIndex = results.indexWhere(
        (s) => s.kind == CatalogSuggestionKind.ingredient && s.id == 'lemon juice',
      );
      expect(limeIndex, greaterThanOrEqualTo(0));
      expect(lemonIndex, greaterThanOrEqualTo(0));
      expect(limeIndex, lessThan(lemonIndex));
    });

    test('alias spelling finds the canonical identity exactly once', () {
      final results = index.suggest('dark rums');
      final matches = results
          .where((s) => s.kind == CatalogSuggestionKind.ingredient)
          .toList();
      expect(matches, hasLength(1));
      expect(matches.single.id, 'dark rum');
      expect(matches.single.label, 'Dark Rum');
    });

    test('short words get no typo tolerance ("gni" does not match "gin")', () {
      final results = index.suggest('gni');
      expect(
        results.any((s) => s.kind == CatalogSuggestionKind.ingredient && s.id == 'gin'),
        isFalse,
      );
    });
  });

  group('suggest — parameters and edge inputs', () {
    test('kinds filters suggestions to the requested kinds', () {
      final ingredientsOnly = index.suggest(
        'gin',
        kinds: const {CatalogSuggestionKind.ingredient},
      );
      expect(
        ingredientsOnly.every((s) => s.kind == CatalogSuggestionKind.ingredient),
        isTrue,
      );

      final recipesOnly = index.suggest(
        'gin',
        kinds: const {CatalogSuggestionKind.recipe},
      );
      expect(
        recipesOnly.every((s) => s.kind == CatalogSuggestionKind.recipe),
        isTrue,
      );
    });

    test('empty kinds returns no suggestions', () {
      expect(index.suggest('gin', kinds: const {}), isEmpty);
    });

    test('limit caps the result count', () {
      expect(index.suggest('gin', limit: 1), hasLength(1));
    });

    test('limit <= 0 throws ArgumentError', () {
      expect(() => index.suggest('gin', limit: 0), throwsArgumentError);
      expect(() => index.suggest('gin', limit: -1), throwsArgumentError);
    });

    test('empty, whitespace, emoji, very long and RTL queries do not throw', () {
      expect(index.suggest(''), isEmpty);
      expect(index.suggest('   \t  '), isEmpty);
      expect(() => index.suggest('🍸🍹🥃'), returnsNormally);
      expect(() => index.suggest('g' * 500), returnsNormally);
      expect(() => index.suggest('מרגריטה קוקטייל'), returnsNormally);
      expect(() => index.suggest('كوكتيل'), returnsNormally);
    });
  });

  group('determinism', () {
    test('two indices built from differently ordered recipes agree exactly', () {
      final forward = CatalogSearchIndex.fromRecipes(recipes);
      final shuffled = CatalogSearchIndex.fromRecipes(recipes.reversed.toList());

      for (final query in ['gin', 'juice', 'old fash', 'margarta', 'creme']) {
        expect(
          shuffled.suggest(query, limit: 20),
          forward.suggest(query, limit: 20),
          reason: 'query "$query" should rank identically regardless of build order',
        );
      }
    });
  });

  group('recipeIdsMatchingName', () {
    test('returns every matching recipe, ranked, with no limit', () {
      final ids = index.recipeIdsMatchingName('gin');
      // "Gin Fizz" and "Gin Rickey" are label prefixes (tier 2); "Pink Gin
      // Sour" only matches as a substring (tier 4).
      expect(ids, ['1002', '1004', '1003']);
    });

    test('empty query returns no ids', () {
      expect(index.recipeIdsMatchingName(''), isEmpty);
    });

    test(
      'finding #10: typo-tier noise never joins a query that already has '
      'real (tier 1-4) matches',
      () {
        // "sour" is a real word-prefix match on "Pink Gin Sour" (tier 3):
        // no other recipe name is anywhere near it edit-distance-wise, but
        // before the fix every recipe's tier was computed and merged
        // regardless, so an unrelated typo-tier hit could ride along.
        expect(index.recipeIdsMatchingName('sour'), ['1003']);
      },
    );

    test(
      'finding #10: typo tier is still used when tiers 1-4 return nothing '
      'at all',
      () {
        // "fasioned" (a dropped 'h') matches nothing at tiers 1-4, but is
        // one edit from "fashioned" — the fallback must still surface it.
        final ids = index.recipeIdsMatchingName('fasioned');
        expect(ids, containsAll(['1001', '1008']));
      },
    );
  });

  group('finding #10: equal-length-prefix typo rule needs 5+ char words', () {
    late CatalogSearchIndex miniIndex;

    setUp(() {
      miniIndex = CatalogSearchIndex.fromRecipes([
        _recipe('2001', 'Flannel Special', ['Whiskey']),
      ]);
    });

    test(
      'a 4-char query one edit from a longer word\'s equal-length prefix '
      'no longer matches',
      () {
        // "glan" is one substitution from "flan" — "Flannel"'s first four
        // letters — but at 4 chars the equal-length-prefix rule no longer
        // applies (full-word tolerance still needs 4+, but "glan" is also
        // 3 characters shorter than "flannel", well past the one-edit
        // length window, so the full-word check can't rescue it either).
        expect(miniIndex.recipeIdsMatchingName('glan'), isEmpty);
      },
    );

    test(
      'a 5-char query one edit from a longer word\'s equal-length prefix '
      'still matches',
      () {
        // "glann" is one substitution from "flann" — "Flannel"'s first
        // five letters — and 5+ chars keeps the equal-length-prefix rule.
        expect(miniIndex.recipeIdsMatchingName('glann'), ['2001']);
      },
    );
  });

  group('recipeIdsWithIngredient', () {
    test('orders recipes by folded name then id', () {
      final ids = index.recipeIdsWithIngredient('Gin');
      expect(ids, ['1002', '1004', '1003']);
    });

    test('normalizes the argument identity', () {
      expect(
        index.recipeIdsWithIngredient('  GIN  '),
        index.recipeIdsWithIngredient('gin'),
      );
    });

    test('unknown identity returns an empty list', () {
      expect(index.recipeIdsWithIngredient('unobtainium'), isEmpty);
    });
  });

  group('CatalogSearchIndex.empty', () {
    test('has no suggestions or matches', () {
      expect(CatalogSearchIndex.empty.suggest('gin'), isEmpty);
      expect(CatalogSearchIndex.empty.recipeIdsMatchingName('gin'), isEmpty);
      expect(CatalogSearchIndex.empty.recipeIdsWithIngredient('gin'), isEmpty);
    });
  });

  group('CatalogSuggestion value semantics', () {
    test('equality and toString', () {
      const a = CatalogSuggestion(
        kind: CatalogSuggestionKind.ingredient,
        id: 'gin',
        label: 'Gin',
        recipeCount: 3,
      );
      const b = CatalogSuggestion(
        kind: CatalogSuggestionKind.ingredient,
        id: 'gin',
        label: 'Gin',
        recipeCount: 3,
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a.toString(), contains('Gin'));
      expect(a.toString(), contains('gin'));
    });
  });

  group('performance', () {
    test('500 suggest calls over a 2,000-recipe synthetic catalog stay fast', () {
      final ingredientPool = [
        for (var i = 0; i < 60; i++) 'Synthetic Ingredient $i',
      ];
      final bigCatalog = <Recipe>[
        for (var i = 0; i < 2000; i++)
          _recipe('900${i.toString().padLeft(4, '0')}', 'Synthetic Recipe Number $i', [
            ingredientPool[i % ingredientPool.length],
            ingredientPool[(i * 7 + 3) % ingredientPool.length],
            ingredientPool[(i * 13 + 5) % ingredientPool.length],
          ]),
      ];
      final bigIndex = CatalogSearchIndex.fromRecipes(bigCatalog);

      final queries = [
        'synthetic',
        'recipe',
        'ingredient',
        'syntetic', // typo
        'ingrediant', // typo
        'number 1',
        'nu',
        '',
      ];

      final stopwatch = Stopwatch()..start();
      for (var i = 0; i < 500; i++) {
        bigIndex.suggest(queries[i % queries.length]);
      }
      stopwatch.stop();

      // Generous, non-flaky bound: this should be comfortably interactive
      // (well under 5 seconds for 500 calls on a 2,000-entry catalog).
      expect(stopwatch.elapsedMilliseconds, lessThan(5000));
    });
  });
}
