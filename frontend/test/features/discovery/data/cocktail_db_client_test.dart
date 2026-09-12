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
      'builds each endpoint with encoded query values and injected key',
      () async {
        final urls = <Uri>[];
        final client = CocktailDbClient(
          apiKey: 'test-key',
          client: MockClient((request) async {
            urls.add(request.url);
            return _jsonResponse({
              'drinks': request.url.path.contains('filter')
                  ? [_summary()]
                  : request.url.path.contains('list')
                  ? [
                      {'strIngredient1': 'Lime'},
                    ]
                  : [_full()],
            });
          }),
        );

        await client.searchByName('  lime fizz  ');
        await client.browseByFirstLetter(' Q ');
        await client.filterByIngredient('Brand Rum & Lime');
        await client.lookupRecipe('42');
        await client.listIngredientNames();

        expect(urls.map((url) => url.path), [
          '/api/json/v1/test-key/search.php',
          '/api/json/v1/test-key/search.php',
          '/api/json/v1/test-key/filter.php',
          '/api/json/v1/test-key/lookup.php',
          '/api/json/v1/test-key/list.php',
        ]);
        expect(urls.map((url) => url.queryParameters), [
          {'s': 'lime fizz'},
          {'f': 'q'},
          {'i': 'Brand Rum & Lime'},
          {'i': '42'},
          {'i': 'list'},
        ]);
      },
    );

    test('uses documented default key', () async {
      late Uri url;
      final client = CocktailDbClient(
        client: MockClient((request) async {
          url = request.url;
          return _jsonResponse({
            'drinks': [_full()],
          });
        }),
      );
      await client.searchByName('mint');
      expect(url.path, '/api/json/v1/1/search.php');
    });

    test('lists ingredient names sorted, deduplicated, and cached', () async {
      var requests = 0;
      final client = CocktailDbClient(
        client: MockClient((request) async {
          requests++;
          return _jsonResponse({
            'drinks': [
              {'strIngredient1': 'Zest Orange'},
              {'strIngredient1': ' apple syrup '},
              {'strIngredient1': 'Zest Orange'},
              {'strIngredient1': 'Apple Syrup'},
            ],
          });
        }),
      );
      final names = await client.listIngredientNames();
      expect(names, ['apple syrup', 'Zest Orange']);
      expect(requests, 1);
      expect(await client.listIngredientNames(), same(names));
      expect(requests, 1);
    });

    test('rejects malformed ingredient list records', () async {
      final client = CocktailDbClient(
        client: MockClient(
          (request) async => _jsonResponse({
            'drinks': [
              {'strIngredient1': 7},
            ],
          }),
        ),
      );
      await expectLater(
        client.listIngredientNames(),
        _throwsKind(CocktailApiErrorKind.invalidResponse),
      );
    });

    test(
      'handles empty matches and only returns detail models for detail endpoints',
      () async {
        final client = CocktailDbClient(
          client: MockClient((request) async {
            if (request.url.path.contains('filter'))
              return _jsonResponse({
                'drinks': [_summary()],
              });
            return _jsonResponse({'drinks': null});
          }),
        );
        expect(await client.searchByName('none'), isEmpty);
        expect(await client.filterByIngredient('mint'), hasLength(1));
        expect(await client.lookupRecipe('42'), isNull);
      },
    );

    test('rejects invalid input before making a request', () async {
      var calls = 0;
      final client = CocktailDbClient(
        client: MockClient((_) async {
          calls++;
          return _jsonResponse({'drinks': []});
        }),
      );
      expect(() => client.searchByName('  '), throwsArgumentError);
      expect(() => client.filterByIngredient(''), throwsArgumentError);
      expect(() => client.browseByFirstLetter('12'), throwsArgumentError);
      expect(() => client.lookupRecipe('x42'), throwsArgumentError);
      expect(calls, 0);
    });

    test(
      'rejects unsafe API keys without including the supplied key in the error',
      () {
        expect(
          () => CocktailDbClient(apiKey: 'secret/key'),
          throwsA(
            isA<ArgumentError>().having(
              (error) => error.toString(),
              'safe error',
              isNot(contains('secret/key')),
            ),
          ),
        );
      },
    );

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
        await expectLater(
          client.searchByName('one'),
          _throwsKind(CocktailApiErrorKind.invalidResponse),
        );
        await expectLater(
          client.searchByName('two'),
          _throwsKind(CocktailApiErrorKind.invalidResponse),
        );
        await expectLater(
          client.searchByName('three'),
          _throwsKind(CocktailApiErrorKind.invalidResponse),
        );
        await expectLater(
          client.lookupRecipe('42'),
          _throwsKind(CocktailApiErrorKind.invalidResponse),
        );
        await expectLater(
          client.lookupRecipe('42'),
          _throwsKind(CocktailApiErrorKind.invalidResponse),
        );
      },
    );

    test(
      'maps HTTP failures and rate limits with their safe metadata',
      () async {
        final httpFailure = CocktailDbClient(
          client: MockClient((_) async => http.Response('', 500)),
        );
        await expectLater(
          httpFailure.searchByName('one'),
          _throwsKind(CocktailApiErrorKind.http),
        );
        final limited = CocktailDbClient(
          client: MockClient(
            (_) async => http.Response('', 429, headers: {'retry-after': '7'}),
          ),
        );
        await expectLater(
          limited.searchByName('two'),
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
        apiKey: 'secret-key',
        client: MockClient(
          (_) => throw http.ClientException(
            'syntheticsecret',
            Uri.parse('https://example.invalid/syntheticsecret'),
          ),
        ),
      );
      await expectLater(
        network.searchByName('x'),
        _throwsKind(CocktailApiErrorKind.network),
      );
      try {
        await network.searchByName('y');
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
          client.searchByName('redirect'),
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
        oversized.searchByName('large'),
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
        failedStream.searchByName('stream'),
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
            return _jsonResponse({
              'drinks': request.url.queryParameters['s'] == 'empty'
                  ? []
                  : [_full()],
            });
          }),
        );
        await client.searchByName('a');
        await client.searchByName('b');
        await client.searchByName('a'); // a becomes most recently used
        await client.searchByName('c'); // b evicted
        await client.searchByName('b');
        await client.searchByName('empty');
        await client.searchByName('empty');
        expect(calls, 5);
        clock = clock.add(const Duration(minutes: 1));
        await client.searchByName('empty');
        expect(calls, 6);
      },
    );

    test(
      'returns immutable collections and treats zero TTL as immediately expired',
      () async {
        var calls = 0;
        final client = CocktailDbClient(
          cacheTtl: Duration.zero,
          client: MockClient((_) async {
            calls++;
            return _jsonResponse({
              'drinks': [_full()],
            });
          }),
        );
        final recipes = await client.searchByName('immutable');
        expect(() => recipes.add(recipes.single), throwsUnsupportedError);
        await client.searchByName('immutable');
        expect(calls, 2);
      },
    );

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
                'drinks': [_full()],
              }),
            );
          }),
        );
        final first = client.searchByName('shared');
        final second = client.searchByName('shared');
        gate.complete(
          _jsonResponse({
            'drinks': [_full()],
          }),
        );
        await Future.wait([first, second]);
        expect(calls, 1);

        final failing = CocktailDbClient(
          client: MockClient((_) async {
            calls++;
            if (calls == 2) return http.Response('bad', 200);
            return _jsonResponse({
              'drinks': [_full()],
            });
          }),
        );
        await expectLater(
          failing.searchByName('retry'),
          _throwsKind(CocktailApiErrorKind.invalidResponse),
        );
        await failing.searchByName('retry');
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
          api.searchByName('slow'),
          _throwsKind(CocktailApiErrorKind.timeout),
        );

        final active = CocktailDbClient(client: client);
        final pending = active.searchByName('active');
        await Future<void>.delayed(Duration.zero);
        active.close();
        await expectLater(pending, _throwsKind(CocktailApiErrorKind.closed));
        api.close();
        expect(client.wasClosed, isFalse);
        await expectLater(
          api.searchByName('after-close'),
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
          timeoutApi.searchByName('slow'),
          _throwsKind(CocktailApiErrorKind.timeout),
        );

        final lateClient = _NonCooperativeClient();
        final lateApi = CocktailDbClient(client: lateClient);
        final pending = lateApi.searchByName('late');
        await Future<void>.delayed(Duration.zero);
        lateApi.close();
        lateClient.complete(
          _jsonResponse({
            'drinks': [_full()],
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
        client.searchByName('stall'),
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
