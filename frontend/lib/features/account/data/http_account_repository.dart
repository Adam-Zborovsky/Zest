import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/account.dart';
import 'account_repository.dart';

/// The `shared_preferences` key holding the signed-in account's JSON. Not
/// secret on its own; the session token lives in
/// [AccountSecureStorageKeys.token] instead. Add this to the
/// `SharedPreferencesWithCache` allowlist in `main()`.
abstract final class AccountPrefsKeys {
  static const account = 'zest.account';
}

/// The `flutter_secure_storage` key holding the bearer session token.
abstract final class AccountSecureStorageKeys {
  static const token = 'zest.session.token';
}

/// [AccountRepository] over the accounts HTTP API. See `docs/ACCOUNTS.md` for
/// the wire contract this implements.
///
/// Construct with [HttpAccountRepository.load], which reads the stored token
/// and account before the repository exists, so [currentAccount] and
/// [sessionToken] are synchronous from the moment it is constructed (the
/// invariant every [AccountRepository] keeps).
final class HttpAccountRepository implements AccountRepository {
  HttpAccountRepository._({
    required Uri baseUrl,
    required http.Client client,
    required SharedPreferencesWithCache prefs,
    required FlutterSecureStorage secureStorage,
    Account? account,
    String? token,
    Duration timeout = const Duration(seconds: 10),
  }) : _baseUrl = baseUrl,
       _client = client,
       _prefs = prefs,
       _secureStorage = secureStorage,
       _account = account,
       _token = token,
       _timeout = timeout;

  /// Loads any stored session before constructing the repository. Signed out
  /// unless both the token and the account decode successfully; a partial or
  /// corrupt pair is treated as signed out and the leftover is cleared.
  static Future<HttpAccountRepository> load({
    required Uri baseUrl,
    required SharedPreferencesWithCache prefs,
    http.Client? client,
    FlutterSecureStorage? secureStorage,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final storage = secureStorage ?? const FlutterSecureStorage();
    final token = await storage.read(key: AccountSecureStorageKeys.token);
    final accountJson = prefs.getString(AccountPrefsKeys.account);
    Account? account;
    if (accountJson != null) {
      try {
        account = Account.fromJson(
          jsonDecode(accountJson) as Map<String, Object?>,
        );
      } catch (_) {
        account = null;
      }
    }
    var effectiveToken = token;
    var effectiveAccount = account;
    if (effectiveToken == null || effectiveAccount == null) {
      effectiveToken = null;
      effectiveAccount = null;
      // Best-effort cleanup of an inconsistent stored pair.
      try {
        await storage.delete(key: AccountSecureStorageKeys.token);
      } catch (_) {}
      try {
        await prefs.remove(AccountPrefsKeys.account);
      } catch (_) {}
    }
    return HttpAccountRepository._(
      baseUrl: baseUrl,
      client: client ?? http.Client(),
      prefs: prefs,
      secureStorage: storage,
      account: effectiveAccount,
      token: effectiveToken,
      timeout: timeout,
    );
  }

  final Uri _baseUrl;
  final http.Client _client;
  final SharedPreferencesWithCache _prefs;
  final FlutterSecureStorage _secureStorage;
  final Duration _timeout;

  Account? _account;
  String? _token;

  @override
  Account? get currentAccount => _account;

  @override
  String? get sessionToken => _token;

  @override
  Future<Account> register({
    required String email,
    required String password,
  }) => _authenticate('auth/register', email: email, password: password);

  @override
  Future<Account> signIn({required String email, required String password}) =>
      _authenticate('auth/login', email: email, password: password);

  Future<Account> _authenticate(
    String path, {
    required String email,
    required String password,
  }) async {
    final normalized = AccountRules.normalizeEmail(email);
    if (normalized == null) {
      throw const AccountException(AccountFailure.invalidEmail);
    }
    if (!AccountRules.isAcceptablePassword(password)) {
      throw const AccountException(AccountFailure.weakPassword);
    }
    final response = await _send(
      'POST',
      path,
      body: {'email': normalized, 'password': password},
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _mapError(response);
    }
    final Map<String, Object?> decoded;
    try {
      decoded = jsonDecode(response.body) as Map<String, Object?>;
      final userJson = decoded['user'] as Map<String, Object?>;
      final sessionJson = decoded['session'] as Map<String, Object?>;
      final account = Account.fromJson(userJson);
      final token = sessionJson['token'];
      if (token is! String || token.isEmpty) {
        throw const FormatException('Invalid session token.');
      }
      await _storeSession(account, token);
      return account;
    } catch (error) {
      if (error is AccountException) rethrow;
      throw const AccountException(AccountFailure.server);
    }
  }

  Future<void> _storeSession(Account account, String token) async {
    try {
      await _secureStorage.write(
        key: AccountSecureStorageKeys.token,
        value: token,
      );
      await _prefs.setString(
        AccountPrefsKeys.account,
        jsonEncode(account.toJson()),
      );
    } catch (error) {
      // Leave the stored session unchanged: best-effort rollback of a
      // partial write, then surface as a plain failure.
      try {
        await _secureStorage.delete(key: AccountSecureStorageKeys.token);
      } catch (_) {}
      throw const AccountException(AccountFailure.server);
    }
    _account = account;
    _token = token;
  }

  @override
  Future<void> signOut() async {
    final token = _token;
    if (token != null) {
      try {
        await _send('POST', 'auth/logout', token: token);
      } catch (_) {
        // Sign-out always clears locally regardless of server reachability.
      }
    }
    await _clearSession();
  }

  @override
  Future<void> expireSession() => _clearSession();

  Future<void> _clearSession() async {
    _account = null;
    _token = null;
    try {
      await _secureStorage.delete(key: AccountSecureStorageKeys.token);
    } catch (_) {}
    try {
      await _prefs.remove(AccountPrefsKeys.account);
    } catch (_) {}
  }

  Future<http.Response> _send(
    String method,
    String path, {
    Map<String, Object?>? body,
    String? token,
  }) async {
    final uri = _baseUrl.resolve(path);
    try {
      final http.Response response;
      final headers = <String, String>{
        if (body != null) 'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };
      switch (method) {
        case 'POST':
          response = await _client
              .post(
                uri,
                headers: headers,
                body: body == null ? null : jsonEncode(body),
              )
              .timeout(_timeout);
        default:
          throw UnsupportedError('Unsupported method $method');
      }
      return response;
    } on TimeoutException {
      throw const AccountException(AccountFailure.unreachable);
    } on http.ClientException {
      throw const AccountException(AccountFailure.unreachable);
    } on SocketException {
      throw const AccountException(AccountFailure.unreachable);
    } on AccountException {
      rethrow;
    } catch (_) {
      throw const AccountException(AccountFailure.unreachable);
    }
  }

  AccountException _mapError(http.Response response) {
    String? code;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) {
        final error = decoded['error'];
        if (error is Map) code = error['code'] as String?;
      }
    } catch (_) {
      // Malformed error body; fall through to a status-code based mapping.
    }
    switch (response.statusCode) {
      case 401:
        return const AccountException(AccountFailure.invalidCredentials);
      case 409:
        return const AccountException(AccountFailure.emailTaken);
      case 429:
        return AccountException(
          AccountFailure.rateLimited,
          retryAfter: _retryAfter(response.headers['retry-after']),
        );
    }
    if (code == 'invalid_credentials') {
      return const AccountException(AccountFailure.invalidCredentials);
    }
    if (code == 'email_taken') {
      return const AccountException(AccountFailure.emailTaken);
    }
    return const AccountException(AccountFailure.server);
  }

  Duration? _retryAfter(String? value) {
    final seconds = int.tryParse(value?.trim() ?? '');
    return seconds == null || seconds < 0 ? null : Duration(seconds: seconds);
  }

  void close() => _client.close();
}
