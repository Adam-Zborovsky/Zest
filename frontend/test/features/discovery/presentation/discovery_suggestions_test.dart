import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zest/app/zest_app.dart';
import 'package:zest/features/catalog/application/catalog_providers.dart';
import 'package:zest/features/catalog/data/catalog_repository.dart';
import 'package:zest/features/discovery/application/discovery_providers.dart';
import 'package:zest/features/discovery/data/cocktail_db_client.dart';
import 'package:zest/features/discovery/domain/recipe.dart';

import '../../../support/catalog_fixtures.dart';
import '../../../support/catalog_wiring.dart';
import '../../../support/collection_test_overrides.dart';
import '../../../support/in_memory_session.dart';
import '../../../support/load_fonts.dart';

Finder keyed(String value) => find.byKey(ValueKey(value));

GoRouter router(WidgetTester tester) =>
    GoRouter.of(tester.element(find.byType(Scaffold).last));

/// docs/M11.md "Surfaces" and "Acceptance": Discover's suggestions come
/// from the local catalog search index, matching "creme", "lime jiuce" and
/// "old fash" as documented.
Future<void> _openWith(WidgetTester tester, List<Recipe> catalogRecipes) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(900, 1200);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final transport = MockClient(
    (_) async => http.Response('{"drinks":null}', 200),
  );
  final client = CocktailDbClient(client: transport);
  addTearDown(() {
    client.close();
    transport.close();
  });
  final database = openInMemoryCatalog();
  addTearDown(database.close);
  final repository = CatalogRepository(database: database);
  await repository.applySnapshot(catalogSnapshotFixture(drinks: catalogRecipes));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        cocktailDbClientProvider.overrideWithValue(client),
        catalogRepositoryProvider.overrideWithValue(repository),
        ...collectionTestOverrides(),
        ...sessionTestOverrides(),
      ],
      child: const ZestApp(initialLocation: '/discover'),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadZestFonts);

  testWidgets(
    'typing a name shows a recipe suggestion; Down, Enter opens its detail',
    (tester) async {
      await _openWith(tester, [
        Recipe.fromJson(catalogRecipe(id: '11009', name: 'Old Fashioned')),
        Recipe.fromJson(catalogRecipe(id: '11010', name: 'Margarita')),
      ]);
      await tester.enterText(keyed('discovery-query'), 'old fash');
      await tester.pumpAndSettle();
      expect(find.text('Old Fashioned'), findsOneWidget);
      expect(find.text('Margarita'), findsNothing);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      expect(router(tester).state.uri.path, '/discover/recipe/11009');
      expect(find.text('Old Fashioned'), findsOneWidget);
    },
  );

  testWidgets(
    'selecting an ingredient suggestion runs ingredient results',
    (tester) async {
      await _openWith(tester, [
        Recipe.fromJson(
          catalogRecipe(
            id: '11009',
            name: 'Old Fashioned',
            ingredients: const [('Bourbon', '2 oz'), ('Sugar syrup', null)],
          ),
        ),
      ]);
      await tester.tap(keyed('mode-ingredient'));
      await tester.pumpAndSettle();
      await tester.enterText(keyed('discovery-query'), 'bourbon');
      await tester.pumpAndSettle();
      expect(find.text('Bourbon'), findsOneWidget);

      await tester.tap(find.text('Bourbon'));
      await tester.pumpAndSettle();

      expect(router(tester).state.uri.queryParameters, {
        'mode': 'ingredient',
        'q': 'Bourbon',
      });
      expect(keyed('recipe-11009'), findsOneWidget);
    },
  );

  testWidgets('"creme" matches a diacritic-folded ingredient', (tester) async {
    await _openWith(tester, [
      Recipe.fromJson(
        catalogRecipe(
          id: '11009',
          name: 'Kir Royale',
          ingredients: const [('Crème de cassis', '1 oz')],
        ),
      ),
    ]);
    await tester.tap(keyed('mode-ingredient'));
    await tester.pumpAndSettle();
    await tester.enterText(keyed('discovery-query'), 'creme');
    await tester.pumpAndSettle();
    expect(find.text('Crème de cassis'), findsOneWidget);
  });

  testWidgets('"lime jiuce" (typo) matches Lime juice', (tester) async {
    await _openWith(tester, [
      Recipe.fromJson(
        catalogRecipe(
          id: '11009',
          name: 'Daiquiri',
          ingredients: const [('Lime juice', '1 oz')],
        ),
      ),
    ]);
    await tester.tap(keyed('mode-ingredient'));
    await tester.pumpAndSettle();
    await tester.enterText(keyed('discovery-query'), 'lime jiuce');
    await tester.pumpAndSettle();
    expect(find.text('Lime juice'), findsOneWidget);
  });

  testWidgets(
    'Enter with no highlighted suggestion still submits free text',
    (tester) async {
      await _openWith(tester, [
        Recipe.fromJson(catalogRecipe(id: '11009', name: 'Old Fashioned')),
      ]);
      await tester.enterText(keyed('discovery-query'), 'old fash');
      await tester.pumpAndSettle();
      // No Up/Down pressed: Enter must submit the free-text query, not
      // silently commit a suggestion.
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(router(tester).state.uri.queryParameters, {
        'mode': 'name',
        'q': 'old fash',
      });
      expect(keyed('recipe-11009'), findsOneWidget);
    },
  );
}
