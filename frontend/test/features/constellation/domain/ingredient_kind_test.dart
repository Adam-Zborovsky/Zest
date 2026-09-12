import 'package:flutter_test/flutter_test.dart';
import 'package:zest/features/constellation/domain/ingredient_kind.dart';

void main() {
  test('groups by whole words, never by substrings', () {
    expect(ingredientKindOf('gin'), IngredientKind.spirit);
    expect(ingredientKindOf('ginger'), IngredientKind.herbal);
    expect(ingredientKindOf('lemonade'), IngredientKind.other);
    expect(ingredientKindOf('rumple minze'), IngredientKind.other);
  });

  test('liqueurs and bitters win over the fruit or spirit they name', () {
    expect(ingredientKindOf('orange bitters'), IngredientKind.liqueur);
    expect(ingredientKindOf('coffee liqueur'), IngredientKind.liqueur);
    expect(ingredientKindOf('creme de cassis'), IngredientKind.liqueur);
    expect(ingredientKindOf('sweet vermouth'), IngredientKind.liqueur);
    expect(ingredientKindOf('triple sec'), IngredientKind.liqueur);
  });

  test('mixers stay neutral even when they name an herb or fruit', () {
    expect(ingredientKindOf('ginger ale'), IngredientKind.other);
    expect(ingredientKindOf('lemon-lime soda'), IngredientKind.other);
    expect(ingredientKindOf('coconut milk'), IngredientKind.other);
  });

  test('recognizes the common groups', () {
    expect(ingredientKindOf('light rum'), IngredientKind.spirit);
    expect(ingredientKindOf('lime juice'), IngredientKind.citrus);
    expect(ingredientKindOf('sugar syrup'), IngredientKind.sweet);
    expect(ingredientKindOf('grenadine'), IngredientKind.sweet);
    expect(ingredientKindOf('mint leaf'), IngredientKind.herbal);
  });

  test('unknown or blank names stay in the neutral group', () {
    expect(ingredientKindOf('ice'), IngredientKind.other);
    expect(ingredientKindOf('egg white'), IngredientKind.other);
    expect(ingredientKindOf('wide ingredient 3'), IngredientKind.other);
    expect(ingredientKindOf('   '), IngredientKind.other);
  });
}
