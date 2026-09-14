import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:zest/app/zest_app.dart';
import 'package:zest/features/catalog/data/catalog_snapshot_client.dart';
import 'package:zest/features/catalog/domain/coverage_report.dart';
import 'package:zest/features/discovery/domain/recipe.dart';
import 'package:zest/features/home_bar/application/home_bar_providers.dart';
import 'package:zest/features/home_bar/domain/home_bar_item.dart';

import '../../../support/bar_fixtures.dart';
import '../../../support/catalog_wiring.dart';
import '../../../support/collection_test_overrides.dart';
import '../../../support/in_memory_session.dart';
import '../../../support/in_memory_home_bar_repository.dart';
import '../../../support/load_fonts.dart';

Recipe _recipe(String id, String name, List<(String, String?)> ingredients) =>
    Recipe.fromJson(
      barRecipeJson(id: id, name: name, ingredients: ingredients),
    );

Future<void> _open(
  WidgetTester tester, {
  required InMemoryHomeBarRepository repository,
  required List<Recipe> recipes,
  String location = '/bar',
}) async {
  addTearDown(repository.dispose);
  // homeBarCatalogFreshnessProvider watches the shared catalog update
  // controller, which otherwise pulls in the real (path_provider-backed)
  // catalog database — never touched directly by this screen's own
  // overrides below.
  final catalogDatabase = openInMemoryCatalog();
  addTearDown(catalogDatabase.close);
  final catalogFetcher = FakeCatalogSnapshotFetcher()
    ..enqueueAvailable(const CatalogSnapshotUnchanged());
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...catalogTestOverrides(database: catalogDatabase, fetcher: catalogFetcher),
        homeBarRepositoryProvider.overrideWithValue(repository),
        homeBarCatalogRecipesProvider.overrideWith((ref) async => recipes),
        homeBarCatalogCoverageProvider.overrideWith(
          (ref) async => CoverageReport(
            recipeCount: recipes.length,
            publishedAt: DateTime.utc(2026, 9, 14),
          ),
        ),
        homeBarCatalogIngredientOptionsProvider.overrideWith(
          (ref) async => [
            for (final recipe in recipes)
              for (final ingredient in recipe.ingredients)
                HomeBarCatalogIngredient(
                  ingredientId: ingredient.normalizedName,
                  displayName: ingredient.name,
                ),
          ],
        ),
        ...collectionTestOverrides(),
        ...sessionTestOverrides(),
      ],
      child: ZestApp(initialLocation: location),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadZestFonts);

  testWidgets('catalog-backed shelf adds missing essentials to shopping', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = InMemoryHomeBarRepository([
      HomeBarItem(
        ingredientId: 'imaginary gin',
        displayName: 'Imaginary gin',
        location: HomeBarLocation.stocked,
        updatedAt: DateTime.utc(2026, 9, 14),
      ),
    ]);
    await _open(
      tester,
      repository: repository,
      recipes: [
        _recipe('99100', 'Shelf sour', [
          ('Imaginary gin', '2 oz'),
          ('Pretend lime juice', '1 oz'),
          ('Nutmeg', null),
        ]),
      ],
    );

    expect(find.text('Matches from your local catalog'), findsOneWidget);
    expect(find.text('Missing essentials'), findsOneWidget);
    expect(find.textContaining('Garnish not counted: Nutmeg.'), findsOneWidget);
    final addMissing = find.byKey(const ValueKey('home-bar-add-missing-99100'));
    await tester.tap(addMissing);
    await tester.pumpAndSettle();
    expect(
      repository.items.any(
        (item) =>
            item.location == HomeBarLocation.shopping &&
            item.displayName == 'Pretend lime juice',
      ),
      isTrue,
    );
    expect(find.textContaining('1 ingredient stocked'), findsOneWidget);
    expect(find.text('Missing essentials added to shopping.'), findsOneWidget);
  });

  testWidgets(
    'catalog picker is keyboard reachable and states its result count',
    (tester) async {
      final repository = InMemoryHomeBarRepository();
      await _open(
        tester,
        repository: repository,
        recipes: [
          _recipe('99101', 'Catalog drink', [('Imaginary gin', '2 oz')]),
        ],
      );

      await tester.tap(find.byKey(const ValueKey('home-bar-add-ingredient')));
      await tester.pumpAndSettle();
      expect(find.text('Add to your bar'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('home-bar-catalog-search')),
        'gin',
      );
      await tester.pump();
      expect(find.text('Showing 1 of 1 catalog ingredients.'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('home-bar-catalog-option-imaginary gin')),
      );
      await tester.pumpAndSettle();
      expect(find.text('1 ingredient stocked.'), findsOneWidget);
    },
  );

  testWidgets('home bar reflows at 320 logical pixels and 2x text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await _open(
      tester,
      repository: InMemoryHomeBarRepository(),
      recipes: const [],
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Your botanical shelf'), findsOneWidget);
  });

  testWidgets('shopping is route-backed and Back returns to the shelf', (
    tester,
  ) async {
    await _open(
      tester,
      repository: InMemoryHomeBarRepository(),
      recipes: const [],
    );
    final router = GoRouter.of(tester.element(find.byType(Scaffold).last));

    await tester.tap(find.byKey(const ValueKey('shopping-destination')));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/bar/shopping');
    expect(find.text('A short list for later'), findsOneWidget);

    router.pop();
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/bar');
    expect(find.text('Your botanical shelf'), findsOneWidget);
  });

  testWidgets('botanical shelf golden', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _open(
      tester,
      repository: InMemoryHomeBarRepository([
        HomeBarItem(
          ingredientId: 'imaginary gin',
          displayName: 'Imaginary gin',
          location: HomeBarLocation.stocked,
          updatedAt: DateTime.utc(2026, 9, 14),
        ),
      ]),
      recipes: [
        _recipe('99102', 'Garden shelf', [
          ('Imaginary gin', '2 oz'),
          ('Pretend lime juice', '1 oz'),
        ]),
      ],
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/home-bar-shelf.png'),
    );
  });

  testWidgets('shopping checklist golden', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _open(
      tester,
      location: '/bar/shopping',
      repository: InMemoryHomeBarRepository([
        HomeBarItem(
          ingredientId: 'pretend lime juice',
          displayName: 'Pretend lime juice',
          location: HomeBarLocation.shopping,
          updatedAt: DateTime.utc(2026, 9, 14),
        ),
      ]),
      recipes: const [],
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/home-bar-shopping.png'),
    );
  });
}
