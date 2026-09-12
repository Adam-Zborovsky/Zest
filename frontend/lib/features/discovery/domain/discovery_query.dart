/// The supported, explicit discovery endpoint selection.
enum DiscoveryMode { name, ingredient, letter }

/// A validated discovery request suitable for routing and provider families.
final class DiscoveryQuery {
  factory DiscoveryQuery({required DiscoveryMode mode, required String value}) {
    final trimmed = value.trim();
    switch (mode) {
      case DiscoveryMode.name:
      case DiscoveryMode.ingredient:
        if (trimmed.isEmpty) {
          throw ArgumentError.value(value, 'value', 'Must not be blank.');
        }
      case DiscoveryMode.letter:
        if (!RegExp(r'^[A-Za-z]$').hasMatch(trimmed)) {
          throw ArgumentError.value(
            value,
            'value',
            'Must be one ASCII letter.',
          );
        }
        return DiscoveryQuery._(mode, trimmed.toLowerCase());
    }
    return DiscoveryQuery._(mode, trimmed);
  }

  const DiscoveryQuery._(this.mode, this.value);

  final DiscoveryMode mode;
  final String value;

  Uri get uri =>
      Uri(path: '/discover', queryParameters: {'mode': mode.name, 'q': value});

  /// Returns null for a route with no discovery selection. Malformed selection
  /// parameters are rejected without including route content in the error.
  static DiscoveryQuery? fromUri(Uri uri) {
    final modes = uri.queryParametersAll['mode'];
    final queries = uri.queryParametersAll['q'];
    if ((modes == null || modes.isEmpty) &&
        (queries == null || queries.isEmpty)) {
      return null;
    }
    if (modes == null ||
        modes.length != 1 ||
        queries == null ||
        queries.length != 1) {
      throw const FormatException('Invalid discovery selection.');
    }
    final modeValue = modes.single;
    final queryValue = queries.single;
    final mode = DiscoveryMode.values.where((mode) => mode.name == modeValue);
    if (mode.length != 1) {
      throw const FormatException('Invalid discovery selection.');
    }
    try {
      return DiscoveryQuery(mode: mode.single, value: queryValue);
    } on ArgumentError {
      throw const FormatException('Invalid discovery selection.');
    }
  }

  @override
  bool operator ==(Object other) =>
      other is DiscoveryQuery && other.mode == mode && other.value == value;

  @override
  int get hashCode => Object.hash(mode, value);
}
