import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zest/features/collection/domain/collection_entry.dart';
import 'package:zest/features/collection/domain/memory_photo.dart';
import 'package:zest/features/collection/sync/http_sync_api.dart';
import 'package:zest/features/collection/sync/sync_contract.dart';
import 'package:zest/features/collection/sync/sync_exceptions.dart';

import '../../../support/fake_account_repository.dart';

void main() {
  final baseUrl = Uri.parse('http://127.0.0.1:3000/api/');

  EntryRecord sampleEntry() => EntryRecord(
    id: '0a1b2c3d4e5f60718293a4b5c6d7e8f9',
    kind: CollectionEntryKind.saved,
    sourceRecipeId: '98001',
    source: const {'idDrink': '98001', 'strDrink': 'Testbench Tonic'},
    variation: null,
    day: '2026-09-13',
    hasPhoto: false,
    photoUpdatedAt: null,
    createdAt: DateTime.utc(2026, 9, 13, 10),
    updatedAt: DateTime.utc(2026, 9, 13, 10),
    deleted: false,
    revision: 5,
  );

  test('pull sends the bearer token and parses the page', () async {
    final account = FakeAccountRepository(current: syntheticAccount());
    http.Request? captured;
    final api = HttpSyncApi(
      baseUrl: baseUrl,
      account: account,
      client: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'entries': [sampleEntry().toJson()..['revision'] = 5],
            'revision': 5,
            'hasMore': false,
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final page = await api.pull(since: 0);

    expect(page.entries, hasLength(1));
    expect(page.hasMore, isFalse);
    expect(
      captured!.headers['Authorization'],
      'Bearer ${account.sessionToken}',
    );
    expect(captured!.url.queryParameters['since'], '0');
  });

  test('putEntry sends JSON and returns the stored record', () async {
    final account = FakeAccountRepository(current: syntheticAccount());
    final api = HttpSyncApi(
      baseUrl: baseUrl,
      account: account,
      client: MockClient(
        (request) async => http.Response(
          jsonEncode(sampleEntry().toJson()..['revision'] = 6),
          200,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );

    final result = await api.putEntry(sampleEntry());
    expect(result.revision, 6);
  });

  test('putPhoto sends raw bytes with the photo Content-Type', () async {
    final account = FakeAccountRepository(current: syntheticAccount());
    final photo = MemoryPhoto.fromBytes(
      Uint8List.fromList(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0]),
    );
    http.Request? captured;
    final api = HttpSyncApi(
      baseUrl: baseUrl,
      account: account,
      client: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode(sampleEntry().toJson()..['revision'] = 7),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    await api.putPhoto(
      sampleEntry().id,
      photo,
      updatedAt: DateTime.utc(2026, 9, 13, 11),
    );

    expect(captured!.headers['content-type'], photo.mimeType);
    expect(captured!.bodyBytes, photo.bytes);
    expect(
      captured!.url.queryParameters['updatedAt'],
      '2026-09-13T11:00:00.000Z',
    );
  });

  test('getPhoto returns null on 404', () async {
    final account = FakeAccountRepository(current: syntheticAccount());
    final api = HttpSyncApi(
      baseUrl: baseUrl,
      account: account,
      client: MockClient((request) async => http.Response('', 404)),
    );

    expect(await api.getPhoto('missing'), isNull);
  });

  test('a 401 calls expireSession and throws SyncUnauthorizedException', () async {
    final account = FakeAccountRepository(current: syntheticAccount());
    final api = HttpSyncApi(
      baseUrl: baseUrl,
      account: account,
      client: MockClient((request) async => http.Response('', 401)),
    );

    await expectLater(
      api.pull(since: 0),
      throwsA(isA<SyncUnauthorizedException>()),
    );
    expect(account.currentAccount, isNull);
  });

  test('a transport failure throws SyncOfflineException', () async {
    final account = FakeAccountRepository(current: syntheticAccount());
    final api = HttpSyncApi(
      baseUrl: baseUrl,
      account: account,
      client: MockClient((request) async {
        throw http.ClientException('offline');
      }),
    );

    await expectLater(
      api.pull(since: 0),
      throwsA(isA<SyncOfflineException>()),
    );
  });

  test('a non-2xx, non-401 status throws SyncApiException', () async {
    final account = FakeAccountRepository(current: syntheticAccount());
    final api = HttpSyncApi(
      baseUrl: baseUrl,
      account: account,
      client: MockClient(
        (request) async => http.Response(
          jsonEncode({
            'error': {'code': 'not_found', 'message': 'gone'},
          }),
          404,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );

    await expectLater(
      api.deletePhoto('missing', updatedAt: DateTime.utc(2026, 9, 13)),
      throwsA(
        isA<SyncApiException>()
            .having((e) => e.statusCode, 'statusCode', 404)
            .having((e) => e.code, 'code', 'not_found'),
      ),
    );
  });
}
