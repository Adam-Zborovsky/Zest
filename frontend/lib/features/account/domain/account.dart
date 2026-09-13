/// A signed-in Zest account. Its [id] is the server's user id, which scopes
/// every synced entry and photo. See `docs/ACCOUNTS.md`.
final class Account {
  const Account({
    required this.id,
    required this.email,
    required this.createdAt,
  });

  factory Account.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final email = json['email'];
    final created = json['createdAt'];
    if (id is! String ||
        id.isEmpty ||
        email is! String ||
        AccountRules.normalizeEmail(email) != email ||
        created is! String) {
      throw const FormatException('Invalid account.');
    }
    final createdAt = DateTime.tryParse(created);
    if (createdAt == null) {
      throw const FormatException('Invalid account creation date.');
    }
    return Account(id: id, email: email, createdAt: createdAt.toUtc());
  }

  final String id;

  /// Always the normalized form (see [AccountRules.normalizeEmail]).
  final String email;
  final DateTime createdAt;

  Map<String, Object?> toJson() => {
    'id': id,
    'email': email,
    'createdAt': createdAt.toUtc().toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      other is Account &&
      other.id == id &&
      other.email == email &&
      other.createdAt.isAtSameMomentAs(createdAt);

  @override
  int get hashCode =>
      Object.hash(id, email, createdAt.millisecondsSinceEpoch);
}

/// Validation the client and server share, so the login form rejects exactly
/// what the server would. Keep in step with `docs/ACCOUNTS.md`.
abstract final class AccountRules {
  static const maxEmailLength = 254;

  /// Unicode code points, per NIST SP 800-63B; no composition rules.
  static const minPasswordLength = 10;
  static const maxPasswordLength = 128;

  static final _whitespace = RegExp(r'\s');

  /// Trimmed and lowercased, or null when it cannot be an email address:
  /// empty, over [maxEmailLength], not exactly one `@` with text on both
  /// sides, or containing whitespace.
  static String? normalizeEmail(String raw) {
    final email = raw.trim().toLowerCase();
    if (email.isEmpty || email.length > maxEmailLength) return null;
    if (email.contains(_whitespace)) return null;
    final at = email.indexOf('@');
    if (at <= 0 || at != email.lastIndexOf('@') || at == email.length - 1) {
      return null;
    }
    return email;
  }

  static bool isAcceptablePassword(String password) {
    final length = password.runes.length;
    return length >= minPasswordLength && length <= maxPasswordLength;
  }
}
