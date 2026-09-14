import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zest/core/network/cocktail_api_exception.dart';
import 'package:zest/features/catalog/application/catalog_providers.dart';
import 'package:zest/features/catalog/data/catalog_database.dart';
import 'package:zest/features/catalog/data/catalog_repository.dart';
import 'package:zest/features/discovery/application/discovery_providers.dart';
import 'package:zest/features/discovery/data/cocktail_db_client.dart';
import 'package:zest/features/discovery/domain/discovery_query.dart';
import 'package:zest/features/discovery/domain/recipe.dart';

import '../../../support/catalog_fixtures.dart';
import '../../../support/catalog_wiring.dart';

void main() {
  test('name mode ranks local catalog matches via the search index', () async {
    final seeded = await _seededContainer([
      catalogRecipeModel(id: '1', name: 'Old Fashioned'),
      catalogRecipeModel(id: '2', name: 'Margarita'),
    ]);
    addTearDown(() => _disposeSeeded(seeded));

    final results = await seeded.container.read(
      discoveryResultsProvider(
        DiscoveryQuery(mode: DiscoveryMode.name, value: 'old fash'),
      ).future,
    );
    expect(results.map((r) => r.id), ['1']);
  });

  test(
    'ingredient mode returns every recipe using that ingredient identity',
    () async {
      final seeded = await _seededContainer([
        catalogRecipeModel(
          id: '1',
          name: 'Gin Fizz',
          ingredients: const [('Gin', '2 oz')],
        ),
        catalogRecipeModel(
          id: '2',
          name: 'Gin Sour',
          ingredients: const [('Gin', '1 oz')],
        ),
        catalogRecipeModel(
          id: '3',
          name: 'Rum Punch',
          ingredients: const [('Rum', '1 oz')],
        ),
      ]);
      addTearDown(() => _disposeSeeded(seeded));

      final results = await seeded.container.read(
        discoveryResultsProvider(
          DiscoveryQuery(mode: DiscoveryMode.ingredient, value: 'gin'),
        ).future,
      );
      expect(results.map((r) => r.id).toSet(), {'1', '2'});
    },
  );

  test(
    'letter mode returns recipes whose folded name starts with that letter, ordered by name',
    () async {
      final seeded = await _seededContainer([
        catalogRecipeModel(id: '1', name: 'Zesty Zinger'),
        catalogRecipeModel(id: '2', name: 'Zephyr'),
        catalogRecipeModel(id: '3', name: 'Amaro Spritz'),
      ]);
      addTearDown(() => _disposeSeeded(seeded));

      final results = await seeded.container.read(
        discoveryResultsProvider(
          DiscoveryQuery(mode: DiscoveryMode.letter, value: 'z'),
        ).future,
      );
      expect(results.map((r) => r.id), ['2', '1']);
    },
  );

  test('rejects invalid detail IDs before any lookup', () async {
    var calls = 0;
    final seeded = await _seededContainer(
      const [],
      transport: MockClient((_) async {
        calls++;
        return _response({'drinks': []});
      }),
    );
    addTearDown(() => _disposeSeeded(seeded));

    await expectLater(
      seeded.container.read(recipeDetailProvider('not-an-id').future),
      throwsArgumentError,
    );
    expect(calls, 0);
  });

  test(
    'recipe detail reads the local catalog first, without any network call',
    () async {
      var calls = 0;
      final seeded = await _seededContainer(
        [catalogRecipeModel(id: '3', name: 'Local Hit')],
        transport: MockClient((_) async {
          calls++;
          return _response({'drinks': []});
        }),
      );
      addTearDown(() => _disposeSeeded(seeded));

      final recipe = await seeded.container.read(recipeDetailProvider('3').future);
      expect(recipe?.name, 'Local Hit');
      expect(calls, 0);
    },
  );

  test(
    'recipe detail falls back to lookup.php when the id is absent from the catalog',
    () async {
      final requests = <Uri>[];
      final seeded = await _seededContainer(
        const [],
        transport: MockClient((request) async {
          requests.add(request.url);
          return _response({
            'drinks': [_full('7')],
          });
        }),
      );
      addTearDown(() => _disposeSeeded(seeded));

      final recipe = await seeded.container.read(recipeDetailProvider('7').future);
      expect(recipe?.id, '7');
      expect(requests.single.queryParameters, {'i': '7'});
    },
  );

  test('does not automatically retry a fallback lookup failure', () async {
    var calls = 0;
    final seeded = await _seededContainer(
      const [],
      transport: MockClient((_) async {
        calls++;
        return http.Response('', 500);
      }),
    );
    addTearDown(() => _disposeSeeded(seeded));

    await expectLater(
      seeded.container.read(recipeDetailProvider('7').future),
      throwsA(isA<CocktailApiException>()),
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(calls, 1);
  });

  test(
    'a 429 on the fallback lookup shares a cooldown across detail requests, then expires',
    () async {
      var clock = DateTime(2026);
      var calls = 0;
      final seeded = await _seededContainer(
        const [],
        transport: MockClient((_) async {
          calls++;
          if (calls == 1) return http.Response('', 429);
          return _response({
            'drinks': [_full('7')],
          });
        }),
        now: () => clock,
      );
      addTearDown(() => _disposeSeeded(seeded));

      await expectLater(
        seeded.container.read(recipeDetailProvider('7').future),
        throwsA(
          isA<CocktailApiException>().having(
            (e) => e.retryAfter,
            'fallback',
            const Duration(seconds: 30),
          ),
        ),
      );
      await expectLater(
        seeded.container.read(recipeDetailProvider('8').future),
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
      seeded.container.invalidate(recipeDetailProvider('7'));
      expect((await seeded.container.read(recipeDetailProvider('7').future))?.id, '7');
      expect(calls, 2);
    },
  );

  test('disposes the provider-owned client safely', () async {
    final container = ProviderContainer();
    final client = container.read(cocktailDbClientProvider);
    container.dispose();
    await expectLater(
      client.lookupRecipe('42'),
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

/// Both the container and its in-memory catalog database, so callers can
/// tear down each explicitly (`ProviderContainer` has no dispose hook of its
/// own to close a database an override merely points at).
typedef _Seeded = ({ProviderContainer container, CatalogDatabase database});

Future<_Seeded> _seededContainer(
  List<Recipe> recipes, {
  http.Client? transport,
  DateTime Function()? now,
}) async {
  final database = openInMemoryCatalog();
  final repository = CatalogRepository(database: database);
  if (recipes.isNotEmpty) {
    await repository.applySnapshot(catalogSnapshotFixture(drinks: recipes));
  }
  final container = ProviderContainer(
    overrides: [
      catalogRepositoryProvider.overrideWithValue(repository),
      cocktailDbClientProvider.overrideWithValue(
        CocktailDbClient(client: transport ?? MockClient((_) async => _response({'drinks': []}))),
      ),
      if (now != null) nowProvider.overrideWithValue(now),
    ],
  );
  return (container: container, database: database);
}

Future<void> _disposeSeeded(_Seeded seeded) async {
  seeded.container.dispose();
  await seeded.database.close();
}

http.Response _response(Object body) => http.Response(jsonEncode(body), 200);

Map<String, dynamic> _full(String id, {String? name}) => {
  'idDrink': id,
  'strDrink': name ?? 'Synthetic $id',
  'strInstructions': 'Stir.',
  'strIngredient1': 'Mint',
};
