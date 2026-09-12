import 'dart:math' as math;

import '../../discovery/domain/recipe.dart';

/// What a collection entry is. A saved entry keeps the source recipe exactly
/// as it was saved; a variation is the person's own editable version and is
/// always presented as "your variation of" its source — never as the source.
enum CollectionEntryKind { saved, variation }

/// One ingredient line of a personal variation. Free text on purpose: a
/// variation is the person's own wording, not a provider record, so it is
/// never normalized into catalog identities or matched as availability.
final class VariationIngredient {
  VariationIngredient({required String name, String measure = ''})
    : name = name.trim(),
      measure = measure.trim() {
    if (this.name.isEmpty) {
      throw const FormatException('A variation ingredient needs a name.');
    }
    if (this.name.length > maxNameLength) {
      throw const FormatException('A variation ingredient name is too long.');
    }
    if (this.measure.length > maxMeasureLength) {
      throw const FormatException('A variation measure is too long.');
    }
  }

  factory VariationIngredient.fromJson(Map<String, dynamic> json) {
    final name = json['name'];
    final measure = json['measure'];
    if (name is! String || (measure != null && measure is! String)) {
      throw const FormatException('Invalid variation ingredient.');
    }
    return VariationIngredient(name: name, measure: measure as String? ?? '');
  }

  static const maxNameLength = 120;
  static const maxMeasureLength = 80;

  final String name;

  /// Empty when the person gave no measure.
  final String measure;

  Map<String, dynamic> toJson() => {'name': name, 'measure': measure};

  @override
  bool operator ==(Object other) =>
      other is VariationIngredient &&
      other.name == name &&
      other.measure == measure;

  @override
  int get hashCode => Object.hash(name, measure);
}

/// The editable content of a personal variation: a full copy the person may
/// change freely. Validated on construction so no invalid variation can be
/// stored.
final class VariationDetails {
  VariationDetails({
    required String name,
    required List<VariationIngredient> ingredients,
    String method = '',
    String notes = '',
  }) : name = name.trim(),
       ingredients = List.unmodifiable(ingredients),
       method = method.trim(),
       notes = notes.trim() {
    if (this.name.isEmpty) {
      throw const FormatException('A variation needs a name.');
    }
    if (this.name.length > maxNameLength) {
      throw const FormatException('A variation name is too long.');
    }
    if (this.ingredients.length > maxIngredients) {
      throw const FormatException('A variation has too many ingredients.');
    }
    if (this.method.length > maxMethodLength) {
      throw const FormatException('A variation method is too long.');
    }
    if (this.notes.length > maxNotesLength) {
      throw const FormatException('Variation notes are too long.');
    }
  }

  /// A starting draft copied from the source recipe: its name, its
  /// ingredients with measures as the source gives them, and its method.
  factory VariationDetails.fromSource(Recipe source) => VariationDetails(
    name: _clip(source.name, maxNameLength),
    ingredients: [
      for (final ingredient in source.ingredients.take(maxIngredients))
        VariationIngredient(
          name: _clip(ingredient.name, VariationIngredient.maxNameLength),
          measure: _clip(
            ingredient.measure.display ?? '',
            VariationIngredient.maxMeasureLength,
          ),
        ),
    ],
    method: _clip(source.instructions ?? '', maxMethodLength),
  );

  factory VariationDetails.fromJson(Map<String, dynamic> json) {
    final name = json['name'];
    final ingredients = json['ingredients'];
    final method = json['method'];
    final notes = json['notes'];
    if (name is! String ||
        ingredients is! List ||
        method is! String ||
        notes is! String) {
      throw const FormatException('Invalid variation details.');
    }
    return VariationDetails(
      name: name,
      ingredients: [
        for (final item in ingredients)
          if (item is Map<String, dynamic>)
            VariationIngredient.fromJson(item)
          else
            throw const FormatException('Invalid variation ingredient.'),
      ],
      method: method,
      notes: notes,
    );
  }

  static const maxNameLength = 120;
  static const maxIngredients = 30;
  static const maxMethodLength = 8000;
  static const maxNotesLength = 4000;

  final String name;
  final List<VariationIngredient> ingredients;
  final String method;
  final String notes;

  Map<String, dynamic> toJson() => {
    'name': name,
    'ingredients': [for (final ingredient in ingredients) ingredient.toJson()],
    'method': method,
    'notes': notes,
  };

  @override
  bool operator ==(Object other) =>
      other is VariationDetails &&
      other.name == name &&
      other.method == method &&
      other.notes == notes &&
      _listEquals(other.ingredients, ingredients);

  @override
  int get hashCode =>
      Object.hash(name, method, notes, Object.hashAll(ingredients));
}

/// One entry in the person's private collection.
///
/// [source] is a snapshot of the recipe taken when the entry was created, so
/// the entry stays readable offline and never changes when the catalog does.
/// It is kept byte-for-byte as the source gave it; a variation's edits live
/// only in [variation].
final class CollectionEntry {
  const CollectionEntry._({
    required this.id,
    required this.kind,
    required this.source,
    required this.createdAt,
    required this.updatedAt,
    required this.variation,
    required this.hasPhoto,
  });

  factory CollectionEntry.saved({
    required String id,
    required Recipe source,
    required DateTime createdAt,
    DateTime? updatedAt,
    bool hasPhoto = false,
  }) => CollectionEntry._(
    id: id,
    kind: CollectionEntryKind.saved,
    source: source,
    createdAt: createdAt,
    updatedAt: updatedAt ?? createdAt,
    variation: null,
    hasPhoto: hasPhoto,
  );

  factory CollectionEntry.variation({
    required String id,
    required Recipe source,
    required VariationDetails details,
    required DateTime createdAt,
    DateTime? updatedAt,
    bool hasPhoto = false,
  }) => CollectionEntry._(
    id: id,
    kind: CollectionEntryKind.variation,
    source: source,
    createdAt: createdAt,
    updatedAt: updatedAt ?? createdAt,
    variation: details,
    hasPhoto: hasPhoto,
  );

  final String id;
  final CollectionEntryKind kind;
  final Recipe source;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Present exactly when [kind] is [CollectionEntryKind.variation].
  final VariationDetails? variation;
  final bool hasPhoto;

  String get sourceRecipeId => source.id;
  bool get isVariation => kind == CollectionEntryKind.variation;

  /// The name to show: the person's variation name, or the source name.
  String get displayName => variation?.name ?? source.name;

  CollectionEntry copyWith({
    VariationDetails? variation,
    bool? hasPhoto,
    DateTime? updatedAt,
  }) {
    if (variation != null && !isVariation) {
      throw StateError('A saved recipe has no variation details to replace.');
    }
    return CollectionEntry._(
      id: id,
      kind: kind,
      source: source,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      variation: variation ?? this.variation,
      hasPhoto: hasPhoto ?? this.hasPhoto,
    );
  }
}

/// A random 128-bit identifier in lowercase hex. Local-only ids: entries
/// never sync anywhere, so no coordination is needed.
String newCollectionEntryId([math.Random? random]) {
  final source = random ?? math.Random.secure();
  return [
    for (var i = 0; i < 16; i++)
      source.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ].join();
}

String _clip(String value, int max) {
  final trimmed = value.trim();
  return trimmed.length <= max ? trimmed : trimmed.substring(0, max);
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
