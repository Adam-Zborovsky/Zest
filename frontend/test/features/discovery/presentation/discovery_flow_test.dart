import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zest/app/zest_app.dart';
import 'package:zest/features/discovery/application/discovery_providers.dart';
import 'package:zest/features/discovery/data/cocktail_db_client.dart';
import 'package:zest/features/discovery/presentation/discovery_widgets.dart';

import '../../../support/collection_test_overrides.dart';
import '../../../support/in_memory_session.dart';
import '../../../support/discovery_fixtures.dart';
import '../../../support/load_fonts.dart';

Finder keyed(String value) => find.byKey(ValueKey(value));

Future<void> openDiscovery(
  WidgetTester tester, {
  required Future<http.Response> Function(http.Request) respond,
  // Since M5, `/` is the home screen; these tests exercise discovery, and
  // previously reached it through the old `/` → `/discover` redirect.
  String location = '/discover',
  Size size = const Size(900, 1200),
  Future<bool> Function(Uri)? launchSource,
  DateTime Function()? now,
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
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        cocktailDbClientProvider.overrideWithValue(client),
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
          if (request.url.path.endsWith('lookup.php')) {
            final id = request.url.queryParameters['i']!;
            return discoveryResponse([
              discoveryRecipe(id: id, name: 'Paper Garden 8'),
            ]);
          }
          return discoveryResponse(discoveryRecipes());
        },
      );
      await search(tester, 'Paper Garden');
      expect(requests.single.queryParameters, {'s': 'Paper Garden'});
      expect(keyed('recipe-99001'), findsOneWidget);
      expect(keyed('recipe-99007'), findsNothing);
      await activate(tester, keyed('see-all-results'));
      expect(router(tester).state.uri.path, '/discover/results');
      await activate(tester, keyed('recipe-99008'));
      expect(router(tester).state.uri.path, '/discover/recipe/99008');
      expect(requests.last.queryParameters, {'i': '99008'});
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
        tester.widget<TextFormField>(keyed('discovery-query')).controller!.text,
        'Paper Garden',
      );
      expect(requests, hasLength(2));
      expectReadable(tester);
    },
  );

  testWidgets('ingredient and letter modes use their distinct API endpoints', (
    tester,
  ) async {
    final requests = <Uri>[];
    await openDiscovery(
      tester,
      respond: (request) async {
        requests.add(request.url);
        final recipes = discoveryRecipes(1);
        return discoveryResponse(
          request.url.path.endsWith('filter.php')
              ? recipes.map(discoverySummary).toList()
              : recipes,
        );
      },
    );
    await activate(tester, keyed('mode-ingredient'));
    await search(tester, 'Imaginary leaf syrup');
    expect(requests.last.path, endsWith('filter.php'));
    expect(requests.last.queryParameters, {'i': 'Imaginary leaf syrup'});
    expect(keyed('recipe-99001'), findsOneWidget);
    await activate(tester, find.text('Browse A–Z'));
    await activate(tester, keyed('letter-a'));
    expect(requests.last.path, endsWith('search.php'));
    expect(requests.last.queryParameters, {'f': 'a'});
    expect(router(tester).state.uri.queryParameters, {
      'mode': 'letter',
      'q': 'a',
    });
    expect(requests, hasLength(2));
  });

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
    String fieldValue() =>
        tester.widget<TextFormField>(keyed('discovery-query')).controller!.text;
    await tester.enterText(keyed('discovery-query'), 'Draft botanical');
    await activate(tester, keyed('mode-ingredient'));
    expect(fieldValue(), 'Draft botanical');
    expect(requests, isEmpty);
    await activate(tester, keyed('search-submit'));
    expect(fieldValue(), 'Draft botanical');
    expect(requests.single.queryParameters, {'i': 'Draft botanical'});
    await activate(tester, keyed('mode-name'));
    expect(fieldValue(), 'Draft botanical');
    await search(tester, 'Second botanical');
    expect(fieldValue(), 'Second botanical');
    expect(requests.last.queryParameters, {'s': 'Second botanical'});
    router(tester).go('/discover?mode=name&q=Third');
    await tester.pumpAndSettle();
    expect(fieldValue(), 'Third');
    expect(requests.last.queryParameters, {'s': 'Third'});
  });

  testWidgets('keyboard search and result activation require no pointer', (
    tester,
  ) async {
    final requests = <Uri>[];
    await openDiscovery(
      tester,
      respond: (request) async {
        requests.add(request.url);
        return discoveryResponse(discoveryRecipes(1));
      },
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
    expect(requests.single.queryParameters, {'s': 'Paper'});
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

  testWidgets('an earlier response cannot replace the newer routed query', (
    tester,
  ) async {
    final earlier = Completer<http.Response>();
    await openDiscovery(
      tester,
      respond: (request) async {
        if (request.url.queryParameters['s'] == 'Earlier') {
          return earlier.future;
        }
        return discoveryResponse([
          discoveryRecipe(id: '99002', name: 'Newer Paper Garden'),
        ]);
      },
    );
    router(tester).go('/discover?mode=name&q=Earlier');
    await tester.pump();
    await tester.pump();
    expect(keyed('recipe-99001'), findsNothing);
    expect(find.text('Finding recipes…'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.liveRegion == true &&
            widget.properties.label == 'Finding recipes…',
      ),
      findsOneWidget,
    );
    router(tester).go('/discover?mode=name&q=Newer');
    await tester.pumpAndSettle();
    expect(keyed('recipe-99002'), findsOneWidget);
    earlier.complete(discoveryResponse(discoveryRecipes(1)));
    await tester.pumpAndSettle();
    expect(keyed('recipe-99001'), findsNothing);
    expect(keyed('recipe-99002'), findsOneWidget);
    expect(router(tester).state.uri.queryParameters['q'], 'Newer');
  });

  testWidgets('failed search waits for manual retry and then shows its result', (
    tester,
  ) async {
    var requests = 0;
    await openDiscovery(
      tester,
      location: '/discover?mode=name&q=Paper',
      respond: (_) async {
        requests++;
        return requests == 1
            ? http.Response('Synthetic temporary failure', 503)
            : discoveryResponse(discoveryRecipes(1));
      },
    );
    expect(
      find.text('Recipes are out of reach'),
      findsOneWidget,
      reason:
          'Requests: $requests; route: ${router(tester).state.uri}; '
          'visible text: ${tester.widgetList<Text>(find.byType(Text)).map((text) => text.data).join('|')}',
    );
    await tester.pump(const Duration(seconds: 20));
    expect(requests, 1);
    await activate(tester, find.text('Try again'));
    expect(requests, 2);
    expect(keyed('recipe-99001'), findsOneWidget);
    expect(router(tester).state.uri.queryParameters['q'], 'Paper');
  });

  testWidgets('rate limit disables retry until its cooldown expires', (
    tester,
  ) async {
    var requests = 0;
    var clock = DateTime.utc(2026, 9, 11);
    await openDiscovery(
      tester,
      location: '/discover?mode=name&q=Paper',
      now: () => clock,
      respond: (_) async {
        requests++;
        return requests == 1
            ? http.Response('', 429, headers: {'retry-after': '2'})
            : discoveryResponse(discoveryRecipes(1));
      },
    );
    expect(find.text('A moment for the source'), findsOneWidget);
    expect(find.text('Try again'), findsNothing);
    final waiting = find.textContaining('Try again in');
    expect(waiting, findsOneWidget);
    await tester.ensureVisible(waiting);
    await tester.tap(waiting);
    await tester.pump();
    expect(requests, 1);
    clock = clock.add(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 3));
    await activate(tester, find.text('Try again'));
    expect(requests, 2);
    expect(keyed('recipe-99001'), findsOneWidget);
  });

  testWidgets(
    'empty search and missing recipe are distinct recoverable states',
    (tester) async {
      await openDiscovery(
        tester,
        location: '/discover?mode=name&q=Nothing',
        respond: (_) async => discoveryResponse(null),
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
        respond: (_) async => discoveryResponse(discoveryRecipes(1)),
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
