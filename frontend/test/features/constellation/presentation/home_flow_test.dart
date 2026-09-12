import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zest/app/zest_app.dart';
import 'package:zest/core/network/cocktail_api_exception.dart';
import 'package:zest/core/widgets/zest_button.dart';
import 'package:zest/features/catalog/data/catalog_repository.dart';
import 'package:zest/features/constellation/domain/graph_layout.dart';
import 'package:zest/features/constellation/domain/ingredient_graph.dart';
import 'package:zest/features/constellation/presentation/constellation_canvas.dart';
import 'package:zest/features/constellation/presentation/constellation_painter.dart';
import 'package:zest/features/constellation/presentation/constellation_widgets.dart';
import 'package:zest/features/discovery/application/discovery_providers.dart';
import 'package:zest/features/discovery/data/cocktail_db_client.dart';
import 'package:zest/features/discovery/domain/recipe.dart';

import '../../../support/catalog_fixtures.dart';
import '../../../support/catalog_wiring.dart';
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

Future<FakeCatalogLetterSource> openHome(
  WidgetTester tester, {
  Map<String, List<Recipe>> letters = const {},
  Map<String, List<Recipe>> seed = const {},
  Map<String, Object> failures = const {},
  Set<String> gates = const {},
  Size size = const Size(900, 1600),
  DateTime Function()? now,
  bool settle = true,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final source = FakeCatalogLetterSource(
    letters: letters,
    failures: failures,
    gates: gates,
  );
  final database = openInMemoryCatalog();
  addTearDown(database.close);
  // Seed the store directly: `letters` configures the sync source, `seed`
  // preloads the on-device catalog the graph reads.
  final seedRepository = CatalogRepository(
    database: database,
    now: now ?? () => DateTime(2026, 9, 12, 10),
  );
  for (final entry in seed.entries) {
    await seedRepository.upsertLetter(entry.key, entry.value);
  }
  final transport = MockClient(_respond);
  final client = CocktailDbClient(client: transport);
  addTearDown(() {
    client.close();
    transport.close();
  });
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...catalogTestOverrides(database: database, source: source, now: now),
        cocktailDbClientProvider.overrideWithValue(client),
        if (now != null) nowProvider.overrideWithValue(now),
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
  return source;
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
  final box = tester.renderObject<RenderBox>(
    keyed('constellation-canvas'),
  );
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

void main() {
  setUpAll(loadZestFonts);

  testWidgets('home leads with the constellation and keeps the core tasks '
      'reachable without it', (tester) async {
    await openHome(tester, seed: {'a': catalogLetterRecipes('a')});

    expect(find.text('The Ingredient Constellation'), findsOneWidget);
    expect(keyed('constellation-canvas'), findsOneWidget);
    expect(find.text('Your recipe collection'), findsOneWidget);
    expect(find.text('The graph is decorative — the list view carries the '
        'same information.'), findsOneWidget);

    await activate(tester, keyed('home-discover'));
    expect(router(tester).state.uri.path, '/discover');
  });

  testWidgets('an empty catalog offers a designed empty state with a sync '
      'CTA, never a blank graph', (tester) async {
    await openHome(tester);

    expect(find.text('The constellation is waiting'), findsOneWidget);
    expect(
      find.textContaining(
        'Ingredients appear here once recipes are loaded on this device.',
      ),
      findsOneWidget,
    );

    // The empty state and the idle sync card both offer the CTA; starting
    // with no recipes anywhere finishes instantly into the honest card.
    expect(find.text('Start syncing'), findsNWidgets(2));
    await activate(tester, find.text('Start syncing').first);
    expect(find.text('Collection loaded'), findsOneWidget);
    expect(
      find.text(
        'TheCocktailDB recipes loaded on this device '
        '(26 of 26 letters · 0 recipes).',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining('not a claim about the full provider catalog'),
      findsOneWidget,
    );
  });

  testWidgets('syncing reports live progress; stopping keeps the partial '
      'catalog', (tester) async {
    final source = await openHome(
      tester,
      letters: everyCatalogLetter(),
      gates: {'b'},
    );

    await activate(tester, keyed('sync-start'));
    await tester.runAsync(() => source.waitUntilRequested('b'));
    await tester.pump();

    expect(
      find.text('Syncing… 1 of 26 letters · 1 recipe'),
      findsOneWidget,
    );
    expect(find.text('Browsing letter “B”.'), findsOneWidget);

    await activate(tester, keyed('sync-stop'));
    expect(find.text('Your recipe collection'), findsOneWidget);
    expect(find.text('Continue syncing'), findsOneWidget);
    expect(
      find.text(
        'TheCocktailDB recipes loaded on this device '
        '(1 of 26 letters · 1 recipe).',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining('not a claim about the full provider catalog'),
      findsNothing,
    );
  });

  testWidgets('a rate limit pauses with a countdown; resume continues when '
      'it ends', (tester) async {
    var clock = DateTime.utc(2026, 9, 12);
    await openHome(
      tester,
      letters: everyCatalogLetter(),
      failures: {
        'a': CocktailApiException(
          CocktailApiErrorKind.rateLimited,
          statusCode: 429,
          retryAfter: const Duration(seconds: 2),
          retryAt: clock.add(const Duration(seconds: 2)),
        ),
      },
      now: () => clock,
    );

    // No pumpAndSettle while the countdown ticks — the ticker reschedules
    // frames every fake second, so only explicit pumps are used (the
    // discovery cooldown suite follows the same rule).
    await tester.ensureVisible(keyed('sync-start'));
    await tester.tap(keyed('sync-start'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Paused for a moment'), findsOneWidget);
    final resume = tester.widget<ZestButton>(keyed('sync-resume'));
    expect(resume.label, 'Resume in 2 s');
    expect(resume.onPressed, isNull);

    // The countdown follows the deadline, not the tick count.
    clock = clock.add(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 1));
    final ready = tester.widget<ZestButton>(keyed('sync-resume'));
    expect(ready.label, 'Resume syncing');
    expect(ready.onPressed, isNotNull);

    await tester.tap(keyed('sync-resume'));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    expect(find.text('Collection loaded'), findsOneWidget);
    expect(
      find.text(
        'TheCocktailDB recipes loaded on this device '
        '(26 of 26 letters · 26 recipes).',
      ),
      findsOneWidget,
    );
    expect(find.text('Every A–Z browse has completed.'), findsOneWidget);
    expect(
      find.textContaining('does not prove the catalog is exhausted'),
      findsOneWidget,
    );
  });

  testWidgets('a generic error pauses resumably', (tester) async {
    await openHome(
      tester,
      letters: everyCatalogLetter(),
      failures: {
        'a': const CocktailApiException(CocktailApiErrorKind.network),
      },
    );

    await activate(tester, keyed('sync-start'));
    expect(find.text('The sync hit a problem'), findsOneWidget);

    await activate(tester, find.text('Resume syncing'));
    expect(find.text('Collection loaded'), findsOneWidget);
  });

  testWidgets('the list view states the same prevalence and connection '
      'information without the graph', (tester) async {
    await openHome(tester, seed: {
      'a': catalogLetterRecipes('a'),
      'b': catalogLetterRecipes('b'),
      'c': catalogLetterRecipes('c'),
    });

    await activate(tester, keyed('home-view-list'));

    expect(find.text('Mint leaf'), findsOneWidget);
    expect(
      find.text(
        'Appears in 3 of the 3 recipes in the analyzed collection.',
      ),
      findsWidgets,
    );
    // The identified collection line appears in both the list card and the
    // sync card, and nothing claims completeness.
    expect(find.textContaining('(3 of 26 letters'), findsNWidgets(2));
    expect(find.textContaining('(26 of 26 letters'), findsNothing);

    await activate(tester, keyed('constellation-item-mint leaf'));
    expect(find.text('Strongest connections'), findsOneWidget);
    expect(
      find.text('Invented botanical syrup — 3 shared recipes'),
      findsOneWidget,
    );

    await activate(
      tester,
      keyed('constellation-connection-invented botanical syrup'),
    );
    // Canonical edge order: "invented botanical syrup" sorts first.
    expect(find.text('Invented botanical syrup and Mint leaf'), findsOneWidget);
    expect(find.text('Aarden Spritz 1'), findsOneWidget);

    await activate(tester, keyed('constellation-recipe-000971'));
    expect(router(tester).state.uri.path, '/discover/recipe/000971');
    expect(find.text('Testbench Tonic'), findsOneWidget);
  });

  testWidgets('the graph canvas answers node and edge selection',
      (tester) async {
    await openHome(tester, seed: {
      'a': catalogLetterRecipes('a'),
      'b': catalogLetterRecipes('b'),
      'c': catalogLetterRecipes('c'),
    });

    await tester.ensureVisible(keyed('constellation-canvas'));
    await tester.pumpAndSettle();
    final (box, graph, layout) = canvasGeometry(tester, threeLetterRecipes());

    // Node selection: the info surface states the same prevalence phrase.
    await tester.tapAt(box.localToGlobal(layout.positionOf('mint leaf')));
    await tester.pumpAndSettle();
    expect(find.text('Mint leaf'), findsOneWidget);
    expect(
      find.text(
        'Appears in 3 of the 3 recipes in the analyzed collection.',
      ),
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
    await openHome(tester, seed: {
      'a': catalogLetterRecipes('a'),
      'b': catalogLetterRecipes('b'),
      'c': catalogLetterRecipes('c'),
    });

    await tester.ensureVisible(keyed('constellation-search'));
    await tester.enterText(keyed('constellation-search'), 'mint');
    await tester.pumpAndSettle();
    expect(find.text('Showing 1 of 3 ingredients.'), findsOneWidget);

    await tester.enterText(keyed('constellation-search'), 'zzz');
    await tester.pumpAndSettle();
    expect(find.text('Showing 0 of 3 ingredients.'), findsOneWidget);
  });

  testWidgets('reduced motion renders the settled layout with no running '
      'animation controllers', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    await openHome(
      tester,
      seed: {
        'a': catalogLetterRecipes('a'),
        'b': catalogLetterRecipes('b'),
        'c': catalogLetterRecipes('c'),
      },
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
      find.text(
        'Appears in 3 of the 3 recipes in the analyzed collection.',
      ),
      findsOneWidget,
    );
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('navigation reaches the bar screen from home', (tester) async {
    await openHome(tester, seed: {'a': catalogLetterRecipes('a')});

    await activate(tester, keyed('home-bar'));
    expect(router(tester).state.uri.path, '/bar');
    expect(find.text('What can I make?'), findsOneWidget);
  });
}

// Keep the math import honest: the helper file uses it for clear midpoints.
// ignore_for_file: unused_import
