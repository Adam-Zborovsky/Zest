import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zest/app/zest_app.dart';
import 'package:zest/features/discovery/application/discovery_providers.dart';
import 'package:zest/features/discovery/data/cocktail_db_client.dart';
import 'package:zest/features/home_bar/application/home_bar_providers.dart';
import 'package:zest/features/home_bar/domain/home_bar_item.dart';

import '../../../support/bar_fixtures.dart';
import '../../../support/catalog_wiring.dart';
import '../../../support/collection_test_overrides.dart';
import '../../../support/in_memory_home_bar_repository.dart';
import '../../../support/in_memory_session.dart';

Future<InMemoryHomeBarRepository> _openRecipe(
  WidgetTester tester, {
  bool inventoryLoading = false,
}) async {
  final response = http.Response(
    jsonEncode({
      'drinks': [
        barRecipeJson(
          id: '99120',
          name: 'Shopping sour',
          ingredients: [
            ('Imaginary gin', '2 oz'),
            ('Pretend lime juice', '1 oz'),
            ('Nutmeg', null),
          ],
        ),
      ],
    }),
    200,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
  final transport = MockClient((_) async => response);
  final client = CocktailDbClient(client: transport);
  final repository = InMemoryHomeBarRepository([
    HomeBarItem(
      ingredientId: 'imaginary gin',
      displayName: 'Imaginary gin',
      location: HomeBarLocation.stocked,
      updatedAt: DateTime.utc(2026, 9, 14),
    ),
  ]);
  addTearDown(() {
    client.close();
    transport.close();
  });
  addTearDown(repository.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        cocktailDbClientProvider.overrideWithValue(client),
        emptyCatalogRepositoryOverride(),
        homeBarRepositoryProvider.overrideWithValue(repository),
        if (inventoryLoading)
          homeBarItemsProvider.overrideWithValue(
            const AsyncLoading<List<HomeBarItem>>(),
          ),
        ...collectionTestOverrides(),
        ...sessionTestOverrides(),
      ],
      child: const ZestApp(initialLocation: '/discover/recipe/99120'),
    ),
  );
  await tester.pumpAndSettle();
  return repository;
}

void main() {
  testWidgets('recipe sends only unstocked essentials to shopping', (
    tester,
  ) async {
    final repository = await _openRecipe(tester);

    expect(find.text('Missing essentials'), findsOneWidget);
    expect(find.textContaining('Pretend lime juice.'), findsOneWidget);
    expect(
      find.textContaining('Optional garnishes are not added'),
      findsOneWidget,
    );
    final addMissing = find.byKey(const ValueKey('recipe-add-missing-99120'));
    await tester.ensureVisible(addMissing);
    await tester.pumpAndSettle();
    await tester.tap(addMissing);
    await tester.pumpAndSettle();

    expect(find.text('Missing essentials added to shopping.'), findsOneWidget);
    expect(
      repository.items
          .where((item) => item.location == HomeBarLocation.shopping)
          .map((item) => item.ingredientId),
      ['pretend lime juice'],
    );
  });

  testWidgets('recipe waits for inventory before offering a shopping write', (
    tester,
  ) async {
    await _openRecipe(tester, inventoryLoading: true);

    expect(find.text('Checking your home bar…'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('recipe-add-missing-99120')),
      findsNothing,
    );
  });
}
