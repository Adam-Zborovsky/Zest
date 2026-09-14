import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zest/app/zest_app.dart';
import 'package:zest/core/widgets/zest_button.dart';
import 'package:zest/features/catalog/data/catalog_database.dart';
import 'package:zest/features/catalog/data/catalog_repository.dart';
import 'package:zest/features/catalog/data/catalog_snapshot_client.dart';
import 'package:zest/features/catalog/domain/catalog_snapshot.dart';
import 'package:zest/features/catalog/domain/coverage_report.dart';
import 'package:zest/features/discovery/application/discovery_providers.dart';
import 'package:zest/features/discovery/data/cocktail_db_client.dart';
import 'package:zest/features/discovery/domain/recipe.dart';
import 'package:zest/features/home_bar/application/home_bar_providers.dart';
import 'package:zest/features/home_bar/domain/home_bar_item.dart';

import '../../../support/bar_fixtures.dart';
import '../../../support/catalog_wiring.dart';
import '../../../support/collection_test_overrides.dart';
import '../../../support/in_memory_home_bar_repository.dart';
import '../../../support/in_memory_session.dart';
import '../../../support/load_fonts.dart';

Finder keyed(String value) => find.byKey(ValueKey(value));

const ingredientOptions = [
  'Imaginary gin',
  'Lime juice',
  'Pretend lime juice',
  'Unlisted bitters',
];

List<Map<String, dynamic>> gardenRecipes() => [
  barRecipeJson(
    id: '99001',
    name: 'Garden Gimlet',
    ingredients: [('Imaginary gin', '2 oz'), ('Fresh Lime Juice', '1 oz')],
  ),
  barRecipeJson(
    id: '99002',
    name: 'Garden Sour',
    ingredients: [
      ('Imaginary gin', '2 oz'),
      ('Pretend lime juice', '1 oz'),
      ('Nutmeg', null),
    ],
  ),
  barRecipeJson(
    id: '99003',
    name: 'Garden Bitter',
    ingredients: [('Imaginary gin', '2 oz'), ('Unlisted bitters', '2 dashes')],
  ),
];

http.Response _json(Object body) => http.Response(
  jsonEncode(body),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Future<http.Response> _respond(
  http.Request request, {
  bool rateLimitOnce = false,
}) async {
  if (request.url.path.endsWith('list.php')) {
    return _json({
      'drinks': [
        for (final name in ingredientOptions) {'strIngredient1': name},
      ],
    });
  }
  if (request.url.path.endsWith('lookup.php')) {
    final id = request.url.queryParameters['i']!;
    final recipe = gardenRecipes().firstWhere(
      (record) => record['idDrink'] == id,
      orElse: () => barRecipeJson(id: id, name: 'Paper Garden $id'),
    );
    return _json({
      'drinks': [recipe],
    });
  }
  return _json({'drinks': gardenRecipes()});
}

/// Returns the seeded catalog database so a test can, e.g., empty it after
/// reaching a scope built from it — forcing a subsequent detail read
/// through the gateway fallback (`docs/M11.md` "Recipe detail").
Future<CatalogDatabase> openApp(
  WidgetTester tester, {
  required Future<http.Response> Function(http.Request) respond,
  // Since M5, `/` is the home screen; tests that used to ride the old
  // `/` → `/discover` redirect now start on discovery explicitly.
  String location = '/discover',
  Size size = const Size(900, 1200),
  DateTime Function()? now,
  List<String> stocked = const ['Imaginary gin'],
  List<Recipe> catalogRecipes = const [],
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final transport = MockClient(respond);
  final client = CocktailDbClient(client: transport);
  final repository = InMemoryHomeBarRepository([
    for (final name in stocked)
      HomeBarItem(
        ingredientId: name.toLowerCase(),
        displayName: name,
        location: HomeBarLocation.stocked,
        updatedAt: DateTime.utc(2026, 9, 14),
      ),
  ]);
  addTearDown(() {
    client.close();
    transport.close();
  });
  addTearDown(repository.dispose);
  // homeBarCatalogFreshnessProvider watches the shared catalog update
  // controller, which otherwise pulls in the real (path_provider-backed)
  // catalog database — never touched directly by this screen's own
  // overrides below.
  final catalogDatabase = openInMemoryCatalog();
  addTearDown(catalogDatabase.close);
  // Discover's results and suggestions now read the local catalog
  // (docs/M11.md "Surfaces"), so the recipes `_respond` used to hand back
  // over the network for any search must actually be stored locally.
  await CatalogRepository(database: catalogDatabase).applySnapshot(
    CatalogSnapshot(
      version: List.filled(64, 'b').join(),
      publishedAt: DateTime.utc(2026, 9, 14),
      recipeCount: gardenRecipes().length,
      attribution: CatalogAttribution(
        name: 'TheCocktailDB',
        url: Uri.parse('https://www.thecocktaildb.com'),
      ),
      drinks: [for (final record in gardenRecipes()) Recipe.fromJson(record)],
    ),
  );
  final catalogFetcher = FakeCatalogSnapshotFetcher()
    ..enqueueAvailable(const CatalogSnapshotUnchanged());
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...catalogTestOverrides(database: catalogDatabase, fetcher: catalogFetcher),
        cocktailDbClientProvider.overrideWithValue(client),
        homeBarRepositoryProvider.overrideWithValue(repository),
        homeBarCatalogRecipesProvider.overrideWith(
          (ref) async => catalogRecipes,
        ),
        homeBarCatalogCoverageProvider.overrideWith(
          (ref) async => CoverageReport(
            recipeCount: catalogRecipes.length,
            publishedAt: catalogRecipes.isEmpty ? null : DateTime.utc(2026, 9, 14),
          ),
        ),
        homeBarCatalogIngredientOptionsProvider.overrideWith(
          (ref) async => [
            for (final name in ingredientOptions)
              HomeBarCatalogIngredient(
                ingredientId: name.toLowerCase(),
                displayName: name,
              ),
          ],
        ),
        if (now != null) nowProvider.overrideWithValue(now),
        ...collectionTestOverrides(),
        ...sessionTestOverrides(),
      ],
      child: ZestApp(initialLocation: location),
    ),
  );
  await tester.pumpAndSettle();
  await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  await tester.pumpAndSettle();
  return catalogDatabase;
}

/// Wipes every stored recipe, so any id already captured in a `RecipeScope`
/// now misses the local catalog and its detail falls to the gateway.
Future<void> emptyCatalog(CatalogDatabase database) =>
    CatalogRepository(database: database).applySnapshot(
      CatalogSnapshot(
        version: List.filled(64, '0').join(),
        publishedAt: DateTime.utc(2026, 9, 14),
        recipeCount: 0,
        attribution: CatalogAttribution(
          name: 'TheCocktailDB',
          url: Uri.parse('https://www.thecocktaildb.com'),
        ),
        drinks: const [],
      ),
    );

Future<void> activate(WidgetTester tester, Finder target) async {
  if (target.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      target,
      400,
      scrollable: find.byType(Scrollable).last,
      maxScrolls: 60,
    );
  }
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

GoRouter router(WidgetTester tester) =>
    GoRouter.of(tester.element(find.byType(Scaffold).last));

Future<void> search(WidgetTester tester, String query) async {
  await tester.ensureVisible(keyed('discovery-query'));
  await tester.enterText(keyed('discovery-query'), query);
  await tester.pump();
  // Close the suggestion panel the query now opens (docs/M11.md "Discover")
  // — otherwise it can sit over the submit button and swallow the tap.
  await tester.sendKeyEvent(LogicalKeyboardKey.escape);
  await tester.pump();
  await activate(tester, keyed('search-submit'));
}

void expectReadable(WidgetTester tester) {
  expect(tester.takeException(), isNull);
  for (final paragraph in tester.renderObjectList<RenderParagraph>(
    find.byType(RichText),
  )) {
    expect(
      paragraph.didExceedMaxLines,
      isFalse,
      reason: 'Text must remain readable: ${paragraph.text.toPlainText()}',
    );
  }
}

void main() {
  setUpAll(loadZestFonts);

  testWidgets('direct bar link opens the durable shelf and links discovery', (
    tester,
  ) async {
    var requests = 0;
    await openApp(
      tester,
      location: '/bar',
      stocked: const [],
      respond: (_) async {
        requests++;
        return _json({'drinks': null});
      },
    );
    expect(find.text('Your botanical shelf'), findsOneWidget);
    expect(find.text('No local recipes to match yet'), findsOneWidget);
    expect(keyed('bar-find-matches'), findsNothing);
    expect(requests, 0);
    await activate(tester, find.text('Explore discovery'));
    expect(router(tester).state.uri.path, '/discover');
  });

  testWidgets('persistent inventory sorts the scoped collection into three buckets', (
    tester,
  ) async {
    await openApp(
      tester,
      respond: _respond,
      stocked: const ['Imaginary gin', 'Pretend lime juice', 'Lime juice'],
    );
    await search(tester, 'Garden');
    await activate(tester, keyed('bar-from-preview'));
    expect(router(tester).state.uri.path, '/bar');

    // Scope is labeled and bounded; availability comes from My bar.
    expect(find.text('Recipes for “Garden”'), findsOneWidget);
    expect(find.textContaining('3 recipes.'), findsOneWidget);
    expect(
      find.text('3 ingredients are stocked and used for this match.'),
      findsOneWidget,
    );
    expect(
      tester.widget<ZestButton>(keyed('bar-find-matches')).onPressed,
      isNotNull,
    );

    await activate(tester, keyed('bar-find-matches'));

    expect(find.text('Ready to make'), findsOneWidget);
    expect(find.text('Garden Sour'), findsOneWidget);
    expect(
      find.text('Ready now — every essential is on your shelf.'),
      findsOneWidget,
    );
    expect(find.textContaining('Garnish not counted: Nutmeg.'), findsOneWidget);

    expect(find.text('Possible with a substitution'), findsOneWidget);
    expect(find.text('Garden Gimlet'), findsOneWidget);
    expect(
      find.textContaining(
        'Use Lime juice instead of Fresh Lime Juice — a reviewed suggestion.',
      ),
      findsOneWidget,
    );

    expect(find.text('Missing essentials'), findsOneWidget);
    expect(find.text('Garden Bitter'), findsOneWidget);
    expect(
      find.textContaining('Missing 1 essential: Unlisted bitters.'),
      findsOneWidget,
    );

    expect(
      find.text(
        'Finished checking 3 of 3 recipes. 1 ready, 1 with a substitution, 1 missing essentials.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Checked 3 of 3 recipes in this collection — not the full cocktail catalog.',
      ),
      findsOneWidget,
    );
    expectReadable(tester);

    // Re-running matching replaces the previous results without duplicating.
    await activate(tester, keyed('bar-find-matches'));
    expect(find.text('Garden Sour'), findsOneWidget);
    expect(find.text('Garden Gimlet'), findsOneWidget);
    expect(find.text('Garden Bitter'), findsOneWidget);
    expect(
      find.text(
        'Finished checking 3 of 3 recipes. 1 ready, 1 with a substitution, 1 missing essentials.',
      ),
      findsOneWidget,
    );
    expectReadable(tester);
  });

  testWidgets(
    'home bar picker searches, adds, removes, and closes with Escape',
    (tester) async {
      await openApp(
        tester,
        location: '/bar',
        respond: _respond,
        stocked: const [],
        catalogRecipes: [
          for (final record in gardenRecipes()) Recipe.fromJson(record),
        ],
      );
      await activate(tester, keyed('home-bar-add-ingredient'));
      await tester.enterText(keyed('home-bar-catalog-search'), 'gin');
      await tester.pumpAndSettle();
      expect(find.text('Showing 1 of 4 catalog ingredients.'), findsOneWidget);
      expect(keyed('home-bar-catalog-option-imaginary gin'), findsOneWidget);
      expect(keyed('home-bar-catalog-option-lime juice'), findsNothing);
      await tester.enterText(keyed('home-bar-catalog-search'), 'zzz');
      await tester.pumpAndSettle();
      expect(
        find.textContaining('No catalog ingredient matches'),
        findsOneWidget,
      );
      await tester.enterText(keyed('home-bar-catalog-search'), '');
      await activate(tester, keyed('home-bar-catalog-option-imaginary gin'));
      expect(find.text('1 ingredient stocked.'), findsOneWidget);
      await activate(tester, find.widgetWithText(ZestButton, 'Remove'));
      expect(find.textContaining('Your shelf is empty.'), findsOneWidget);
      expectReadable(tester);

      // Escape still closes the sheet without a pointer.
      await activate(tester, keyed('home-bar-add-ingredient'));
      expect(find.text('Add to your bar'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Add to your bar'), findsNothing);
      expectReadable(tester);
    },
  );

  testWidgets('a rate limit pauses matching and resumes after the cooldown', (
    tester,
  ) async {
    var clock = DateTime.utc(2026, 9, 12);
    var limited = false;
    final catalogDatabase = await openApp(
      tester,
      now: () => clock,
      respond: (request) async {
        if (request.url.path.endsWith('lookup.php') && !limited) {
          limited = true;
          return http.Response('', 429, headers: {'retry-after': '2'});
        }
        return _respond(request);
      },
    );
    await search(tester, 'Garden');
    await activate(tester, keyed('bar-from-preview'));
    // Force this scope's detail reads through the gateway (docs/M11.md
    // "Recipe detail" is local-first, and every scoped id is in the
    // catalog seeded by openApp) so the mocked 429 above is reachable.
    await emptyCatalog(catalogDatabase);
    await activate(tester, keyed('bar-find-matches'));
    // The 429's discarded byte-stream cancellation completes in the root
    // zone; drain it the same way openDiscovery does, then settle.
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();

    expect(find.text('A moment for the source'), findsOneWidget);
    expect(find.text('Try again'), findsNothing);
    final waiting = find.textContaining('Try again in');
    expect(waiting, findsOneWidget);
    expect(find.text('Matching within'), findsOneWidget);

    clock = clock.add(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 3));
    await activate(tester, find.text('Try again'));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    // With only gin selected, all three recipes miss an essential.
    expect(
      find.text(
        'Finished checking 3 of 3 recipes. 0 ready, 0 with a substitution, 3 missing essentials.',
      ),
      findsOneWidget,
    );
    expectReadable(tester);
  });

  testWidgets('match cards open the source recipe detail', (tester) async {
    await openApp(tester, respond: _respond);
    await search(tester, 'Garden');
    await activate(tester, keyed('bar-from-preview'));
    await activate(tester, keyed('bar-find-matches'));
    await activate(tester, keyed('bar-recipe-99002'));
    expect(router(tester).state.uri.path, '/discover/recipe/99002');
    expect(find.text('Garden Sour'), findsOneWidget);
    router(tester).pop();
    await tester.pumpAndSettle();
    expect(router(tester).state.uri.path, '/bar');
    // Results survive the round trip; with only gin selected every recipe
    // is missing at least one essential.
    expect(find.text('Missing essentials'), findsOneWidget);
    expect(find.text('Garden Sour'), findsOneWidget);
    expect(
      find.text(
        'Finished checking 3 of 3 recipes. 0 ready, 0 with a substitution, 3 missing essentials.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('keyboard starts matching with persistent inventory', (
    tester,
  ) async {
    await openApp(tester, respond: _respond);
    await search(tester, 'Garden');
    await activate(tester, keyed('bar-from-preview'));

    Future<bool> tabTo(String key) async {
      for (var tab = 0; tab < 40; tab++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        final focused = FocusManager.instance.primaryFocus?.context;
        if (focused == null) continue;
        var found = false;
        focused.visitAncestorElements((element) {
          if (element.widget.key == ValueKey(key)) {
            found = true;
            return false;
          }
          return true;
        });
        if (found) return true;
      }
      return false;
    }

    expect(await tabTo('bar-find-matches'), isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('Missing essentials'), findsOneWidget);
    expect(find.text('Garden Sour'), findsOneWidget);
    expectReadable(tester);
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets('bar flow remains readable at 320px and ${scale}x', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await openApp(tester, size: const Size(320, 720), respond: _respond);
      await search(tester, 'Garden');
      await activate(tester, keyed('bar-from-preview'));
      expectReadable(tester);
      await activate(tester, keyed('bar-find-matches'));
      expectReadable(tester);
    });
  }
}
