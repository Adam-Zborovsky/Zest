import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zest/app/zest_app.dart';
import 'package:zest/core/network/cocktail_api_exception.dart';
import 'package:zest/features/catalog/application/catalog_providers.dart';
import 'package:zest/features/catalog/data/catalog_repository.dart';
import 'package:zest/features/discovery/application/discovery_providers.dart';
import 'package:zest/features/discovery/data/cocktail_db_client.dart';
import 'package:zest/features/discovery/domain/recipe.dart';
import 'package:zest/features/discovery/presentation/discovery_widgets.dart';

import '../../../support/catalog_fixtures.dart';
import '../../../support/catalog_wiring.dart';
import '../../../support/collection_test_overrides.dart';
import '../../../support/in_memory_session.dart';
import '../../../support/discovery_fixtures.dart';
import '../../../support/load_fonts.dart';

Finder keyed(String value) => find.byKey(ValueKey(value));

/// `discovery-query`'s key is on the outer `ZestSuggestionField` now; this
/// descends to the actual `TextFormField` it wraps.
String queryFieldText(WidgetTester tester) => tester
    .widget<TextFormField>(
      find.descendant(
        of: keyed('discovery-query'),
        matching: find.byType(TextFormField),
      ),
    )
    .controller!
    .text;

Future<void> openDiscovery(
  WidgetTester tester, {
  required Future<http.Response> Function(http.Request) respond,
  // Since M5, `/` is the home screen; these tests exercise discovery, and
  // previously reached it through the old `/` → `/discover` redirect.
  String location = '/discover',
  Size size = const Size(900, 1200),
  Future<bool> Function(Uri)? launchSource,
  DateTime Function()? now,
  // Discover's results and suggestions read the local catalog now
  // (docs/M11.md "Surfaces"); seed it for tests exercising local
  // name/ingredient/letter matching. Left empty, `recipeById` misses and
  // `respond` above serves the `lookup.php` fallback.
  List<Recipe> catalogRecipes = const [],
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final transport = MockClient(respond);
  final client = CocktailDbClient(client: transport);
  addTearDown(() {
    client.close();
    transport.close();
  });
  final database = openInMemoryCatalog();
  addTearDown(database.close);
  final repository = CatalogRepository(database: database);
  if (catalogRecipes.isNotEmpty) {
    await repository.applySnapshot(catalogSnapshotFixture(drinks: catalogRecipes));
  }
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        cocktailDbClientProvider.overrideWithValue(client),
        catalogRepositoryProvider.overrideWithValue(repository),
        if (launchSource != null)
          sourceLauncherProvider.overrideWithValue(launchSource),
        if (now != null) nowProvider.overrideWithValue(now),
        ...collectionTestOverrides(),
        ...sessionTestOverrides(),
      ],
      child: ZestApp(initialLocation: location),
    ),
  );
  await tester.pumpAndSettle();
  // MockClient's discarded byte-stream cancellation can finish in the root
  // zone. Drain that event turn without adding network or arbitrary delays.
  await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  await tester.pumpAndSettle();
}

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

GoRouter router(WidgetTester tester) =>
    GoRouter.of(tester.element(find.byType(Scaffold).last));

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

  testWidgets('launch and blank submission do not request provider records', (
    tester,
  ) async {
    var requests = 0;
    await openDiscovery(
      tester,
      respond: (_) async {
        requests++;
        return discoveryResponse(null);
      },
    );
    expect(keyed('discovery-query'), findsOneWidget);
    expect(requests, 0);
    await search(tester, '   ');
    expect(requests, 0);
    expect(find.byType(Form), findsOneWidget);
    expect(find.text('Enter a name to start your search.'), findsOneWidget);
    expect(tester.testTextInput.hasAnyClients, isTrue);
    expectReadable(tester);
  });

  testWidgets(
    'name preview, all results, detail and back preserve the search',
    (tester) async {
      final requests = <Uri>[];
      await openDiscovery(
        tester,
        respond: (request) async {
          requests.add(request.url);
          return discoveryResponse(null);
        },
        catalogRecipes: [
          for (final record in discoveryRecipes())
            Recipe.fromJson(record),
        ],
      );
      await search(tester, 'Paper Garden');
      expect(keyed('recipe-99001'), findsOneWidget);
      expect(keyed('recipe-99007'), findsNothing);
      await activate(tester, keyed('see-all-results'));
      expect(router(tester).state.uri.path, '/discover/results');
      await activate(tester, keyed('recipe-99008'));
      expect(router(tester).state.uri.path, '/discover/recipe/99008');
      // Local-first detail (docs/M11.md "Recipe detail"): this id is in the
      // seeded catalog, so no network request is made at all.
      expect(requests, isEmpty);
      expect(find.text('1 1/2 oz'), findsOneWidget);
      expect(find.text('a small splash'), findsOneWidget);
      expect(find.text('Imaginary leaf syrup'), findsOneWidget);
      expect(
        find.text(
          'Stir the imaginary ingredients. Keep this sentence together.',
        ),
        findsOneWidget,
      );
      expect(
        find.text('Serve in a paper cup; garnish with a fictional leaf.'),
        findsOneWidget,
      );
      // Unnumbered source paragraphs get numbered step seals.
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.bySemanticsLabel('Step 1'), findsOneWidget);
      expect(find.text('Glass: Paper cup'), findsOneWidget);
      expect(find.text('Type: Non alcoholic'), findsOneWidget);
      expect(find.text('Open source recipe'), findsOneWidget);
      router(tester).pop();
      await tester.pumpAndSettle();
      expect(router(tester).state.uri.path, '/discover/results');
      router(tester).pop();
      await tester.pumpAndSettle();
      expect(router(tester).state.uri.queryParameters, {
        'mode': 'name',
        'q': 'Paper Garden',
      });
      expect(
        queryFieldText(tester),
        'Paper Garden',
      );
      expect(requests, isEmpty);
      expectReadable(tester);
    },
  );

  testWidgets(
    'ingredient and letter modes match the local catalog, with no network call',
    (tester) async {
      final requests = <Uri>[];
      await openDiscovery(
        tester,
        respond: (request) async {
          requests.add(request.url);
          return discoveryResponse(null);
        },
        catalogRecipes: [Recipe.fromJson(discoveryRecipes(1).single)],
      );
      await activate(tester, keyed('mode-ingredient'));
      await search(tester, 'Imaginary leaf syrup');
      expect(keyed('recipe-99001'), findsOneWidget);
      await activate(tester, find.text('Browse A–Z'));
      await activate(tester, keyed('letter-p'));
      expect(keyed('recipe-99001'), findsOneWidget);
      expect(router(tester).state.uri.queryParameters, {
        'mode': 'letter',
        'q': 'p',
      });
      expect(requests, isEmpty);
    },
  );

  testWidgets('mode changes and submitted query updates preserve field text', (
    tester,
  ) async {
    final requests = <Uri>[];
    await openDiscovery(
      tester,
      respond: (request) async {
        requests.add(request.url);
        return discoveryResponse(null);
      },
    );
    String fieldValue() => queryFieldText(tester);
    await tester.enterText(keyed('discovery-query'), 'Draft botanical');
    await activate(tester, keyed('mode-ingredient'));
    expect(fieldValue(), 'Draft botanical');
    await activate(tester, keyed('search-submit'));
    expect(fieldValue(), 'Draft botanical');
    await activate(tester, keyed('mode-name'));
    expect(fieldValue(), 'Draft botanical');
    await search(tester, 'Second botanical');
    expect(fieldValue(), 'Second botanical');
    router(tester).go('/discover?mode=name&q=Third');
    await tester.pumpAndSettle();
    expect(fieldValue(), 'Third');
    // Discover's results are local now (docs/M11.md "Surfaces"); no query
    // ever reaches the network.
    expect(requests, isEmpty);
  });

  testWidgets('keyboard search and result activation require no pointer', (
    tester,
  ) async {
    final requests = <Uri>[];
    await openDiscovery(
      tester,
      respond: (request) async {
        requests.add(request.url);
        return discoveryResponse(null);
      },
      catalogRecipes: [Recipe.fromJson(discoveryRecipes(1).single)],
    );
    for (var tab = 0; tab < 12; tab++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      if (tester.testTextInput.hasAnyClients) break;
    }
    expect(tester.testTextInput.hasAnyClients, isTrue);
    tester.testTextInput.enterText('Paper');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(requests, isEmpty);
    var reachedResult = false;
    for (var tab = 0; tab < 40; tab++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final focusedContext = FocusManager.instance.primaryFocus?.context;
      if (focusedContext == null) continue;
      var found = focusedContext.widget.key == const ValueKey('recipe-99001');
      focusedContext.visitAncestorElements((element) {
        if (element.widget.key == const ValueKey('recipe-99001')) {
          found = true;
          return false;
        }
        return true;
      });
      if (found) {
        reachedResult = true;
        break;
      }
    }
    expect(
      reachedResult,
      isTrue,
      reason: FocusManager.instance.rootScope.toStringDeep(),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(router(tester).state.uri.path, '/discover/recipe/99001');
    expectReadable(tester);
  });

  testWidgets(
    'navigating between two name queries always shows the latest, never a stale one',
    (tester) async {
      // Discover's results are a synchronous local read now (docs/M11.md
      // "Surfaces"), so the old network-race scenario (an earlier slow
      // response arriving after a newer one) no longer applies; this
      // instead guards the family-keyed provider's per-query identity when
      // routing quickly between two queries.
      await openDiscovery(
        tester,
        respond: (_) async => discoveryResponse(null),
        catalogRecipes: [
          Recipe.fromJson(discoveryRecipe(id: '99001', name: 'Older Paper Garden')),
          Recipe.fromJson(discoveryRecipe(id: '99002', name: 'Newer Paper Garden')),
        ],
      );
      router(tester).go('/discover?mode=name&q=Older');
      await tester.pumpAndSettle();
      expect(keyed('recipe-99001'), findsOneWidget);
      expect(keyed('recipe-99002'), findsNothing);
      router(tester).go('/discover?mode=name&q=Newer');
      await tester.pumpAndSettle();
      expect(keyed('recipe-99001'), findsNothing);
      expect(keyed('recipe-99002'), findsOneWidget);
      expect(router(tester).state.uri.queryParameters['q'], 'Newer');
    },
  );

  testWidgets(
    'an empty catalog shows the download state instead of empty results',
    (tester) async {
      // docs/M11.md "Surfaces": with no local catalog yet, results areas
      // show the catalog download state (downloading, or failed with
      // Retry) rather than a false "no results found".
      final fetcher = FakeCatalogSnapshotFetcher()
        ..enqueueError(
          const CocktailApiException(CocktailApiErrorKind.network),
        );
      final database = openInMemoryCatalog();
      addTearDown(database.close);
      final container = ProviderContainer(
        overrides: [
          ...catalogTestOverrides(database: database, fetcher: fetcher),
          cocktailDbClientProvider.overrideWithValue(
            CocktailDbClient(client: MockClient((_) async => discoveryResponse(null))),
          ),
          ...collectionTestOverrides(),
          ...sessionTestOverrides(),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const ZestApp(initialLocation: '/discover?mode=name&q=Paper'),
        ),
      );
      await tester.pumpAndSettle();
      // The app shell's own launch check (finding #3) already ran on the
      // first frame above — no route-specific screen needs to trigger it,
      // and a cold deep link straight to /discover exercises exactly that.
      expect(find.text("Couldn't download the catalog"), findsOneWidget);
      expect(keyed('catalog-download-failed'), findsOneWidget);
    },
  );

  testWidgets(
    'finding #12: a cold deep link to /discover/results with an empty '
    'catalog shows the download state, not empty results',
    (tester) async {
      final fetcher = FakeCatalogSnapshotFetcher()
        ..enqueueError(
          const CocktailApiException(CocktailApiErrorKind.network),
        );
      final database = openInMemoryCatalog();
      addTearDown(database.close);
      final container = ProviderContainer(
        overrides: [
          ...catalogTestOverrides(database: database, fetcher: fetcher),
          cocktailDbClientProvider.overrideWithValue(
            CocktailDbClient(client: MockClient((_) async => discoveryResponse(null))),
          ),
          ...collectionTestOverrides(),
          ...sessionTestOverrides(),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const ZestApp(
            initialLocation: '/discover/results?mode=name&q=Paper',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(keyed('results-catalog-status'), findsOneWidget);
      expect(find.text('No recipes found'), findsNothing);
    },
  );

  testWidgets(
    'empty search and missing recipe are distinct recoverable states',
    (tester) async {
      await openDiscovery(
        tester,
        location: '/discover?mode=name&q=Nothing',
        respond: (_) async => discoveryResponse(null),
        // A non-empty catalog that just doesn't match "Nothing" — a real
        // no-results outcome, distinct from the empty-catalog download
        // state covered above.
        catalogRecipes: [Recipe.fromJson(discoveryRecipes(1).single)],
      );
      expect(keyed('recipe-99001'), findsNothing);
      expect(find.text('Try again'), findsNothing);
      expect(find.text('No recipes found'), findsOneWidget);
      expect(keyed('discovery-query'), findsOneWidget);
      router(tester).go('/discover/recipe/99999');
      await tester.pumpAndSettle();
      expect(find.text('Recipe not found'), findsOneWidget);
      await activate(tester, find.byTooltip('Back'));
      expect(router(tester).state.uri.path, '/discover');
      expect(keyed('discovery-query'), findsOneWidget);
    },
  );

  testWidgets('invalid recipe link is rejected without a network request', (
    tester,
  ) async {
    var requests = 0;
    await openDiscovery(
      tester,
      location: '/discover/recipe/not-a-number',
      respond: (_) async {
        requests++;
        return discoveryResponse(null);
      },
    );
    expect(find.text('That recipe link is not valid'), findsOneWidget);
    expect(requests, 0);
    await activate(tester, find.byTooltip('Back'));
    expect(keyed('discovery-query'), findsOneWidget);
  });

  testWidgets('source launch failure exposes the canonical source address', (
    tester,
  ) async {
    final launched = <Uri>[];
    await openDiscovery(
      tester,
      location: '/discover/recipe/99001',
      respond: (_) async => discoveryResponse(discoveryRecipes(1)),
      launchSource: (uri) async {
        launched.add(uri);
        return false;
      },
    );
    await activate(tester, find.text('Open source recipe'));
    expect(
      launched.single.toString(),
      'https://www.thecocktaildb.com/drink/99001',
    );
    expect(
      find.text(
        'Could not open the source. Copy this address into your browser:',
      ),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(SelectableText, launched.single.toString()),
      findsOneWidget,
    );
  });

  for (final scale in [1.0, 2.0, 3.0]) {
    testWidgets('search and detail remain readable at 320px and ${scale}x', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await openDiscovery(
        tester,
        size: const Size(320, 720),
        respond: (_) async => discoveryResponse(null),
        catalogRecipes: [Recipe.fromJson(discoveryRecipes(1).single)],
      );
      expectReadable(tester);
      await search(tester, 'Paper Garden');
      expectReadable(tester);
      await activate(tester, keyed('recipe-99001'));
      expectReadable(tester);
      await tester.ensureVisible(find.text('Open source recipe'));
      await tester.pumpAndSettle();
      expectReadable(tester);
    });
  }
}
