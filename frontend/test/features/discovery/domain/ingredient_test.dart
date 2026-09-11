import 'package:flutter_test/flutter_test.dart';
import 'package:zest/features/discovery/domain/ingredient.dart';

void main() {
  test('normalizes casing/whitespace and each reviewed plural alias', () {
    expect(normalizeIngredientName('  Dark \t RUM\n'), 'dark rum');
    for (final entry in ingredientAliases.entries) {
      expect(
        normalizeIngredientName(' ${entry.key.toUpperCase()} '),
        entry.value,
      );
      expect(normalizeIngredientName(entry.value), entry.value);
    }
    expect(() => normalizeIngredientName(' '), throwsFormatException);
    expect(() => ingredientAliases['test'] = 'other', throwsUnsupportedError);
  });

  test(
    'does not infer substitutions, brand families, preparation or garnish',
    () {
      const distinct = [
        'dark rum',
        'white rum',
        'light rum',
        'spiced rum',
        'Imaginary House Dark Rum',
        'Imaginary House Rum',
        'lime',
        'lime juice',
        'lime peel',
        'lime cordial',
        'mint leaf',
        'mint',
        'ice cube',
        'crushed ice',
        'simple syrup',
        'sugar',
        'Dark_Rum',
      ];
      expect(
        distinct.map(normalizeIngredientName).toSet(),
        hasLength(distinct.length),
      );
    },
  );
}
