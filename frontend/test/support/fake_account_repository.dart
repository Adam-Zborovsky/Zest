import 'dart:math' as math;

import 'package:zest/features/account/data/account_repository.dart';
import 'package:zest/features/account/domain/account.dart';

/// An in-memory [AccountRepository] holding the same invariants as
/// [HttpAccountRepository], for widget and unit tests. A tiny in-process
/// "server" so [register]/[signIn] behave like the real accounts API
/// (email-taken, invalid-credentials) without a network.
final class FakeAccountRepository implements AccountRepository {
  FakeAccountRepository({
    Account? current,
    DateTime Function()? clock,
    String Function()? newId,
  }) : _current = current,
       _token = current == null ? null : 'fake-token-${current.id}',
       _clock = clock ?? DateTime.now,
       _newId = newId ?? _sequentialIds() {
    if (current != null) {
      _accountsByEmail[current.email] = current;
      _passwordsByEmail[current.email] = 'synthetic-pass';
    }
  }

  final DateTime Function() _clock;
  final String Function() _newId;

  Account? _current;
  String? _token;

  /// email -> password, standing in for the server's user table.
  final _passwordsByEmail = <String, String>{};
  final _accountsByEmail = <String, Account>{};

  /// When set, the next [register] or [signIn] call throws this instead of
  /// running normally.
  AccountException? failNext;

  @override
  Account? get currentAccount => _current;

  /// Test-only: force the signed-in account directly, bypassing
  /// register/signIn, for simulating multiple devices already signed into
  /// the same (or a different) account.
  set current(Account? value) {
    _current = value;
    _token = value == null ? null : 'fake-token-${value.id}';
  }

  @override
  String? get sessionToken => _token;

  @override
  Future<Account> register({
    required String email,
    required String password,
  }) async {
    final normalized = _validate(email, password);
    _throwIfFailing();
    if (_accountsByEmail.containsKey(normalized)) {
      throw const AccountException(AccountFailure.emailTaken);
    }
    final account = Account(
      id: _newId(),
      email: normalized,
      createdAt: _clock(),
    );
    _accountsByEmail[normalized] = account;
    _passwordsByEmail[normalized] = password;
    return _signInAs(account);
  }

  @override
  Future<Account> signIn({required String email, required String password}) async {
    final normalized = _validate(email, password);
    _throwIfFailing();
    final account = _accountsByEmail[normalized];
    if (account == null || _passwordsByEmail[normalized] != password) {
      throw const AccountException(AccountFailure.invalidCredentials);
    }
    return _signInAs(account);
  }

  Future<Account> _signInAs(Account account) async {
    _current = account;
    _token = 'fake-token-${account.id}';
    return account;
  }

  String _validate(String email, String password) {
    final normalized = AccountRules.normalizeEmail(email);
    if (normalized == null) {
      throw const AccountException(AccountFailure.invalidEmail);
    }
    if (!AccountRules.isAcceptablePassword(password)) {
      throw const AccountException(AccountFailure.weakPassword);
    }
    return normalized;
  }

  void _throwIfFailing() {
    final failure = failNext;
    if (failure == null) return;
    failNext = null;
    throw failure;
  }

  @override
  Future<void> signOut() async {
    _current = null;
    _token = null;
  }

  @override
  Future<void> expireSession() async {
    _current = null;
    _token = null;
  }

  /// Registers an account directly (bypassing sign-in) so tests can seed a
  /// known password for later `signIn` calls.
  Account seedAccount({required String email, required String password}) {
    final normalized = AccountRules.normalizeEmail(email)!;
    final account = Account(
      id: _newId(),
      email: normalized,
      createdAt: _clock(),
    );
    _accountsByEmail[normalized] = account;
    _passwordsByEmail[normalized] = password;
    return account;
  }

  static String Function() _sequentialIds() {
    var next = 0;
    return () => 'account-${++next}';
  }
}

/// A synthetic signed-in account for tests that start inside the app.
Account syntheticAccount({String email = 'sam@example.test'}) => Account(
  id: 'account-test',
  email: email,
  createdAt: DateTime.utc(2026, 9, 1),
);

/// A random 128-bit identifier in lowercase hex, matching the shape used
/// elsewhere for local-only test ids.
String randomTestId([math.Random? random]) {
  final source = random ?? math.Random.secure();
  return [
    for (var i = 0; i < 16; i++)
      source.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ].join();
}
