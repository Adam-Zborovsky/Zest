import 'measure.dart';

/// Lexical aliases only. This table does not assert ingredient substitutions.
/// Review rationale and intentionally distinct examples: docs/DATA.md.
const ingredientAliases = <String, String>{
  'dark rums': 'dark rum',
  'light rums': 'light rum',
  'white rums': 'white rum',
  'mint leaves': 'mint leaf',
  'ice cubes': 'ice cube',
};

String normalizeIngredientName(String name) {
  final key = name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  if (key.isEmpty) throw const FormatException('Ingredient name is empty.');
  return ingredientAliases[key] ?? key;
}

/// One original, numbered ingredient/measure pair, not an availability claim.
final class Ingredient {
  Ingredient({
    required this.sourceSlot,
    required this.rawName,
    required this.measure,
  }) {
    if (sourceSlot < 1 || sourceSlot > 15 || rawName.trim().isEmpty) {
      throw const FormatException('Invalid ingredient.');
    }
  }

  factory Ingredient.fromJson(Map<String, dynamic> json) {
    final slot = json['sourceSlot'];
    final name = json['rawName'];
    if (slot is! int || name is! String) {
      throw const FormatException('Invalid ingredient fields.');
    }
    return Ingredient(
      sourceSlot: slot,
      rawName: name,
      measure: Measure.fromJson(json['measure']),
    );
  }

  final int sourceSlot;
  final String rawName;
  final Measure measure;
  String get name => rawName.trim();
  String get normalizedName => normalizeIngredientName(rawName);

  Map<String, dynamic> toJson() => {
    'sourceSlot': sourceSlot,
    'rawName': rawName,
    'measure': measure.toJson(),
  };
}
