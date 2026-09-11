import 'package:flutter_test/flutter_test.dart';
import 'package:zest/features/discovery/domain/measure.dart';

void main() {
  test('parses unambiguous amounts without changing source text', () {
    const examples = <String, (double, String?)>{
      ' 1 1/2 tsp ': (1.5, 'tsp'),
      '½ oz': (.5, 'oz'),
      '1½ oz': (1.5, 'oz'),
      '¾ ounces': (.75, 'oz'),
      '2⅓ parts': (2 + 1 / 3, 'part'),
      '1/4oz': (.25, 'oz'),
      '30 ml': (30, 'ml'),
      '.5 CL': (.5, 'cl'),
      '1.25 tbsp.': (1.25, 'tbsp'),
      '2 dashes': (2, 'dash'),
      '1': (1, null),
    };
    for (final entry in examples.entries) {
      final measure = Measure.fromJson(entry.key);
      expect(
        measure.amount,
        closeTo(entry.value.$1, 0.000001),
        reason: entry.key,
      );
      expect(measure.unit, entry.value.$2);
      expect(measure.raw, entry.key);
      expect(measure.toJson(), entry.key);
      expect(measure.display, entry.key.trim());
      expect(Measure.fromJson(measure.toJson()).amount, measure.amount);
    }
  });

  test('unknown, absent, ambiguous and invalid quantities stay unparsed', () {
    for (final raw in <String?>[
      null,
      '',
      '  ',
      'to taste',
      'a splash',
      '1-2 oz',
      '1 to 2 oz',
      '1,5 oz',
      '1/0 oz',
      '0 oz',
      '-1 oz',
      '2 scoops',
      '1 oz / 30 ml',
      '1 fl oz',
      '1 pinch salt',
      'NaN',
      'Infinity',
      '1 o..z',
      '1 t.b.s.p',
    ]) {
      final measure = Measure.fromJson(raw);
      expect(measure.raw, raw);
      expect(measure.amount, isNull, reason: raw);
      expect(measure.unit, isNull);
      expect(measure.toJson(), raw);
    }
    expect(Measure.fromJson(' ').display, isNull);
    expect(Measure.fromJson(null).display, isNull);
    expect(() => Measure.fromJson(1), throwsFormatException);
  });
}
