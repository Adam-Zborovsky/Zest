import 'package:flutter_test/flutter_test.dart';
import 'package:zest/features/bar/domain/bar_match.dart';
import 'package:zest/features/bar/domain/ingredient_classification.dart';
import 'package:zest/features/discovery/domain/recipe.dart';

import '../../../support/bar_fixtures.dart';

Recipe recipe(
  String name,
  List<(String, String?)> ingredients, {
  String id = '99101',
}) => Recipe.fromJson(barRecipeJson(id: id, name: name, ingredients: ingredients));

void main() {
  group('unselected is not available', () {
    test('an empty selection leaves every essential missing', () {
      final match = classifyRecipe(
        recipe('Testbench Sour', [('Imaginary gin', '2 oz')]),
        const {},
      );

      expect(match.category, BarMatchCategory.missingEssentials);
      expect(match.missingEssentials, ['Imaginary gin']);
      expect(match.substitutions, isEmpty);
      expect(match.optionalGarnishes, isEmpty);
    });

    test('a partial selection only covers what it names', () {
      final match = classifyRecipe(
        recipe('Testbench Sour', [
          ('Imaginary gin', '2 oz'),
          ('Pretend lime juice', '1 oz'),
        ]),
        {'imaginary gin'},
      );

      expect(match.category, BarMatchCategory.missingEssentials);
      expect(match.missingEssentials, ['Pretend lime juice']);
    });

    test('a similar but distinct name does not cover the requirement', () {
      final match = classifyRecipe(
        recipe('Testbench Sour', [('Dark Rum', '2 oz')]),
        {'light rum', 'rum'},
      );

      expect(match.category, BarMatchCategory.missingEssentials);
      expect(match.missingEssentials, ['Dark Rum']);
    });
  });

  group('reviewed aliases and deduplication', () {
    test('an aliased selection covers the requirement', () {
      final match = classifyRecipe(
        recipe('Testbench Sour', [('Dark Rum', '2 oz')]),
        {'dark rums'},
      );

      expect(match.category, BarMatchCategory.ready);
      expect(match.missingEssentials, isEmpty);
    });

    test('duplicate slots after normalization count once', () {
      final match = classifyRecipe(
        recipe('Twice Minty', [
          ('Mint Leaves', '6'),
          ('mint leaf', '2'),
          ('Imaginary gin', '2 oz'),
        ]),
        {'imaginary gin'},
      );

      expect(match.category, BarMatchCategory.missingEssentials);
      expect(match.missingEssentials, ['Mint Leaves']);
    });
  });

  group('optional garnishes', () {
    test('reviewed garnish forms are not counted as missing', () {
      for (final garnish in [
        'Nutmeg',
        'Ground Nutmeg',
        'Cherry',
        'Maraschino Cherry',
        'Lemon Twist',
        'Orange Peel',
        'Lime Wedge',
        'Pineapple Slice',
        'Mint Sprig',
      ]) {
        final match = classifyRecipe(
          recipe('Garnished', [('Imaginary gin', '2 oz'), (garnish, null)]),
          {'imaginary gin'},
        );

        expect(match.category, BarMatchCategory.ready, reason: garnish);
        expect(match.optionalGarnishes, [garnish], reason: garnish);
        expect(match.missingEssentials, isEmpty, reason: garnish);
      }
    });

    test('plain fruit, herbs, and unreviewed names stay essential', () {
      for (final essential in [
        'Lemon',
        'Mint',
        'Mint Leaf',
        'Ice Cube',
        'Orange',
        'Cocktail Onion',
        'Celery Stalk',
      ]) {
        final match = classifyRecipe(
          recipe('Strict', [('Imaginary gin', '2 oz'), (essential, null)]),
          {'imaginary gin'},
        );

        expect(
          match.category,
          BarMatchCategory.missingEssentials,
          reason: essential,
        );
        expect(match.missingEssentials, [essential], reason: essential);
      }
    });
  });

  group('reviewed substitutions', () {
    test('a selected partner moves the recipe to the substitution category', () {
      final match = classifyRecipe(
        recipe('Fresh Pressed', [
          ('Imaginary gin', '2 oz'),
          ('Fresh Lime Juice', '1 oz'),
        ]),
        {'imaginary gin', 'lime juice'},
      );

      expect(match.category, BarMatchCategory.substitution);
      expect(match.missingEssentials, ['Fresh Lime Juice']);
      expect(match.substitutions, [
        const BarSubstitution(
          recipeWants: 'Fresh Lime Juice',
          youHave: 'lime juice',
        ),
      ]);
    });

    test('substitution pairs work in both directions', () {
      final reverse = classifyRecipe(
        recipe('Plain Sweetener', [
          ('Imaginary gin', '2 oz'),
          ('Sugar', '1 tsp'),
        ]),
        {'imaginary gin', 'granulated sugar'},
      );
      expect(reverse.category, BarMatchCategory.substitution);
      expect(reverse.substitutions.single.youHave, 'granulated sugar');

      final sparkling = classifyRecipe(
        recipe('Bubbly', [
          ('Imaginary gin', '2 oz'),
          ('Soda Water', '4 oz'),
        ]),
        {'imaginary gin', 'sparkling water'},
      );
      expect(sparkling.category, BarMatchCategory.substitution);
      expect(sparkling.substitutions.single.youHave, 'sparkling water');
    });

    test('a substitution without its partner stays an ordinary missing item', () {
      final match = classifyRecipe(
        recipe('Fresh Pressed', [('Fresh Lime Juice', '1 oz')]),
        {'imaginary gin'},
      );

      expect(match.category, BarMatchCategory.missingEssentials);
      expect(match.substitutions, isEmpty);
      expect(match.missingEssentials, ['Fresh Lime Juice']);
    });

    test('one unsubstituted essential keeps the recipe in the missing bucket', () {
      final match = classifyRecipe(
        recipe('Mixed News', [
          ('Imaginary gin', '2 oz'),
          ('Fresh Lime Juice', '1 oz'),
          ('Pretend triple sec', '1 oz'),
        ]),
        {'imaginary gin', 'lime juice'},
      );

      expect(match.category, BarMatchCategory.missingEssentials);
      expect(match.missingEssentials, ['Fresh Lime Juice', 'Pretend triple sec']);
      expect(match.substitutions.single.recipeWants, 'Fresh Lime Juice');
    });
  });

  group('readiness', () {
    test('every essential selected means ready', () {
      final match = classifyRecipe(
        recipe('Testbench Sour', [
          ('Imaginary Gin', '2 oz'),
          ('Pretend lime juice', '1 oz'),
          ('Lemon Twist', null),
        ]),
        {'imaginary gin', 'pretend lime juice'},
      );

      expect(match.category, BarMatchCategory.ready);
      expect(match.optionalGarnishes, ['Lemon Twist']);
    });

    test('a recipe with no named ingredients is ready with empty lists', () {
      final match = classifyRecipe(
        recipe('Empty Vessel', [], id: '99102'),
        const {},
      );

      expect(match.category, BarMatchCategory.ready);
      expect(match.missingEssentials, isEmpty);
      expect(match.optionalGarnishes, isEmpty);
    });
  });

  group('classification helpers', () {
    test('garnish suffixes do not swallow whole identities', () {
      expect(isOptionalGarnish('lemon twist'), isTrue);
      expect(isOptionalGarnish('twist of lemon'), isFalse);
      expect(isOptionalGarnish('orange peel'), isTrue);
      expect(isOptionalGarnish('orange peel syrup'), isFalse);
      expect(isOptionalGarnish('lemon'), isFalse);
    });

    test('substitution lookup is limited to the reviewed pairs', () {
      expect(substitutionFor('lime cordial', {'lime juice'}), isNull);
      expect(substitutionFor('ginger ale', {'ginger beer'}), isNull);
      expect(substitutionFor('dark rum', {'light rum'}), isNull);
      expect(substitutionFor('fresh lime juice', {'lemon juice'}), isNull);
    });

    test('selection normalization matches ingredient normalization', () {
      expect(normalizeSelection('  Dark   Rums '), 'dark rum');
      expect(() => normalizeSelection('  '), throwsFormatException);
    });
  });
}
