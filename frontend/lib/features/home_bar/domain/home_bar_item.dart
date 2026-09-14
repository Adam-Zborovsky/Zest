import '../../discovery/domain/ingredient.dart';

/// The two mutually exclusive places an ingredient can be in a home bar.
enum HomeBarLocation { stocked, shopping }

/// A durable, account-owned inventory or shopping-list record.
///
/// [ingredientId] is always the normalized identity. [displayName] is the
/// catalog spelling selected when the person last changed this record; unlike
/// provider data, it is personal data and travels through sync unchanged.
final class HomeBarItem {
  static const maxTextLength = 120;

  HomeBarItem({
    required String ingredientId,
    required String displayName,
    required this.location,
    required this.updatedAt,
    this.deleted = false,
    this.revision,
  }) : ingredientId = normalizeIngredientName(ingredientId),
       displayName = _displayName(displayName) {
    if (_hasControlCharacter(ingredientId) ||
        this.ingredientId != ingredientId ||
        this.ingredientId.length > maxTextLength) {
      throw ArgumentError.value(
        ingredientId,
        'ingredientId',
        'Must be a normalized ingredient identity.',
      );
    }
  }

  final String ingredientId;
  final String displayName;
  final HomeBarLocation location;
  final DateTime updatedAt;
  final bool deleted;

  /// Server assigned and absent from client mutation bodies.
  final int? revision;

  /// Mirrors the backend's accepted ingredient-id syntax before a local
  /// mutation can create a dirty record. The identity must later be sent in
  /// normalized form, but add/move callers deliberately provide catalog
  /// display spellings here.
  static String normalizeIngredientId(String value) {
    if (_hasControlCharacter(value)) {
      throw const FormatException(
        'Ingredient name contains a control character.',
      );
    }
    final normalized = normalizeIngredientName(value);
    if (normalized.length > maxTextLength) {
      throw const FormatException('Ingredient name is too long.');
    }
    return normalized;
  }

  static String _displayName(String value) {
    final trimmed = value.trim();
    if (_hasControlCharacter(value) ||
        trimmed.isEmpty ||
        trimmed.length > maxTextLength) {
      throw ArgumentError.value(
        value,
        'displayName',
        'Must contain 1 to $maxTextLength UTF-16 code units.',
      );
    }
    return trimmed;
  }

  static bool _hasControlCharacter(String value) =>
      RegExp(r'[\u0000-\u001F\u007F]').hasMatch(value);

  @override
  bool operator ==(Object other) =>
      other is HomeBarItem &&
      other.ingredientId == ingredientId &&
      other.displayName == displayName &&
      other.location == location &&
      other.updatedAt.isAtSameMomentAs(updatedAt) &&
      other.deleted == deleted &&
      other.revision == revision;

  @override
  int get hashCode => Object.hash(
    ingredientId,
    displayName,
    location,
    updatedAt.millisecondsSinceEpoch,
    deleted,
    revision,
  );
}
