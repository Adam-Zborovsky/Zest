import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zest/core/network/cocktail_api_exception.dart';
import 'package:zest/features/catalog/data/catalog_snapshot_client.dart';

import '../../../support/catalog_fixtures.dart';
import '../../../support/discovery_fixtures.dart';

void main() {
  group('CatalogSnapshotClient', () {
    test('a 200 with a valid envelope returns a parsed snapshot', () async {
      late Uri url;
      final client = CatalogSnapshotClient(
        baseUrl: 'https://gateway.example.invalid/api/cocktails/',
        client: MockClient((request) async {
          url = request.url;
          return http.Response(
            jsonEncode(
              catalogSnapshotEnvelope(
                version: fakeCatalogVersion('v1'),
                drinks: [discoveryRecipe(id: '11007', name: 'Margarita')],
              ),
            ),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final result = await client.fetch();
      expect(url.toString(), 'https://gateway.example.invalid/api/catalog');
      expect(result, isA<CatalogSnapshotAvailable>());
      final snapshot = (result as CatalogSnapshotAvailable).snapshot;
      expect(snapshot.version, fakeCatalogVersion('v1'));
      expect(snapshot.recipeCount, 1);
      expect(snapshot.drinks.single.name, 'Margarita');
      expect(snapshot.attribution.name, 'TheCocktailDB');
    });

    test('sends If-None-Match with the quoted local version', () async {
      http.Request? sent;
      final client = CatalogSnapshotClient(
        client: MockClient((request) async {
          sent = request;
          return http.Response('', 304);
        }),
      );
      await client.fetch(ifNoneMatchVersion: fakeCatalogVersion('current'));
      expect(
        sent!.headers['If-None-Match'],
        '"${fakeCatalogVersion('current')}"',
      );
    });

    test('a 304 yields unchanged without allocating drinks', () async {
      final client = CatalogSnapshotClient(
        client: MockClient((request) async => http.Response('', 304)),
      );
      final result = await client.fetch(ifNoneMatchVersion: 'anything');
      expect(result, isA<CatalogSnapshotUnchanged>());
    });

    test('a 200 whose version matches the caller also yields unchanged', () async {
      final version = fakeCatalogVersion('same');
      final client = CatalogSnapshotClient(
        client: MockClient(
          (request) async => http.Response(
            jsonEncode(catalogSnapshotEnvelope(version: version, drinks: const [])),
            200,
          ),
        ),
      );
      final result = await client.fetch(ifNoneMatchVersion: version);
      expect(result, isA<CatalogSnapshotUnchanged>());
    });

    test('a 503 throws http with statusCode 503', () async {
      final client = CatalogSnapshotClient(
        client: MockClient((request) async => http.Response('', 503)),
      );
      await expectLater(
        client.fetch(),
        _throwsKind(CocktailApiErrorKind.http, statusCode: 503),
      );
    });

    test('a 429 throws rateLimited with Retry-After', () async {
      final client = CatalogSnapshotClient(
        client: MockClient(
          (request) async =>
              http.Response('', 429, headers: {'retry-after': '12'}),
        ),
      );
      await expectLater(
        client.fetch(),
        _throwsKind(CocktailApiErrorKind.rateLimited, retryAfterSeconds: 12),
      );
    });

    test('another non-2xx status throws http with its status code', () async {
      final client = CatalogSnapshotClient(
        client: MockClient((request) async => http.Response('', 500)),
      );
      await expectLater(
        client.fetch(),
        _throwsKind(CocktailApiErrorKind.http, statusCode: 500),
      );
    });

    test('a client timeout throws timeout', () async {
      final client = CatalogSnapshotClient(
        requestTimeout: const Duration(milliseconds: 20),
        client: MockClient((request) async {
          await Future<void>.delayed(const Duration(milliseconds: 200));
          return http.Response(jsonEncode(catalogSnapshotEnvelope()), 200);
        }),
      );
      await expectLater(
        client.fetch(),
        _throwsKind(CocktailApiErrorKind.timeout),
      );
    });

    test('offline (a thrown ClientException) surfaces as network', () async {
      final client = CatalogSnapshotClient(
        client: MockClient((request) => throw http.ClientException('down')),
      );
      await expectLater(
        client.fetch(),
        _throwsKind(CocktailApiErrorKind.network),
      );
    });

    test('a response over the 8 MB decompressed limit is invalid', () async {
      final client = CatalogSnapshotClient(
        maxResponseBytes: 1024,
        client: MockClient(
          (request) async =>
              http.Response(jsonEncode(catalogSnapshotEnvelope()) + ' ' * 4096, 200),
        ),
      );
      await expectLater(
        client.fetch(),
        _throwsKind(CocktailApiErrorKind.invalidResponse),
      );
    });

    test('malformed JSON is invalid', () async {
      final client = CatalogSnapshotClient(
        client: MockClient((request) async => http.Response('not json', 200)),
      );
      await expectLater(
        client.fetch(),
        _throwsKind(CocktailApiErrorKind.invalidResponse),
      );
    });

    test('a version that is not 64 lowercase hex is invalid', () async {
      final client = CatalogSnapshotClient(
        client: MockClient(
          (request) async => http.Response(
            jsonEncode(catalogSnapshotEnvelope(version: 'not-hex')),
            200,
          ),
        ),
      );
      await expectLater(
        client.fetch(),
        _throwsKind(CocktailApiErrorKind.invalidResponse),
      );
    });

    test('recipeCount not matching drinks.length is invalid', () async {
      final client = CatalogSnapshotClient(
        client: MockClient(
          (request) async => http.Response(
            jsonEncode(
              catalogSnapshotEnvelope(
                drinks: [discoveryRecipe(id: '1', name: 'One')],
                recipeCount: 2,
              ),
            ),
            200,
          ),
        ),
      );
      await expectLater(
        client.fetch(),
        _throwsKind(CocktailApiErrorKind.invalidResponse),
      );
    });

    test('duplicate ids across drinks are invalid', () async {
      final client = CatalogSnapshotClient(
        client: MockClient(
          (request) async => http.Response(
            jsonEncode(
              catalogSnapshotEnvelope(
                drinks: [
                  discoveryRecipe(id: '1', name: 'One'),
                  discoveryRecipe(id: '1', name: 'One Again'),
                ],
              ),
            ),
            200,
          ),
        ),
      );
      await expectLater(
        client.fetch(),
        _throwsKind(CocktailApiErrorKind.invalidResponse),
      );
    });

    test('a non-numeric idDrink is invalid', () async {
      final client = CatalogSnapshotClient(
        client: MockClient(
          (request) async => http.Response(
            jsonEncode(
              catalogSnapshotEnvelope(
                drinks: [
                  {...discoveryRecipe(id: '1', name: 'One'), 'idDrink': 'abc'},
                ],
              ),
            ),
            200,
          ),
        ),
      );
      await expectLater(
        client.fetch(),
        _throwsKind(CocktailApiErrorKind.invalidResponse),
      );
    });

    test('a non-string str* field is invalid', () async {
      final client = CatalogSnapshotClient(
        client: MockClient(
          (request) async => http.Response(
            jsonEncode(
              catalogSnapshotEnvelope(
                drinks: [
                  {...discoveryRecipe(id: '1', name: 'One'), 'strDrinkThumb': 7},
                ],
              ),
            ),
            200,
          ),
        ),
      );
      await expectLater(
        client.fetch(),
        _throwsKind(CocktailApiErrorKind.invalidResponse),
      );
    });

    test('an empty or blank strDrink is invalid', () async {
      final client = CatalogSnapshotClient(
        client: MockClient(
          (request) async => http.Response(
            jsonEncode(
              catalogSnapshotEnvelope(
                drinks: [
                  {...discoveryRecipe(id: '1', name: 'One'), 'strDrink': '   '},
                ],
              ),
            ),
            200,
          ),
        ),
      );
      await expectLater(
        client.fetch(),
        _throwsKind(CocktailApiErrorKind.invalidResponse),
      );
    });

    test('a missing or malformed attribution is invalid', () async {
      final client = CatalogSnapshotClient(
        client: MockClient((request) async {
          final body = catalogSnapshotEnvelope();
          body['attribution'] = {'name': 'TheCocktailDB'}; // no url
          return http.Response(jsonEncode(body), 200);
        }),
      );
      await expectLater(
        client.fetch(),
        _throwsKind(CocktailApiErrorKind.invalidResponse),
      );
    });

    test('never sends a provider key', () async {
      final client = CatalogSnapshotClient(
        client: MockClient((request) async {
          expect(request.url.queryParameters, isEmpty);
          expect(request.headers.keys, isNot(contains('apikey')));
          return http.Response(jsonEncode(catalogSnapshotEnvelope()), 200);
        }),
      );
      await client.fetch();
    });
  });
}

Matcher _throwsKind(
  CocktailApiErrorKind kind, {
  int? statusCode,
  int? retryAfterSeconds,
}) {
  var matcher = isA<CocktailApiException>().having((e) => e.kind, 'kind', kind);
  if (statusCode != null) {
    matcher = matcher.having((e) => e.statusCode, 'statusCode', statusCode);
  }
  if (retryAfterSeconds != null) {
    matcher = matcher.having(
      (e) => e.retryAfter?.inSeconds,
      'retryAfter',
      retryAfterSeconds,
    );
  }
  return throwsA(matcher);
}
