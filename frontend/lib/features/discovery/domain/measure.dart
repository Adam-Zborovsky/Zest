/// A source measure is always retained, even when it cannot be parsed safely.
/// Amounts are informational: no unit conversion or missing-quantity inference.
final class Measure {
  const Measure._(this.raw, this.amount, this.unit);

  factory Measure.fromJson(Object? value) {
    if (value != null && value is! String) {
      throw const FormatException('Invalid measure field.');
    }
    final raw = value as String?;
    var text = raw?.trim() ?? '';
    const fractions = {
      '¼': '1/4',
      '½': '1/2',
      '¾': '3/4',
      '⅓': '1/3',
      '⅔': '2/3',
      '⅛': '1/8',
      '⅜': '3/8',
      '⅝': '5/8',
      '⅞': '7/8',
    };
    for (final entry in fractions.entries) {
      text = text.replaceAll(entry.key, ' ${entry.value}');
    }
    text = text.trim();
    final match = RegExp(
      r'^(\d+\s+\d+/\d+|\d+/\d+|\d+(?:\.\d+)?|\.\d+)\s*([a-zA-Z]+\.?)?$',
    ).firstMatch(text);
    if (match == null) return Measure._(raw, null, null);
    final quantity = match[1]!;
    final parts = quantity.split(RegExp(r'\s+'));
    double? parsePart(String part) {
      if (!part.contains('/')) return double.tryParse(part);
      final ratio = part.split('/').map(double.tryParse).toList();
      if (ratio.any((n) => n == null) || ratio[1] == 0) return null;
      return ratio[0]! / ratio[1]!;
    }

    final numbers = parts.map(parsePart).toList();
    if (numbers.any((n) => n == null)) return Measure._(raw, null, null);
    final amount = numbers.fold<double>(0, (sum, n) => sum + n!);
    final sourceUnit = match[2]?.toLowerCase().replaceAll('.', '');
    const units = {
      'oz': 'oz',
      'ounce': 'oz',
      'ounces': 'oz',
      'ml': 'ml',
      'cl': 'cl',
      'l': 'l',
      'tsp': 'tsp',
      'teaspoon': 'tsp',
      'teaspoons': 'tsp',
      'tbsp': 'tbsp',
      'tablespoon': 'tbsp',
      'tablespoons': 'tbsp',
      'cup': 'cup',
      'cups': 'cup',
      'dash': 'dash',
      'dashes': 'dash',
      'drop': 'drop',
      'drops': 'drop',
      'part': 'part',
      'parts': 'part',
    };
    if (!amount.isFinite ||
        amount <= 0 ||
        (sourceUnit != null && !units.containsKey(sourceUnit))) {
      return Measure._(raw, null, null);
    }
    return Measure._(raw, amount, units[sourceUnit]);
  }

  final String? raw;
  final double? amount;
  final String? unit;
  String? get display =>
      raw == null || raw!.trim().isEmpty ? null : raw!.trim();
  String? toJson() => raw;
}
