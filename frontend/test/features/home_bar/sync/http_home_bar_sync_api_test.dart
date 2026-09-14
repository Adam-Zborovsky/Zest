import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zest/features/home_bar/domain/home_bar_item.dart';
import 'package:zest/features/home_bar/sync/home_bar_sync_contract.dart';
import 'package:zest/features/home_bar/sync/http_home_bar_sync_api.dart';
import 'package:zest/features/collection/sync/sync_exceptions.dart';

import '../../../support/fake_account_repository.dart';

void main() {
  final baseUrl = Uri.parse('http://127.0.0.1:3000/api/');
  HomeBarRecord record({String ingredientId = 'lime juice'}) => HomeBarRecord(
    ingredientId: ingredientId,
    displayName: 'Lime Juice',
    location: HomeBarLocation.shopping,
    updatedAt: DateTime.utc(2026, 9, 14, 12),
    deleted: false,
  );

  test(
    'PUT encodes a spaced ingredient identity as one path segment',
    () async {
      http.Request? captured;
      final account = FakeAccountRepository(current: syntheticAccount());
      final api = HttpHomeBarSyncApi(
        baseUrl: baseUrl,
        client: MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode(record().toJson()..['revision'] = 1),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
        account: account,
      );

      await api.putItem(record());

      expect(captured!.url.path, '/api/bar-items/lime%20juice');
      expect(
        captured!.headers['Authorization'],
        'Bearer ${account.sessionToken}',
      );
      expect(jsonDecode(captured!.body)['ingredientId'], 'lime juice');
    },
  );

  test('pull parses the independent item page and sends its cursor', () async {
    http.Request? captured;
    final api = HttpHomeBarSyncApi(
      baseUrl: baseUrl,
      client: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'items': [record().toJson()..['revision'] = 8],
            'revision': 8,
            'hasMore': false,
          }),
          200,
        );
      }),
      account: FakeAccountRepository(current: syntheticAccount()),
    );

    final page = await api.pull(since: 7);
    expect(page.items.single.revision, 8);
    expect(captured!.url.queryParameters['since'], '7');
  });

  test('401 expires the account and transport failure is offline', () async {
    final account = FakeAccountRepository(current: syntheticAccount());
    final unauthorized = HttpHomeBarSyncApi(
      baseUrl: baseUrl,
      client: MockClient((_) async => http.Response('', 401)),
      account: account,
    );
    await expectLater(
      unauthorized.pull(since: 0),
      throwsA(isA<SyncUnauthorizedException>()),
    );
    expect(account.currentAccount, isNull);

    final offline = HttpHomeBarSyncApi(
      baseUrl: baseUrl,
      client: MockClient((_) async => throw http.ClientException('offline')),
      account: FakeAccountRepository(current: syntheticAccount()),
    );
    await expectLater(
      offline.pull(since: 0),
      throwsA(isA<SyncOfflineException>()),
    );
  });
}
