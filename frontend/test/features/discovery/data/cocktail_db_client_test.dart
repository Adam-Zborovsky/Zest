import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zest/core/network/cocktail_api_exception.dart';
import 'package:zest/features/discovery/data/cocktail_db_client.dart';

void main() {
  group('CocktailDbClient', () {
    test(
      'builds the lookup.php gateway endpoint with encoded query values and no key',
      () async {
        final urls = <Uri>[];
        final client = CocktailDbClient(
          baseUrl: 'https://gateway.example.invalid/api/cocktails/',
          client: MockClient((request) async {
            urls.add(request.url);
            return _jsonResponse({
              'drinks': [_full(id: '42')],
            });
          }),
        );

        await client.lookupRecipe(' 42 ');

        expect(urls.single.path, '/api/cocktails/lookup.php');
        expect(urls.single.host, 'gateway.example.invalid');
        expect(urls.single.queryParameters, {'i': '42'});
      },
    );

    test('uses the local gateway by default, never a provider key', () async {
      late Uri url;
      final client = CocktailDbClient(
        client: MockClient((request) async {
          url = request.url;
          return _jsonResponse({
            'drinks': [_full(id: '42')],
          });
        }),
      );
      await client.lookupRecipe('42');
      expect(url.toString(), 'http://127.0.0.1:3000/api/cocktails/lookup.php?i=42');
    });

    test('returns null when the gateway has no match', () async {
      final client = CocktailDbClient(
        client: MockClient((_) async => _jsonResponse({'drinks': null})),
      );
      expect(await client.lookupRecipe('42'), isNull);
    });

    test('rejects invalid input before making a request', () async {
      var calls = 0;
      final client = CocktailDbClient(
        client: MockClient((_) async {
          calls++;
          return _jsonResponse({'drinks': []});
        }),
      );
      expect(() => client.lookupRecipe('x42'), throwsArgumentError);
      expect(() => client.lookupRecipe(''), throwsArgumentError);
      expect(calls, 0);
    });

    test('rejects unsafe gateway configuration without echoing it', () {
      expect(
        () => CocktailDbClient(baseUrl: 'https://secret:key@example.invalid/'),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.toString(),
            'safe error',
            isNot(contains('secret:key')),
          ),
        ),
      );
    });

    test(
      'maps malformed payloads and schema failures to invalidResponse',
      () async {
        final responses = <Object>[
          {'other': []},
          {'drinks': {}},
          {
            'drinks': [_summary()],
          },
          {
            'drinks': [_full(), _full()],
          },
          {
            'drinks': [_full(id: '43')],
          },
        ];
        var index = 0;
        final client = CocktailDbClient(
          client: MockClient((_) async => _jsonResponse(responses[index++])),
        );
        for (var i = 0; i < responses.length; i++) {
          await expectLater(
            client.lookupRecipe('42'),
            _throwsKind(CocktailApiErrorKind.invalidResponse),
          );
        }
      },
    );

    test(
      'maps HTTP failures and rate limits with their safe metadata',
      () async {
        final httpFailure = CocktailDbClient(
          client: MockClient((_) async => http.Response('', 500)),
        );
        await expectLater(
          httpFailure.lookupRecipe('1'),
          _throwsKind(CocktailApiErrorKind.http),
        );
        final limited = CocktailDbClient(
          client: MockClient(
            (_) async => http.Response('', 429, headers: {'retry-after': '7'}),
          ),
        );
        await expectLater(
          limited.lookupRecipe('2'),
          throwsA(
            isA<CocktailApiException>()
                .having(
                  (error) => error.kind,
                  'kind',
                  CocktailApiErrorKind.rateLimited,
                )
                .having((error) => error.statusCode, 'status', 429)
                .having(
                  (error) => error.retryAfter,
                  'retry-after',
                  const Duration(seconds: 7),
                ),
          ),
        );
      },
    );

    test('redacts URI-bearing transport failures', () async {
      final network = CocktailDbClient(
        client: MockClient(
          (_) => throw http.ClientException(
            'syntheticsecret',
            Uri.parse('https://example.invalid/syntheticsecret'),
          ),
        ),
      );
      await expectLater(
        network.lookupRecipe('1'),
        _throwsKind(CocktailApiErrorKind.network),
      );
      try {
        await network.lookupRecipe('2');
      } catch (error) {
        expect(error.toString(), isNot(contains('secret-key')));
        expect(error.toString(), isNot(contains('syntheticsecret')));
        expect(error.toString(), isNot(contains('example.invalid')));
      }
    });

    test(
      'disables redirects and maps redirect responses as HTTP failures',
      () async {
        late http.Request request;
        final client = CocktailDbClient(
          client: MockClient((received) async {
            request = received;
            return http.Response('', 302);
          }),
        );
        await expectLater(
          client.lookupRecipe('1'),
          _throwsKind(CocktailApiErrorKind.http),
        );
        expect(request.followRedirects, isFalse);
        expect(request.maxRedirects, 0);
      },
    );

    test('bounds bodies and maps stream failures to typed errors', () async {
      final oversized = CocktailDbClient(
        maxResponseBytes: 8,
        client: MockClient((_) async => http.Response('0123456789', 200)),
      );
      await expectLater(
        oversized.lookupRecipe('1'),
        _throwsKind(CocktailApiErrorKind.invalidResponse),
      );
      final failedStream = CocktailDbClient(
        client: MockClient.streaming(
          (_, _) async => http.StreamedResponse(
            Stream<List<int>>.error(http.ClientException('syntheticsecret')),
            200,
          ),
        ),
      );
      await expectLater(
        failedStream.lookupRecipe('2'),
        _throwsKind(CocktailApiErrorKind.network),
      );
    });

    test(
      'caches successes including empty responses, expires entries, and evicts LRU',
      () async {
        var calls = 0;
        var clock = DateTime(2026);
        final client = CocktailDbClient(
          cacheTtl: const Duration(minutes: 1),
          maxCacheEntries: 2,
          now: () => clock,
          client: MockClient((request) async {
            calls++;
            final id = request.url.queryParameters['i'];
            return _jsonResponse({
              'drinks': id == '9' ? null : [_full(id: id!)],
            });
          }),
        );
        await client.lookupRecipe('1');
        await client.lookupRecipe('2');
        await client.lookupRecipe('1'); // 1 becomes most recently used
        await client.lookupRecipe('3'); // 2 evicted
        await client.lookupRecipe('2');
        await client.lookupRecipe('9');
        await client.lookupRecipe('9');
        expect(calls, 5);
        clock = clock.add(const Duration(minutes: 1));
        await client.lookupRecipe('9');
        expect(calls, 6);
      },
    );

    test('treats zero TTL as immediately expired', () async {
      var calls = 0;
      final client = CocktailDbClient(
        cacheTtl: Duration.zero,
        client: MockClient((_) async {
          calls++;
          return _jsonResponse({
            'drinks': [_full(id: '1')],
          });
        }),
      );
      final recipe = await client.lookupRecipe('1');
      expect(recipe?.id, '1');
      await client.lookupRecipe('1');
      expect(calls, 2);
    });

    test('rejects invalid runtime settings', () {
      expect(
        () => CocktailDbClient(cacheTtl: const Duration(microseconds: -1)),
        throwsArgumentError,
      );
      expect(() => CocktailDbClient(maxCacheEntries: 0), throwsArgumentError);
      expect(
        () => CocktailDbClient(requestTimeout: Duration.zero),
        throwsArgumentError,
      );
      expect(() => CocktailDbClient(maxResponseBytes: 0), throwsArgumentError);
    });

    test(
      'deduplicates in-flight requests and does not cache failures',
      () async {
        final gate = Completer<http.Response>();
        var calls = 0;
        final client = CocktailDbClient(
          client: MockClient((_) {
            calls++;
            if (calls == 1) return gate.future;
            return Future.value(
              _jsonResponse({
                'drinks': [_full(id: '1')],
              }),
            );
          }),
        );
        final first = client.lookupRecipe('1');
        final second = client.lookupRecipe('1');
        gate.complete(
          _jsonResponse({
            'drinks': [_full(id: '1')],
          }),
        );
        await Future.wait([first, second]);
        expect(calls, 1);

        final failing = CocktailDbClient(
          client: MockClient((_) async {
            calls++;
            if (calls == 2) return http.Response('bad', 200);
            return _jsonResponse({
              'drinks': [_full(id: '2')],
            });
          }),
        );
        await expectLater(
          failing.lookupRecipe('2'),
          _throwsKind(CocktailApiErrorKind.invalidResponse),
        );
        await failing.lookupRecipe('2');
        expect(calls, 3);
      },
    );

    test(
      'timeout and close abort active requests without closing injected client',
      () async {
        final client = _AbortAwareClient();
        final api = CocktailDbClient(
          client: client,
          requestTimeout: const Duration(milliseconds: 1),
        );
        await expectLater(
          api.lookupRecipe('1'),
          _throwsKind(CocktailApiErrorKind.timeout),
        );

        final active = CocktailDbClient(client: client);
        final pending = active.lookupRecipe('2');
        await Future<void>.delayed(Duration.zero);
        active.close();
        await expectLater(pending, _throwsKind(CocktailApiErrorKind.closed));
        api.close();
        expect(client.wasClosed, isFalse);
        await expectLater(
          api.lookupRecipe('3'),
          _throwsKind(CocktailApiErrorKind.closed),
        );
      },
    );

    test(
      'times out and closes non-cooperative clients, and rejects late success',
      () async {
        final timeoutClient = _NonCooperativeClient();
        final timeoutApi = CocktailDbClient(
          client: timeoutClient,
          requestTimeout: const Duration(milliseconds: 1),
        );
        await expectLater(
          timeoutApi.lookupRecipe('1'),
          _throwsKind(CocktailApiErrorKind.timeout),
        );

        final lateClient = _NonCooperativeClient();
        final lateApi = CocktailDbClient(client: lateClient);
        final pending = lateApi.lookupRecipe('2');
        await Future<void>.delayed(Duration.zero);
        lateApi.close();
        lateClient.complete(
          _jsonResponse({
            'drinks': [_full(id: '2')],
          }),
        );
        await expectLater(pending, _throwsKind(CocktailApiErrorKind.closed));
        expect(lateClient.wasClosed, isFalse);
      },
    );

    test('times out when a response stream stalls after headers', () async {
      final controller = StreamController<List<int>>();
      final client = CocktailDbClient(
        requestTimeout: const Duration(milliseconds: 1),
        client: MockClient.streaming(
          (_, _) async => http.StreamedResponse(controller.stream, 200),
        ),
      );
      await expectLater(
        client.lookupRecipe('1'),
        _throwsKind(CocktailApiErrorKind.timeout),
      );
      await controller.close();
    });
  });
}

http.Response _jsonResponse(Object body) =>
    http.Response(jsonEncode(body), 200);

Map<String, dynamic> _full({String id = '42'}) => {
  'idDrink': id,
  'strDrink': 'Synthetic Fizz',
  'strDrinkThumb': 'https://example.invalid/thumb.png',
  'strInstructions': 'Shake gently.',
  'strIngredient1': 'Mint',
  'strMeasure1': '1 leaf',
};

Map<String, dynamic> _summary() => {
  'idDrink': '42',
  'strDrink': 'Synthetic Fizz',
  'strDrinkThumb': 'https://example.invalid/thumb.png',
};

Matcher _hasKind(CocktailApiErrorKind kind) =>
    isA<CocktailApiException>().having((error) => error.kind, 'kind', kind);
Matcher _throwsKind(CocktailApiErrorKind kind) => throwsA(_hasKind(kind));

final class _AbortAwareClient extends http.BaseClient {
  bool wasClosed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final abortable = request as http.AbortableRequest;
    await abortable.abortTrigger;
    throw http.RequestAbortedException(request.url);
  }

  @override
  void close() => wasClosed = true;
}

final class _NonCooperativeClient extends http.BaseClient {
  final _response = Completer<http.StreamedResponse>();
  bool wasClosed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      _response.future;

  void complete(http.Response response) {
    _response.complete(
      http.StreamedResponse(
        Stream<List<int>>.value(response.bodyBytes),
        response.statusCode,
        headers: response.headers,
      ),
    );
  }

  @override
  void close() => wasClosed = true;
}
