import 'dart:convert';

import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:zest/features/account/data/account_repository.dart';
import 'package:zest/features/account/data/http_account_repository.dart';

/// A minimal in-memory `FlutterSecureStoragePlatform`, mirroring the pattern
/// `InMemorySharedPreferencesAsync` uses for `shared_preferences` — this
/// package ships no such fake, so this test provides one.
class _InMemorySecureStorage extends FlutterSecureStoragePlatform {
  final _values = <String, String>{};

  @override
  Future<void> write({
    required String key,
    required String value,
    required Map<String, String> options,
  }) async {
    _values[key] = value;
  }

  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) async => _values[key];

  @override
  Future<void> delete({
    required String key,
    required Map<String, String> options,
  }) async => _values.remove(key);

  @override
  Future<bool> containsKey({
    required String key,
    required Map<String, String> options,
  }) async => _values.containsKey(key);

  @override
  Future<Map<String, String>> readAll({required Map<String, String> options}) async =>
      Map.unmodifiable(_values);

  @override
  Future<void> deleteAll({required Map<String, String> options}) async =>
      _values.clear();
}

void main() {
  late _InMemorySecureStorage secureStorage;
  late InMemorySharedPreferencesAsync prefsPlatform;
  final baseUrl = Uri.parse('http://127.0.0.1:3000/api/');

  setUp(() {
    secureStorage = _InMemorySecureStorage();
    FlutterSecureStoragePlatform.instance = secureStorage;
    prefsPlatform = InMemorySharedPreferencesAsync.empty();
    SharedPreferencesAsyncPlatform.instance = prefsPlatform;
  });

  Future<SharedPreferencesWithCache> prefs() => SharedPreferencesWithCache.create(
    cacheOptions: const SharedPreferencesWithCacheOptions(
      allowList: {AccountPrefsKeys.account},
    ),
  );

  http.Client jsonClient(
    int status,
    Object body, {
    Map<String, String>? headers,
  }) => MockClient(
    (request) async => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json', ...?headers},
    ),
  );

  Map<String, Object?> sessionBody({String email = 'sam@example.test'}) => {
    'user': {
      'id': 'user-1',
      'email': email,
      'createdAt': '2026-09-13T10:00:00.000Z',
    },
    'session': {
      'token': 'c3ludGhldGljLXRva2VuLW5vdC1hLXJlYWwtb25l',
      'expiresAt': '2026-10-13T10:00:00.000Z',
    },
  };

  test('starts signed out when nothing is stored', () async {
    final repo = await HttpAccountRepository.load(
      baseUrl: baseUrl,
      prefs: await prefs(),
    );
    expect(repo.currentAccount, isNull);
    expect(repo.sessionToken, isNull);
  });

  test('register validates locally before any network call', () async {
    var called = false;
    final repo = await HttpAccountRepository.load(
      baseUrl: baseUrl,
      prefs: await prefs(),
      client: MockClient((request) async {
        called = true;
        return http.Response('{}', 200);
      }),
    );

    await expectLater(
      repo.register(email: 'not-an-email', password: 'longenoughpass'),
      throwsA(
        isA<AccountException>().having(
          (e) => e.failure,
          'failure',
          AccountFailure.invalidEmail,
        ),
      ),
    );
    await expectLater(
      repo.register(email: 'sam@example.test', password: 'short'),
      throwsA(
        isA<AccountException>().having(
          (e) => e.failure,
          'failure',
          AccountFailure.weakPassword,
        ),
      ),
    );
    expect(called, isFalse);
  });

  test('register stores the token and account on success', () async {
    final repo = await HttpAccountRepository.load(
      baseUrl: baseUrl,
      prefs: await prefs(),
      client: jsonClient(201, sessionBody()),
    );

    final account = await repo.register(
      email: 'Sam@Example.test',
      password: 'longenoughpass',
    );

    expect(account.email, 'sam@example.test');
    expect(repo.currentAccount, account);
    expect(repo.sessionToken, isNotEmpty);
    expect(secureStorage.readAll(options: const {}), completion(isNotEmpty));
  });

  test('signIn maps 401 to invalidCredentials', () async {
    final repo = await HttpAccountRepository.load(
      baseUrl: baseUrl,
      prefs: await prefs(),
      client: jsonClient(401, {
        'error': {'code': 'invalid_credentials', 'message': 'nope'},
      }),
    );

    await expectLater(
      repo.signIn(email: 'sam@example.test', password: 'longenoughpass'),
      throwsA(
        isA<AccountException>().having(
          (e) => e.failure,
          'failure',
          AccountFailure.invalidCredentials,
        ),
      ),
    );
    expect(repo.currentAccount, isNull);
  });

  test('register maps 409 to emailTaken', () async {
    final repo = await HttpAccountRepository.load(
      baseUrl: baseUrl,
      prefs: await prefs(),
      client: jsonClient(409, {
        'error': {'code': 'email_taken', 'message': 'taken'},
      }),
    );

    await expectLater(
      repo.register(email: 'sam@example.test', password: 'longenoughpass'),
      throwsA(
        isA<AccountException>().having(
          (e) => e.failure,
          'failure',
          AccountFailure.emailTaken,
        ),
      ),
    );
  });

  test('a 429 maps to rateLimited with retryAfter', () async {
    final repo = await HttpAccountRepository.load(
      baseUrl: baseUrl,
      prefs: await prefs(),
      client: jsonClient(429, {
        'error': {'code': 'rate_limited', 'message': 'slow down'},
      }, headers: {'retry-after': '30'}),
    );

    await expectLater(
      repo.signIn(email: 'sam@example.test', password: 'longenoughpass'),
      throwsA(
        isA<AccountException>()
            .having((e) => e.failure, 'failure', AccountFailure.rateLimited)
            .having(
              (e) => e.retryAfter,
              'retryAfter',
              const Duration(seconds: 30),
            ),
      ),
    );
  });

  test('a transport failure maps to unreachable', () async {
    final repo = await HttpAccountRepository.load(
      baseUrl: baseUrl,
      prefs: await prefs(),
      client: MockClient((request) async {
        throw http.ClientException('connection refused');
      }),
    );

    await expectLater(
      repo.signIn(email: 'sam@example.test', password: 'longenoughpass'),
      throwsA(
        isA<AccountException>().having(
          (e) => e.failure,
          'failure',
          AccountFailure.unreachable,
        ),
      ),
    );
  });

  test('signOut always clears locally, even when the server call fails', () async {
    final calls = <String>[];
    final repo = await HttpAccountRepository.load(
      baseUrl: baseUrl,
      prefs: await prefs(),
      client: MockClient((request) async {
        calls.add(request.url.path);
        if (request.url.path.endsWith('auth/register')) {
          return http.Response(
            jsonEncode(sessionBody()),
            201,
            headers: {'content-type': 'application/json'},
          );
        }
        throw http.ClientException('offline');
      }),
    );
    await repo.register(email: 'sam@example.test', password: 'longenoughpass');
    expect(repo.currentAccount, isNotNull);

    await repo.signOut();

    expect(repo.currentAccount, isNull);
    expect(repo.sessionToken, isNull);
  });

  test('expireSession clears locally without a network call', () async {
    var networkCalls = 0;
    final repo = await HttpAccountRepository.load(
      baseUrl: baseUrl,
      prefs: await prefs(),
      client: MockClient((request) async {
        networkCalls++;
        return http.Response(
          jsonEncode(sessionBody()),
          201,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    await repo.register(email: 'sam@example.test', password: 'longenoughpass');
    expect(networkCalls, 1);

    await repo.expireSession();

    expect(repo.currentAccount, isNull);
    expect(networkCalls, 1);
  });

  test('a relaunch over the same backing stays signed in', () async {
    final sharedPrefs = await prefs();
    final repo = await HttpAccountRepository.load(
      baseUrl: baseUrl,
      prefs: sharedPrefs,
      client: jsonClient(201, sessionBody()),
    );
    final account = await repo.register(
      email: 'sam@example.test',
      password: 'longenoughpass',
    );

    final relaunched = await HttpAccountRepository.load(
      baseUrl: baseUrl,
      prefs: await prefs(),
    );

    expect(relaunched.currentAccount, account);
    expect(relaunched.sessionToken, repo.sessionToken);
  });
}
