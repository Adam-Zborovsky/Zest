import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zest/core/network/cocktail_api_exception.dart';
import 'package:zest/features/discovery/data/cocktail_db_client.dart';

void main() {
  test(
    'gateway URLs reject remote cleartext and embedded configuration secrets',
    () {
      for (final url in [
        'http://remote.example.invalid/api/',
        'https://gateway.example.invalid/api?key=synthetic',
        'https://gateway.example.invalid/api/#synthetic',
        'https://gateway.example.invalid/api',
        'file:///api/',
        '/api/',
        'not a url',
      ]) {
        expect(() => CocktailDbClient(baseUrl: url), throwsArgumentError);
      }
      for (final url in [
        'http://localhost:3000/api/cocktails/',
        'http://127.0.0.1:3000/api/cocktails/',
        'http://[::1]:3000/api/cocktails/',
        'https://gateway.example.invalid/api/cocktails/',
      ]) {
        CocktailDbClient(baseUrl: url).close();
      }
    },
  );

  test('upstream timeout through gateway retains timeout UX', () async {
    final client = CocktailDbClient(
      client: MockClient(
        (_) async =>
            http.Response('{"error":{"code":"upstream_timeout"}}', 504),
      ),
    );
    addTearDown(client.close);
    await expectLater(
      client.searchByName('Synthetic'),
      throwsA(
        isA<CocktailApiException>().having(
          (error) => error.kind,
          'kind',
          CocktailApiErrorKind.timeout,
        ),
      ),
    );
  });
}
