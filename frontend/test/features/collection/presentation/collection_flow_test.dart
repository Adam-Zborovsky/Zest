import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zest/app/zest_app.dart';
import 'package:zest/features/collection/domain/collection_entry.dart';
import 'package:zest/features/discovery/application/discovery_providers.dart';
import 'package:zest/features/discovery/data/cocktail_db_client.dart';
import 'package:zest/features/discovery/domain/recipe.dart';

import '../../../support/collection_test_overrides.dart';
import '../../../support/discovery_fixtures.dart';
import '../../../support/in_memory_collection_repository.dart';
import '../../../support/load_fonts.dart';

Finder keyed(String value) => find.byKey(ValueKey(value));

/// A synthetic source recipe for repository-seeded tests. Invented content;
/// not a provider record.
Recipe seedRecipe({required String id, required String name}) =>
    Recipe.fromJson(discoveryRecipe(id: id, name: name));

VariationDetails seedVariation({required String name}) => VariationDetails(
  name: name,
  ingredients: [VariationIngredient(name: 'Test ingredient', measure: '1 oz')],
  method: 'Stir it well.',
);

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

Future<InMemoryCollectionRepository> openApp(
  WidgetTester tester, {
  required String location,
  Future<http.Response> Function(http.Request)? respond,
  Size size = const Size(412, 1600),
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final repository = InMemoryCollectionRepository(
    now: () => DateTime(2026, 9, 13, 12),
  );
  final transport = MockClient(
    respond ?? (_) async => discoveryResponse(discoveryRecipes(1)),
  );
  final client = CocktailDbClient(client: transport);
  addTearDown(() {
    client.close();
    transport.close();
  });
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...collectionTestOverrides(repository: repository),
        cocktailDbClientProvider.overrideWithValue(client),
      ],
      child: ZestApp(initialLocation: location),
    ),
  );
  await tester.pumpAndSettle();
  await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  await tester.pumpAndSettle();
  return repository;
}

void main() {
  setUpAll(loadZestFonts);

  testWidgets('save from recipe detail, open the entry, then remove it', (
    tester,
  ) async {
    await openApp(
      tester,
      location: '/discover/recipe/99001',
      respond: (_) async => discoveryResponse([
        discoveryRecipe(id: '99001', name: 'Paper Garden 1'),
      ]),
    );
    expect(keyed('recipe-save'), findsOneWidget);
    expect(find.text('Saved to your collection'), findsNothing);
    await activate(tester, keyed('recipe-save'));
    expect(find.text('Saved to your collection'), findsOneWidget);
    expect(keyed('recipe-save'), findsNothing);
    expect(keyed('recipe-open-saved'), findsOneWidget);

    await activate(tester, keyed('recipe-open-saved'));
    expect(find.text('Saved recipe'), findsWidgets);
    expect(
      find.textContaining('Paper Garden 1'),
      findsWidgets,
      reason: 'Entry detail should show the saved recipe name.',
    );

    router(tester).pop();
    await tester.pumpAndSettle();
    await activate(tester, keyed('recipe-remove-saved'));
    expect(find.text('Remove from collection?'), findsOneWidget);
    await activate(tester, keyed('recipe-remove-saved-confirm'));
    expect(keyed('recipe-save'), findsOneWidget);
    expect(find.text('Saved to your collection'), findsNothing);
  });

  testWidgets('collection list shows saved and variation entries labeled', (
    tester,
  ) async {
    final repository = await openApp(tester, location: '/collection');
    expect(find.text('Nothing saved yet'), findsOneWidget);

    await repository.saveRecipe(
      seedRecipe(id: '99001', name: 'Paper Garden 1'),
    );
    final variationSource = seedRecipe(id: '99002', name: 'Paper Garden 2');
    await repository.createVariation(
      variationSource,
      seedVariation(name: 'My Twist'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Paper Garden 1'), findsOneWidget);
    expect(find.text('Saved recipe'), findsOneWidget);
    expect(find.text('My Twist'), findsOneWidget);
    expect(find.text('Your variation of Paper Garden 2'), findsOneWidget);
    expectReadable(tester);
  });

  testWidgets(
    'making a variation prefills from the source, edits and saves land on '
    'the new entry',
    (tester) async {
      await openApp(
        tester,
        location: '/discover/recipe/99001',
        respond: (_) async => discoveryResponse([
          discoveryRecipe(id: '99001', name: 'Paper Garden 1'),
        ]),
      );
      await activate(tester, keyed('recipe-make-variation'));
      expect(find.text('Your variation of Paper Garden 1'), findsOneWidget);
      expect(
        tester.widget<TextField>(keyed('variation-name')).controller!.text,
        'Paper Garden 1',
      );
      expect(
        tester
            .widget<TextField>(keyed('variation-ingredient-name-0'))
            .controller!
            .text,
        'Imaginary leaf syrup',
      );

      await tester.enterText(keyed('variation-name'), 'My Own Paper Garden');
      await tester.enterText(keyed('variation-notes'), 'Tastes like paper.');
      await activate(tester, keyed('variation-save'));

      expect(
        find.text('Your variation of Paper Garden 1'),
        findsOneWidget,
        reason: 'Save should land on the new entry detail.',
      );
      expect(find.text('Named "My Own Paper Garden"'), findsOneWidget);
      expect(find.text('Tastes like paper.'), findsOneWidget);
      expect(
        find.text('Your own wording — not matched to catalog ingredients.'),
        findsOneWidget,
      );
      expectReadable(tester);
    },
  );

  testWidgets('editing a variation updates the entry', (tester) async {
    final repository = await openApp(tester, location: '/collection');
    final source = seedRecipe(id: '99003', name: 'Source Drink');
    final entry = await repository.createVariation(
      source,
      seedVariation(name: 'Original name'),
    );
    router(tester).go('/collection/${entry.id}/edit');
    await tester.pumpAndSettle();

    expect(
      tester.widget<TextField>(keyed('variation-name')).controller!.text,
      'Original name',
    );
    await tester.enterText(keyed('variation-name'), 'Updated name');
    await activate(tester, keyed('variation-save'));

    expect(find.text('Named "Updated name"'), findsOneWidget);
  });

  testWidgets('blank name and too many ingredients show inline messages', (
    tester,
  ) async {
    await openApp(
      tester,
      location: '/discover/recipe/99001',
      respond: (_) async => discoveryResponse([
        discoveryRecipe(id: '99001', name: 'Paper Garden 1'),
      ]),
    );
    await activate(tester, keyed('recipe-make-variation'));
    await tester.enterText(keyed('variation-name'), '   ');
    await activate(tester, keyed('variation-save'));
    expect(find.text('A variation needs a name.'), findsOneWidget);

    // The fixture recipe seeds 2 ingredient rows; add up to the 30-row cap.
    for (var i = 0; i < 28; i++) {
      await activate(tester, keyed('variation-add-ingredient'));
    }
    await activate(tester, keyed('variation-add-ingredient'));
    expect(find.text('A variation has too many ingredients.'), findsOneWidget);
  });

  testWidgets('leaving the editor with unsaved edits asks for confirmation', (
    tester,
  ) async {
    await openApp(
      tester,
      location: '/discover/recipe/99001',
      respond: (_) async => discoveryResponse([
        discoveryRecipe(id: '99001', name: 'Paper Garden 1'),
      ]),
    );
    await activate(tester, keyed('recipe-make-variation'));
    await tester.enterText(keyed('variation-name'), 'Changed name');
    await tester.pump();

    await activate(tester, find.byTooltip('Back'));
    expect(find.text('Discard your changes?'), findsOneWidget);

    await activate(tester, find.text('Keep editing'));
    expect(
      tester.widget<TextField>(keyed('variation-name')).controller!.text,
      'Changed name',
      reason: 'Canceling the discard sheet keeps the edited value.',
    );

    await activate(tester, find.byTooltip('Back'));
    await activate(tester, keyed('editor-discard-confirm'));
    expect(find.text('Your variation of Paper Garden 1'), findsNothing);
  });

  testWidgets('deleting a variation entry confirms and removes it', (
    tester,
  ) async {
    final repository = await openApp(tester, location: '/collection');
    final source = seedRecipe(id: '99004', name: 'Deletable Drink');
    final entry = await repository.createVariation(
      source,
      seedVariation(name: 'Doomed'),
    );
    router(tester).go('/collection/${entry.id}');
    await tester.pumpAndSettle();

    await activate(tester, keyed('entry-delete'));
    expect(find.text('Delete this variation?'), findsOneWidget);
    await activate(tester, keyed('entry-delete-confirm'));
    expect(find.text('Nothing saved yet'), findsOneWidget);
  });

  testWidgets('an unknown entry id shows a designed not-found state', (
    tester,
  ) async {
    await openApp(tester, location: '/collection/does-not-exist');
    expect(find.text('Entry not found'), findsOneWidget);
    await activate(tester, find.text('Back to your collection'));
    expect(find.text('Nothing saved yet'), findsOneWidget);
  });

  testWidgets('editing a missing or non-variation entry is rejected', (
    tester,
  ) async {
    final repository = await openApp(tester, location: '/collection');
    final entry = await repository.saveRecipe(
      seedRecipe(id: '99005', name: 'Saved Only'),
    );
    router(tester).go('/collection/${entry.id}/edit');
    await tester.pumpAndSettle();
    expect(find.text('Entry not found'), findsOneWidget);
  });
}
