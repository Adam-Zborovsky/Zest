import 'ingredient.dart';
import 'measure.dart';

String? _text(Map<String, dynamic> json, String key, {bool required = false}) {
  final value = json[key];
  if (value != null && value is! String) {
    throw const FormatException('Invalid recipe field type.');
  }
  final text = value as String?;
  if (required && (text == null || text.trim().isEmpty)) {
    throw const FormatException('Missing required recipe field.');
  }
  return text;
}

String _id(Map<String, dynamic> json) {
  final value = _text(json, 'idDrink', required: true)!;
  if (!RegExp(r'^\d+$').hasMatch(value)) {
    throw const FormatException('Invalid recipe identifier.');
  }
  return value;
}

/// Ingredient filters return summaries. Obtain a Recipe via lookup before use.
final class RecipeSummary {
  const RecipeSummary._({
    required this.id,
    required this.name,
    this.thumbnailUrl,
  });

  factory RecipeSummary.fromJson(Map<String, dynamic> json) => RecipeSummary._(
    id: _id(json),
    name: _text(json, 'strDrink', required: true)!,
    thumbnailUrl: _text(json, 'strDrinkThumb'),
  );

  final String id;
  final String name;
  final String? thumbnailUrl;
  Uri get attributionUrl => Uri.https('www.thecocktaildb.com', '/drink/$id');

  Map<String, dynamic> toJson() => {
    'idDrink': id,
    'strDrink': name,
    'strDrinkThumb': thumbnailUrl,
  };
}

/// Supported metadata and named ingredient pairs round-trip without rewriting
/// text or measures. Empty slots (including orphan measures) and unknown provider
/// fields are deliberately outside the M2 domain model.
final class Recipe {
  Recipe._({
    required this.id,
    required this.name,
    required this.instructions,
    required List<Ingredient> ingredients,
    required this.thumbnailUrl,
    required this.category,
    required this.glass,
    required this.alcoholic,
    required this.sourceUrl,
    required this.imageSource,
    required this.imageAttribution,
    required this.creativeCommonsConfirmed,
  }) : ingredients = List.unmodifiable(ingredients);

  factory Recipe.fromJson(Map<String, dynamic> json) {
    if (!json.containsKey('strInstructions') ||
        !json.containsKey('strIngredient1')) {
      throw const FormatException(
        'Expected full recipe, received incomplete record.',
      );
    }
    final ingredients = <Ingredient>[];
    for (var slot = 1; slot <= 15; slot++) {
      final name = _text(json, 'strIngredient$slot');
      final measure = Measure.fromJson(json['strMeasure$slot']);
      if (name == null || name.trim().isEmpty) continue;
      ingredients.add(
        Ingredient(sourceSlot: slot, rawName: name, measure: measure),
      );
    }
    return Recipe._(
      id: _id(json),
      name: _text(json, 'strDrink', required: true)!,
      instructions: _text(json, 'strInstructions'),
      ingredients: ingredients,
      thumbnailUrl: _text(json, 'strDrinkThumb'),
      category: _text(json, 'strCategory'),
      glass: _text(json, 'strGlass'),
      alcoholic: _text(json, 'strAlcoholic'),
      sourceUrl: _text(json, 'strSource'),
      imageSource: _text(json, 'strImageSource'),
      imageAttribution: _text(json, 'strImageAttribution'),
      creativeCommonsConfirmed: _text(json, 'strCreativeCommonsConfirmed'),
    );
  }

  final String id;
  final String name;
  final String? instructions;
  final List<Ingredient> ingredients;
  final String? thumbnailUrl;
  final String? category;
  final String? glass;
  final String? alcoholic;
  final String? sourceUrl;
  final String? imageSource;
  final String? imageAttribution;
  final String? creativeCommonsConfirmed;
  Uri get attributionUrl => Uri.https('www.thecocktaildb.com', '/drink/$id');

  Map<String, dynamic> toJson() => {
    'idDrink': id,
    'strDrink': name,
    'strInstructions': instructions,
    'strDrinkThumb': thumbnailUrl,
    'strCategory': category,
    'strGlass': glass,
    'strAlcoholic': alcoholic,
    'strSource': sourceUrl,
    'strImageSource': imageSource,
    'strImageAttribution': imageAttribution,
    'strCreativeCommonsConfirmed': creativeCommonsConfirmed,
    for (var slot = 1; slot <= 15; slot++) 'strIngredient$slot': null,
    for (var slot = 1; slot <= 15; slot++) 'strMeasure$slot': null,
    for (final ingredient in ingredients)
      'strIngredient${ingredient.sourceSlot}': ingredient.rawName,
    for (final ingredient in ingredients)
      'strMeasure${ingredient.sourceSlot}': ingredient.measure.toJson(),
  };
}
