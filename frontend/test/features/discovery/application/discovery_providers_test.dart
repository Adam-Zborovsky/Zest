import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zest/core/network/cocktail_api_exception.dart';
import 'package:zest/features/discovery/application/discovery_providers.dart';
import 'package:zest/features/discovery/data/cocktail_db_client.dart';
import 'package:zest/features/discovery/domain/discovery_query.dart';

void main() {
  test(
    'maps all discovery modes to summaries and their respective client calls',
    () async {
      final requests = <Uri>[];
      final container = _container(
        MockClient((request) async {
          requests.add(request.url);
          return _response({
            'drinks': [
              request.url.path.contains('filter') ? _summary('3') : _full('3'),
            ],
          });
        }),
      );
      addTearDown(container.dispose);

      for (final query in [
        DiscoveryQuery(mode: DiscoveryMode.name, value: 'mint'),
        DiscoveryQuery(mode: DiscoveryMode.ingredient, value: 'lime'),
        DiscoveryQuery(mode: DiscoveryMode.letter, value: 'z'),
      ]) {
        final results = await container.read(
          discoveryResultsProvider(query).future,
        );
        expect(results.single.id, '3');
      }
      expect((await container.read(recipeDetailProvider('3').future))?.id, '3');
      expect(requests.map((uri) => uri.queryParameters), [
        {'s': 'mint'},
        {'i': 'lime'},
        {'f': 'z'},
        {'i': '3'},
      ]);
    },
  );

  test('rejects invalid detail IDs before any network request', () async {
    var calls = 0;
    final container = _container(
      MockClient((_) async {
        calls++;
        return _response({'drinks': []});
      }),
    );
    addTearDown(container.dispose);

    await expectLater(
      container.read(recipeDetailProvider('not-an-id').future),
      throwsArgumentError,
    );
    expect(calls, 0);
  });

  test('does not automatically retry provider failures', () async {
    var calls = 0;
    final container = _container(
      MockClient((_) async {
        calls++;
        return http.Response('', 500);
      }),
    );
    addTearDown(container.dispose);
    final query = DiscoveryQuery(mode: DiscoveryMode.name, value: 'mint');

    await expectLater(
      container.read(discoveryResultsProvider(query).future),
      throwsA(isA<CocktailApiException>()),
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(calls, 1);
  });

  test(
    'separate family states do not let an older result replace a newer one',
    () async {
      final first = Completer<http.Response>();
      final second = Completer<http.Response>();
      var calls = 0;
      final container = _container(
        MockClient((_) {
          calls++;
          return calls == 1 ? first.future : second.future;
        }),
      );
      addTearDown(container.dispose);
      final oldQuery = DiscoveryQuery(mode: DiscoveryMode.name, value: 'old');
      final newQuery = DiscoveryQuery(mode: DiscoveryMode.name, value: 'new');
      final oldFuture = container.read(
        discoveryResultsProvider(oldQuery).future,
      );
      final newFuture = container.read(
        discoveryResultsProvider(newQuery).future,
      );

      second.complete(
        _response({
          'drinks': [_full('2', name: 'New')],
        }),
      );
      expect((await newFuture).single.name, 'New');
      first.complete(
        _response({
          'drinks': [_full('1', name: 'Old')],
        }),
      );
      await oldFuture;
      expect(
        container.read(discoveryResultsProvider(newQuery)).value?.single.name,
        'New',
      );
    },
  );

  test(
    'shares a 429 cooldown across results and detail, then expires',
    () async {
      var clock = DateTime(2026);
      var calls = 0;
      final container = _container(
        MockClient((_) async {
          calls++;
          if (calls == 1) return http.Response('', 429);
          return _response({
            'drinks': [_full('7')],
          });
        }),
        now: () => clock,
      );
      addTearDown(container.dispose);
      final query = DiscoveryQuery(mode: DiscoveryMode.name, value: 'mint');

      await expectLater(
        container.read(discoveryResultsProvider(query).future),
        throwsA(
          isA<CocktailApiException>().having(
            (e) => e.retryAfter,
            'fallback',
            const Duration(seconds: 30),
          ),
        ),
      );
      await expectLater(
        container.read(recipeDetailProvider('7').future),
        throwsA(
          isA<CocktailApiException>().having(
            (e) => e.retryAfter,
            'remaining',
            const Duration(seconds: 30),
          ),
        ),
      );
      expect(calls, 1);
      clock = clock.add(const Duration(seconds: 30));
      container.invalidate(recipeDetailProvider('7'));
      expect((await container.read(recipeDetailProvider('7').future))?.id, '7');
      expect(calls, 2);
    },
  );

  test(
    'overlapping 429 responses retain the maximum shared cooldown',
    () async {
      await _expectOverlappingCooldown(
        firstDelay: const Duration(seconds: 120),
        secondDelay: const Duration(seconds: 1),
        firstExpected: const Duration(seconds: 120),
        secondExpected: const Duration(seconds: 120),
      );
      await _expectOverlappingCooldown(
        firstDelay: const Duration(seconds: 1),
        secondDelay: const Duration(seconds: 120),
        firstExpected: const Duration(seconds: 1),
        secondExpected: const Duration(seconds: 120),
      );
    },
  );

  test('disposes the provider-owned client safely', () async {
    final container = ProviderContainer();
    final client = container.read(cocktailDbClientProvider);
    container.dispose();
    await expectLater(
      client.searchByName('after disposal'),
      throwsA(
        isA<CocktailApiException>().having(
          (e) => e.kind,
          'kind',
          CocktailApiErrorKind.closed,
        ),
      ),
    );
  });
}

ProviderContainer _container(
  http.Client transport, {
  DateTime Function()? now,
}) {
  return ProviderContainer(
    overrides: [
      cocktailDbClientProvider.overrideWithValue(
        CocktailDbClient(client: transport),
      ),
      if (now != null) nowProvider.overrideWithValue(now),
    ],
  );
}

http.Response _response(Object body) => http.Response(jsonEncode(body), 200);

Map<String, dynamic> _summary(String id) => {
  'idDrink': id,
  'strDrink': 'Synthetic $id',
};

Map<String, dynamic> _full(String id, {String? name}) => {
  ..._summary(id),
  'strDrink': name ?? 'Synthetic $id',
  'strInstructions': 'Stir.',
  'strIngredient1': 'Mint',
};

Future<void> _expectOverlappingCooldown({
  required Duration firstDelay,
  required Duration secondDelay,
  required Duration firstExpected,
  required Duration secondExpected,
}) async {
  var clock = DateTime(2026);
  final responses = [Completer<http.Response>(), Completer<http.Response>()];
  var calls = 0;
  final container = _container(
    MockClient((_) => responses[calls++].future),
    now: () => clock,
  );
  try {
    final first = container.read(
      discoveryResultsProvider(
        DiscoveryQuery(mode: DiscoveryMode.name, value: 'first'),
      ).future,
    );
    final second = container.read(
      discoveryResultsProvider(
        DiscoveryQuery(mode: DiscoveryMode.name, value: 'second'),
      ).future,
    );
    await Future<void>.delayed(Duration.zero);
    expect(calls, 2);

    final firstError = expectLater(first, _rateLimitWith(firstExpected));
    responses[0].complete(
      http.Response(
        '',
        429,
        headers: {'retry-after': '${firstDelay.inSeconds}'},
      ),
    );
    await firstError;

    final secondError = expectLater(second, _rateLimitWith(secondExpected));
    responses[1].complete(
      http.Response(
        '',
        429,
        headers: {'retry-after': '${secondDelay.inSeconds}'},
      ),
    );
    await secondError;

    await expectLater(
      container.read(
        discoveryResultsProvider(
          DiscoveryQuery(mode: DiscoveryMode.name, value: 'blocked'),
        ).future,
      ),
      _rateLimitWith(firstDelay > secondDelay ? firstDelay : secondDelay),
    );
    expect(calls, 2);
  } finally {
    container.dispose();
  }
}

Matcher _rateLimitWith(Duration delay) => throwsA(
  isA<CocktailApiException>()
      .having((error) => error.kind, 'kind', CocktailApiErrorKind.rateLimited)
      .having((error) => error.retryAfter, 'retryAfter', delay),
);
