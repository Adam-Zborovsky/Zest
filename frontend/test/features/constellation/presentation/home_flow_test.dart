import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zest/app/zest_app.dart';
import 'package:zest/core/network/cocktail_api_exception.dart';
import 'package:zest/features/catalog/data/catalog_repository.dart';
import 'package:zest/features/catalog/data/catalog_snapshot_client.dart';
import 'package:zest/features/constellation/domain/graph_layout.dart';
import 'package:zest/features/constellation/domain/ingredient_graph.dart';
import 'package:zest/features/constellation/presentation/constellation_canvas.dart';
import 'package:zest/features/constellation/presentation/constellation_painter.dart';
import 'package:zest/features/constellation/presentation/constellation_widgets.dart';
import 'package:zest/features/discovery/application/discovery_providers.dart';
import 'package:zest/features/discovery/data/cocktail_db_client.dart';
import 'package:zest/features/discovery/domain/recipe.dart';
import 'package:zest/features/home_bar/application/home_bar_providers.dart';

import '../../../support/catalog_fixtures.dart';
import '../../../support/catalog_wiring.dart';
import '../../../support/collection_test_overrides.dart';
import '../../../support/in_memory_home_bar_repository.dart';
import '../../../support/in_memory_session.dart';
import '../../../support/load_fonts.dart';

Finder keyed(String value) => find.byKey(ValueKey(value));

http.Response _json(Object body) => http.Response(
  jsonEncode(body),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

/// Detail lookups come from the discovery provider layer; everything else is
/// unused on home.
Future<http.Response> _respond(http.Request request) async {
  if (request.url.path.endsWith('lookup.php')) {
    final id = request.url.queryParameters['i']!;
    return _json({
      'drinks': [catalogRecipe(id: id, name: 'Testbench Tonic')],
    });
  }
  return _json({'drinks': null});
}

/// Opens home with the full app shell. [seed] pre-loads the on-device
/// catalog before launch; [prepareFetcher] configures what the
/// background/launch check finds on the "server" — by default it's
/// "nothing new", so tests that only care about the constellation never
/// trip the update machinery.
Future<FakeCatalogSnapshotFetcher> openHome(
  WidgetTester tester, {
  List<Recipe> seed = const [],
  void Function(FakeCatalogSnapshotFetcher fetcher)? prepareFetcher,
  Size size = const Size(900, 1600),
  DateTime Function()? now,
  bool settle = true,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final database = openInMemoryCatalog();
  addTearDown(database.close);
  final stamp = now ?? () => DateTime(2026, 9, 12, 10);
  final seedRepository = CatalogRepository(database: database, now: stamp);
  if (seed.isNotEmpty) {
    await seedRepository.applySnapshot(
      catalogSnapshotFixture(
        version: fakeCatalogVersion('seed'),
        drinks: seed,
      ),
    );
  }
  final fetcher = FakeCatalogSnapshotFetcher();
  if (prepareFetcher != null) {
    prepareFetcher(fetcher);
  } else {
    fetcher.enqueueAvailable(const CatalogSnapshotUnchanged());
  }
  final transport = MockClient(_respond);
  final client = CocktailDbClient(client: transport);
  final homeBar = InMemoryHomeBarRepository();
  addTearDown(() {
    client.close();
    transport.close();
  });
  addTearDown(homeBar.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...catalogTestOverrides(database: database, fetcher: fetcher, now: now),
        cocktailDbClientProvider.overrideWithValue(client),
        homeBarRepositoryProvider.overrideWithValue(homeBar),
        if (now != null) nowProvider.overrideWithValue(now),
        ...collectionTestOverrides(),
        ...sessionTestOverrides(),
      ],
      child: const ZestApp(),
    ),
  );
  await tester.pump();
  if (settle) {
    await tester.pumpAndSettle();
    // Drain discarded byte-stream completions the same way the discovery
    // and bar suites do.
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
  }
  return fetcher;
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

GoRouter router(WidgetTester tester) =>
    GoRouter.of(tester.element(find.byType(Scaffold).last));

/// Rebuilds the same deterministic layout the canvas computed: same graph
/// from the same synthetic recipes, same canvas size, same default seed.
(RenderBox box, IngredientGraph graph, GraphLayout layout) canvasGeometry(
  WidgetTester tester,
  List<Recipe> recipes,
) {
  final box = tester.renderObject<RenderBox>(keyed('constellation-canvas'));
  final graph = IngredientGraph.build(recipes);
  final layout = GraphLayout.compute(graph, size: box.size);
  return (box, graph, layout);
}

/// The midpoint of an edge far enough from every node for a clean tap,
/// together with the edge it belongs to.
(Offset, IngredientEdge) clearEdgeMidpoint(
  IngredientGraph graph,
  GraphLayout layout,
) {
  for (final edge in graph.edges) {
    final mid = Offset.lerp(
      layout.positionOf(edge.aIdentity),
      layout.positionOf(edge.bIdentity),
      0.5,
    )!;
    final clear = graph.nodes.every((node) {
      final radius = constellationNodeRadius(
        node.prevalence,
        graph.maxPrevalence,
      );
      return (mid - layout.positionOf(node.identity)).distance >
          radius + maxHitRadius + 4;
    });
    if (clear) return (mid, edge);
  }
  fail('No edge midpoint clear of every node.');
}

List<Recipe> threeLetterRecipes() => [
  ...catalogLetterRecipes('a'),
  ...catalogLetterRecipes('b'),
  ...catalogLetterRecipes('c'),
];

/// A synthetic collection wider than the graph's default bound: 41 recipes,
/// each pairing one distinct identity with one shared identity — 42 distinct
/// identities in total, of which only the top 40 are kept.
List<Recipe> wideGardenRecipes() => [
  for (var i = 1; i <= 41; i++)
    Recipe.fromJson(
      catalogRecipe(
        id: '7001${i.toString().padLeft(3, '0')}',
        name: 'Wide Garden $i',
        ingredients: [('Wide Ingredient $i', '1 oz'), ('Shared Tonic', '2 oz')],
      ),
    ),
];

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

  testWidgets('home leads with the constellation and keeps the core tasks '
      'reachable without it', (tester) async {
    await openHome(tester, seed: catalogLetterRecipes('a'));

    expect(find.text('The Ingredient Constellation'), findsOneWidget);
    expect(keyed('constellation-canvas'), findsOneWidget);
    expect(find.text('Your recipe catalog'), findsOneWidget);
    expect(find.text('Follow the lines.'), findsOneWidget);
    expect(keyed('home-bar'), findsOneWidget);

    await activate(tester, keyed('home-discover'));
    expect(router(tester).state.uri.path, '/discover');
  });

  group('catalog download and update (M11)', () {
    testWidgets('an empty catalog downloads and applies automatically on '
        'launch, with no manual action needed', (tester) async {
      await openHome(
        tester,
        prepareFetcher: (fetcher) => fetcher.enqueueAvailable(
          CatalogSnapshotAvailable(
            catalogSnapshotFixture(
              version: fakeCatalogVersion('first'),
              drinks: catalogLetterRecipes('a'),
            ),
          ),
        ),
      );

      expect(find.text('Your recipe catalog'), findsOneWidget);
      expect(find.textContaining('TheCocktailDB catalog, 1 recipe'), findsOneWidget);
      // No leftover manual "download" affordance once a catalog exists.
      expect(keyed('catalog-download'), findsNothing);
    });

    testWidgets('a download failure with an empty catalog shows the branded '
        'error with Retry', (tester) async {
      final fetcher = await openHome(
        tester,
        prepareFetcher: (fetcher) => fetcher.enqueueError(
          const CocktailApiException(CocktailApiErrorKind.network),
        ),
      );

      expect(keyed('catalog-download-failed'), findsOneWidget);
      expect(find.text("Couldn't download the catalog"), findsOneWidget);

      fetcher.enqueueAvailable(
        CatalogSnapshotAvailable(
          catalogSnapshotFixture(drinks: [catalogRecipeModel(id: '1')]),
        ),
      );
      await activate(tester, find.text('Retry'));
      expect(find.text('Your recipe catalog'), findsOneWidget);
    });

    testWidgets('an existing catalog checks in the background, applies a '
        'real change automatically, and shows the update notice', (
      tester,
    ) async {
      await openHome(
        tester,
        seed: [catalogRecipeModel(id: '1', name: 'Old Drink')],
        prepareFetcher: (fetcher) => fetcher.enqueueAvailable(
          CatalogSnapshotAvailable(
            catalogSnapshotFixture(
              version: fakeCatalogVersion('newer'),
              drinks: [
                catalogRecipeModel(id: '1', name: 'Old Drink'),
                catalogRecipeModel(id: '2', name: 'New Drink'),
              ],
            ),
          ),
        ),
      );

      expect(find.textContaining('Catalog updated · 1 new recipe'), findsOneWidget);
      expect(keyed('zest-notice-dismiss'), findsOneWidget);

      await tester.tap(keyed('zest-notice-dismiss'));
      await tester.pumpAndSettle();
      expect(keyed('zest-notice-dismiss'), findsNothing);
    });

    testWidgets('a 304 / unchanged background check shows no notice', (
      tester,
    ) async {
      await openHome(tester, seed: [catalogRecipeModel(id: '1')]);

      expect(keyed('zest-notice-dismiss'), findsNothing);
      expect(find.textContaining('Catalog updated'), findsNothing);
    });

    testWidgets('a background failure with an existing catalog is silent — '
        'the resting card keeps showing the existing collection', (
      tester,
    ) async {
      await openHome(
        tester,
        seed: [catalogRecipeModel(id: '1', name: 'Kept Drink')],
        prepareFetcher: (fetcher) => fetcher.enqueueError(
          const CocktailApiException(CocktailApiErrorKind.timeout),
        ),
      );
      // No error card, no notice; existing content intact.
      expect(keyed('catalog-download-failed'), findsNothing);
      expect(keyed('zest-notice-dismiss'), findsNothing);
      expect(find.text('Your recipe catalog'), findsOneWidget);
    });
  });

  testWidgets('the list view states the same prevalence and connection '
      'information without the graph', (tester) async {
    await openHome(
      tester,
      seed: [
        ...catalogLetterRecipes('a'),
        ...catalogLetterRecipes('b'),
        ...catalogLetterRecipes('c'),
      ],
    );

    await activate(tester, keyed('home-view-list'));

    expect(find.text('Mint leaf'), findsOneWidget);
    expect(
      find.text('Appears in 3 of the 3 recipes in the analyzed collection.'),
      findsWidgets,
    );

    await activate(tester, keyed('constellation-item-mint leaf'));
    expect(find.text('Strongest connections'), findsOneWidget);
    expect(
      find.text('Invented botanical syrup — 3 shared recipes'),
      findsOneWidget,
    );
    // Connection rows are tappable targets: the padded row meets the
    // 48-pixel minimum with its text line.
    final connectionRow = tester.getRect(
      keyed('constellation-connection-invented botanical syrup'),
    );
    expect(connectionRow.height, greaterThanOrEqualTo(48));

    await activate(
      tester,
      keyed('constellation-connection-invented botanical syrup'),
    );
    // Canonical edge order: "invented botanical syrup" sorts first.
    expect(find.text('Invented botanical syrup and Mint leaf'), findsOneWidget);
    expect(find.text('Aarden Spritz 1'), findsOneWidget);

    await activate(tester, keyed('constellation-recipe-000971'));
    expect(router(tester).state.uri.path, '/discover/recipe/000971');
    // Local-first detail (docs/M11.md "Recipe detail"): this id is in the
    // seeded catalog, so its stored name shows — not the gateway mock's.
    expect(find.text('Aarden Spritz 1'), findsOneWidget);
  });

  testWidgets('home opens with nothing selected, including after leaving '
      'and returning', (tester) async {
    await openHome(
      tester,
      seed: [
        ...catalogLetterRecipes('a'),
        ...catalogLetterRecipes('b'),
        ...catalogLetterRecipes('c'),
      ],
    );

    void expectNothingSelected() {
      final canvas = tester.widget<ConstellationCanvas>(
        keyed('constellation-canvas'),
      );
      expect(canvas.selectedNodeId, isNull);
      expect(canvas.selectedEdge, isNull);
      expect(keyed('constellation-clear'), findsNothing);
      expect(
        find.textContaining('Tap an ingredient to see where it leads'),
        findsOneWidget,
      );
    }

    expectNothingSelected();

    // Select something, leave home, and come back: the selection does not
    // follow the reader back.
    await tester.ensureVisible(keyed('constellation-canvas'));
    await tester.pumpAndSettle();
    final (box, _, layout) = canvasGeometry(tester, threeLetterRecipes());
    await tester.tapAt(box.localToGlobal(layout.positionOf('mint leaf')));
    await tester.pumpAndSettle();
    expect(keyed('constellation-clear'), findsOneWidget);

    await activate(tester, keyed('home-discover'));
    expect(router(tester).state.uri.path, '/discover');
    router(tester).go('/');
    await tester.pumpAndSettle();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    expectNothingSelected();
  });

  testWidgets('the graph canvas answers node and edge selection', (
    tester,
  ) async {
    await openHome(
      tester,
      seed: [
        ...catalogLetterRecipes('a'),
        ...catalogLetterRecipes('b'),
        ...catalogLetterRecipes('c'),
      ],
    );

    await tester.ensureVisible(keyed('constellation-canvas'));
    await tester.pumpAndSettle();
    final (box, graph, layout) = canvasGeometry(tester, threeLetterRecipes());

    // Node selection: the info surface states the same prevalence phrase.
    await tester.tapAt(box.localToGlobal(layout.positionOf('mint leaf')));
    await tester.pumpAndSettle();
    expect(find.text('Mint leaf'), findsOneWidget);
    expect(
      find.text('Appears in 3 of the 3 recipes in the analyzed collection.'),
      findsOneWidget,
    );

    await activate(tester, keyed('constellation-clear'));
    expect(find.text('Mint leaf'), findsNothing);

    // Edge selection: the shared-recipe sheet opens straight from the canvas.
    final (midpoint, edge) = clearEdgeMidpoint(graph, layout);
    await tester.tapAt(box.localToGlobal(midpoint));
    await tester.pumpAndSettle();
    expect(
      find.text(
        '${displayIdentity(edge.aIdentity)} and '
        '${displayIdentity(edge.bIdentity)}',
      ),
      // The label shows twice: the info surface behind the sheet and the
      // sheet title itself.
      findsNWidgets(2),
    );
    expect(find.text('Aarden Spritz 1'), findsOneWidget);

    await activate(tester, keyed('constellation-recipe-000971'));
    expect(router(tester).state.uri.path, '/discover/recipe/000971');
  });

  testWidgets('the search filter narrows the constellation', (tester) async {
    await openHome(
      tester,
      seed: [
        ...catalogLetterRecipes('a'),
        ...catalogLetterRecipes('b'),
        ...catalogLetterRecipes('c'),
      ],
    );

    await tester.ensureVisible(keyed('constellation-search'));
    await tester.enterText(keyed('constellation-search'), 'mint');
    await tester.pumpAndSettle();
    expect(find.text('Showing 1 of 3 ingredients.'), findsOneWidget);

    await tester.enterText(keyed('constellation-search'), 'zzz');
    await tester.pumpAndSettle();
    expect(find.text('Showing 0 of 3 ingredients.'), findsOneWidget);
  });

  testWidgets('a collection wider than the top-40 bound discloses the cut '
      'honestly in both views', (tester) async {
    await openHome(tester, seed: wideGardenRecipes());

    // The intro no longer claims every ingredient gets a place, and the
    // graph count line names the pre-bound total, not the bounded list.
    expect(
      find.textContaining(
        'The most-used ingredients in the loaded '
        'collection get a place',
      ),
      findsOneWidget,
    );
    expect(
      find.text('Showing the top 40 of 42 ingredients by prevalence.'),
      findsOneWidget,
    );

    // A filtered search keeps the disclosure with the match count.
    await tester.enterText(keyed('constellation-search'), 'wide ingredient 3');
    await tester.pumpAndSettle();
    // "wide ingredient 3" matches identities 3 and 30–39.
    expect(
      find.text('Showing 11 matches among the top 40 of 42 ingredients.'),
      findsOneWidget,
    );

    // The list view shows only bounded nodes, so it carries the same
    // disclosure alongside the coverage label.
    await activate(tester, keyed('home-view-list'));
    expect(
      find.text('Showing the top 40 of 42 ingredients by prevalence.'),
      findsOneWidget,
    );
  });

  // DESIGN.md defines reduced motion as either flag; both must render the
  // settled layout with no running animation controllers.
  for (final flags in [
    (
      name: 'disableAnimations',
      disableAnimations: true,
      accessibleNavigation: false,
    ),
    (
      name: 'accessibleNavigation',
      disableAnimations: false,
      accessibleNavigation: true,
    ),
  ]) {
    testWidgets('reduced motion via ${flags.name} renders the settled layout '
        'with no running animation controllers', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          FakeAccessibilityFeatures(
            disableAnimations: flags.disableAnimations,
            accessibleNavigation: flags.accessibleNavigation,
          );
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );

      await openHome(
        tester,
        seed: [
          ...catalogLetterRecipes('a'),
          ...catalogLetterRecipes('b'),
          ...catalogLetterRecipes('c'),
        ],
        settle: false,
      );
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();

      expect(keyed('constellation-canvas'), findsOneWidget);
      // Nothing is animating: the settle controller is never created under
      // reduced motion, so no ticker exists at all.
      expect(tester.binding.transientCallbackCount, 0);

      // The static canvas stays fully interactive.
      await tester.ensureVisible(keyed('constellation-canvas'));
      await tester.pump();
      final (box, graph, layout) = canvasGeometry(tester, threeLetterRecipes());
      await tester.tapAt(box.localToGlobal(layout.positionOf('mint leaf')));
      await tester.pumpAndSettle();
      expect(find.text('Mint leaf'), findsOneWidget);
      expect(
        find.text('Appears in 3 of the 3 recipes in the analyzed collection.'),
        findsOneWidget,
      );
      expect(tester.binding.transientCallbackCount, 0);
    });
  }

  testWidgets('navigation reaches the bar screen from home', (tester) async {
    await openHome(tester, seed: catalogLetterRecipes('a'));

    await activate(tester, keyed('home-bar'));
    expect(router(tester).state.uri.path, '/bar');
    expect(find.text('Your botanical shelf'), findsOneWidget);
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets('home remains readable at 320px and ${scale}x text', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await openHome(
        tester,
        seed: [
          ...catalogLetterRecipes('a'),
          ...catalogLetterRecipes('b'),
          ...catalogLetterRecipes('c'),
        ],
        size: const Size(320, 720),
      );
      expectReadable(tester);
      await activate(tester, keyed('home-view-list'));
      expectReadable(tester);
      // The catalog status card stays reachable at the bottom of the
      // page's scroll.
      await tester.ensureVisible(keyed('home-sync-card'));
      await tester.pumpAndSettle();
      expectReadable(tester);
    });
  }
}
