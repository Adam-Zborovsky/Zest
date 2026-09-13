/// The local-first identity: a profile kept only on this device. There is no
/// account, credential, or sync behind it; a real provider can replace the
/// `AuthRepository` implementation later without changing this shape.
class LocalProfile {
  LocalProfile({
    required this.id,
    required String? displayName,
    required this.createdAt,
  }) : displayName = normalizeDisplayName(displayName) {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'must not be empty');
    }
  }

  factory LocalProfile.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final name = json['displayName'];
    final created = json['createdAt'];
    if (id is! String || (name != null && name is! String) || created is! String) {
      throw const FormatException('Malformed stored profile');
    }
    final createdAt = DateTime.tryParse(created);
    if (createdAt == null) {
      throw const FormatException('Malformed stored profile date');
    }
    try {
      return LocalProfile(
        id: id,
        displayName: name as String?,
        createdAt: createdAt,
      );
    } on ArgumentError {
      throw const FormatException('Invalid stored profile');
    }
  }

  /// Matches the login field's `maxLength`, counted in Unicode code points.
  static const maxNameLength = 40;

  final String id;

  /// Trimmed, never empty; null when the person gave no name.
  final String? displayName;
  final DateTime createdAt;

  /// Trims [raw]; blank becomes null. Throws [ArgumentError] when the trimmed
  /// name exceeds [maxNameLength] code points, rather than silently cutting it.
  static String? normalizeDisplayName(String? raw) {
    final trimmed = raw?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    if (trimmed.runes.length > maxNameLength) {
      throw ArgumentError.value(
        raw,
        'displayName',
        'must be at most $maxNameLength characters',
      );
    }
    return trimmed;
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'displayName': displayName,
    'createdAt': createdAt.toUtc().toIso8601String(),
  };

  LocalProfile withDisplayName(String? name) =>
      LocalProfile(id: id, displayName: name, createdAt: createdAt);

  @override
  bool operator ==(Object other) =>
      other is LocalProfile &&
      other.id == id &&
      other.displayName == displayName &&
      other.createdAt.isAtSameMomentAs(createdAt);

  @override
  int get hashCode =>
      Object.hash(id, displayName, createdAt.millisecondsSinceEpoch);
}
