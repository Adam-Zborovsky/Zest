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
import 'package:zest/features/discovery/application/discovery_providers.dart';
import 'package:zest/features/discovery/data/cocktail_db_client.dart';

import '../../../support/bar_fixtures.dart';
import '../../../support/collection_test_overrides.dart';
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

Future<void> openApp(
  WidgetTester tester, {
  required Future<http.Response> Function(http.Request) respond,
  // Since M5, `/` is the home screen; tests that used to ride the old
  // `/` → `/discover` redirect now start on discovery explicitly.
  String location = '/discover',
  Size size = const Size(900, 1200),
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
        if (now != null) nowProvider.overrideWithValue(now),
        ...collectionTestOverrides(),
      ],
      child: ZestApp(initialLocation: location),
    ),
  );
  await tester.pumpAndSettle();
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

GoRouter router(WidgetTester tester) =>
    GoRouter.of(tester.element(find.byType(Scaffold).last));

Future<void> search(WidgetTester tester, String query) async {
  await tester.ensureVisible(keyed('discovery-query'));
  await tester.enterText(keyed('discovery-query'), query);
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

  testWidgets('direct bar link without results explains and links discovery', (
    tester,
  ) async {
    var requests = 0;
    await openApp(
      tester,
      location: '/bar',
      respond: (_) async {
        requests++;
        return _json({'drinks': null});
      },
    );
    expect(find.text('What can I make?'), findsOneWidget);
    expect(find.text('Nothing to match yet'), findsOneWidget);
    expect(keyed('bar-find-matches'), findsNothing);
    expect(requests, 0);
    await activate(tester, find.text('Explore discovery'));
    expect(router(tester).state.uri.path, '/discover');
  });

  testWidgets(
    'selection starts empty and matching sorts the collection into three buckets',
    (tester) async {
      await openApp(tester, respond: _respond);
      await search(tester, 'Paper Garden');
      await activate(tester, keyed('bar-from-preview'));
      expect(router(tester).state.uri.path, '/bar');

      // Scope is labeled and bounded; nothing is preselected.
      expect(find.text('Recipes for “Paper Garden”'), findsOneWidget);
      expect(find.textContaining('3 recipes.'), findsOneWidget);
      expect(find.textContaining('Nothing selected yet'), findsOneWidget);
      expect(
        tester.widget<ZestButton>(keyed('bar-find-matches')).onPressed,
        isNull,
      );
      expect(
        find.text('Select at least one ingredient to start matching.'),
        findsOneWidget,
      );

      // Picker: options load, nothing checked, toggling reflects immediately.
      await activate(tester, keyed('bar-add-ingredients'));
      expect(find.text('Choose your ingredients'), findsOneWidget);
      expect(find.text('Showing 4 of 4 ingredients.'), findsOneWidget);
      await activate(tester, keyed('ingredient-option-Imaginary gin'));
      await activate(tester, keyed('ingredient-option-Pretend lime juice'));
      await activate(tester, keyed('ingredient-option-Lime juice'));
      await activate(tester, keyed('picker-done'));

      expect(keyed('bar-remove-imaginary gin'), findsOneWidget);
      expect(keyed('bar-remove-pretend lime juice'), findsOneWidget);
      expect(keyed('bar-remove-lime juice'), findsOneWidget);
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
      expect(
        find.textContaining('Garnish not counted: Nutmeg.'),
        findsOneWidget,
      );

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
    },
  );

  testWidgets('picker search narrows options and chips remove selections', (
    tester,
  ) async {
    await openApp(tester, respond: _respond);
    await search(tester, 'Paper Garden');
    await activate(tester, keyed('bar-from-preview'));
    await activate(tester, keyed('bar-add-ingredients'));
    await tester.enterText(keyed('ingredient-search'), 'gin');
    await tester.pumpAndSettle();
    expect(find.text('Showing 1 of 4 ingredients.'), findsOneWidget);
    expect(keyed('ingredient-option-Imaginary gin'), findsOneWidget);
    expect(keyed('ingredient-option-Lime juice'), findsNothing);
    await tester.enterText(keyed('ingredient-search'), 'zzz');
    await tester.pumpAndSettle();
    expect(find.textContaining('No ingredient matches'), findsOneWidget);
    await tester.enterText(keyed('ingredient-search'), '');
    await activate(tester, keyed('ingredient-option-Imaginary gin'));
    await activate(tester, keyed('picker-done'));
    expect(keyed('bar-remove-imaginary gin'), findsOneWidget);
    await activate(tester, keyed('bar-remove-imaginary gin'));
    expect(find.textContaining('Nothing selected yet'), findsOneWidget);
    expect(
      tester.widget<ZestButton>(keyed('bar-find-matches')).onPressed,
      isNull,
    );
    expectReadable(tester);

    // Escape still closes the sheet without a pointer.
    await activate(tester, keyed('bar-add-ingredients'));
    expect(find.text('Choose your ingredients'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Choose your ingredients'), findsNothing);
    expectReadable(tester);
  });

  testWidgets('a rate limit pauses matching and resumes after the cooldown', (
    tester,
  ) async {
    var clock = DateTime.utc(2026, 9, 12);
    var limited = false;
    await openApp(
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
    await search(tester, 'Paper Garden');
    await activate(tester, keyed('bar-from-preview'));
    await activate(tester, keyed('bar-add-ingredients'));
    await activate(tester, keyed('ingredient-option-Imaginary gin'));
    await activate(tester, keyed('picker-done'));
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
    await search(tester, 'Paper Garden');
    await activate(tester, keyed('bar-from-preview'));
    await activate(tester, keyed('bar-add-ingredients'));
    await activate(tester, keyed('ingredient-option-Imaginary gin'));
    await activate(tester, keyed('picker-done'));
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

  testWidgets('keyboard completes an entire selection and match', (
    tester,
  ) async {
    await openApp(tester, respond: _respond);
    await search(tester, 'Paper Garden');
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

    expect(await tabTo('bar-add-ingredients'), isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('Choose your ingredients'), findsOneWidget);

    expect(await tabTo('ingredient-option-Imaginary gin'), isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<CheckboxListTile>(keyed('ingredient-option-Imaginary gin'))
          .value,
      isTrue,
    );

    expect(await tabTo('picker-done'), isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(keyed('bar-remove-imaginary gin'), findsOneWidget);

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
      await search(tester, 'Paper Garden');
      await activate(tester, keyed('bar-from-preview'));
      expectReadable(tester);
      await activate(tester, keyed('bar-add-ingredients'));
      expectReadable(tester);
      await activate(tester, keyed('ingredient-option-Imaginary gin'));
      await activate(tester, keyed('picker-done'));
      await activate(tester, keyed('bar-find-matches'));
      expectReadable(tester);
    });
  }
}
