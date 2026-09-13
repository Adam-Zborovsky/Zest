import '../domain/account.dart';

/// Why an account operation failed. Screens map each to plain copy; none of
/// them carries server text, tokens, or passwords.
enum AccountFailure {
  /// The email is not acceptable to [AccountRules.normalizeEmail].
  invalidEmail,

  /// The password is outside the [AccountRules] length bounds.
  weakPassword,

  /// Wrong email or password. Deliberately does not say which.
  invalidCredentials,

  /// Registration for an email that already has an account.
  emailTaken,

  /// The server returned 429; see [AccountException.retryAfter].
  rateLimited,

  /// The server could not be reached (no network, server off, timeout).
  unreachable,

  /// Anything else the server reported as a failure.
  server,
}

final class AccountException implements Exception {
  const AccountException(this.failure, {this.retryAfter});

  final AccountFailure failure;

  /// From `Retry-After` when [failure] is [AccountFailure.rateLimited].
  final Duration? retryAfter;

  @override
  String toString() => 'AccountException(${failure.name})';
}

/// The account seam that replaces M7's local profile. See
/// `docs/ACCOUNTS.md` for the wire contract.
///
/// Invariants every implementation keeps:
/// - [currentAccount] is non-null exactly while a session token is stored.
///   It is loaded before `runApp`, so reading it is synchronous.
/// - [register] and [signIn] validate locally first and throw
///   [AccountException] with [AccountFailure.invalidEmail] or
///   [AccountFailure.weakPassword] without a network call. On success they
///   store the token and the account before returning.
/// - Any failure throws [AccountException] and leaves the stored session
///   unchanged.
/// - [signOut] always clears the stored session, even when revoking it on the
///   server fails or the server is unreachable. It never deletes collection
///   data.
/// - [expireSession] clears the stored session without a network call. An
///   authenticated client calls it when the server answers 401.
abstract interface class AccountRepository {
  Account? get currentAccount;

  /// The bearer token for authenticated calls, or null when signed out.
  String? get sessionToken;

  Future<Account> register({required String email, required String password});

  Future<Account> signIn({required String email, required String password});

  Future<void> signOut();

  Future<void> expireSession();
}
