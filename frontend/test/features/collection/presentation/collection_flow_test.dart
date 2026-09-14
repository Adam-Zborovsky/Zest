import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zest/app/zest_app.dart';
import 'package:zest/features/catalog/application/catalog_providers.dart';
import 'package:zest/features/catalog/data/catalog_repository.dart';
import 'package:zest/features/collection/domain/collection_entry.dart';
import 'package:zest/features/discovery/application/discovery_providers.dart';
import 'package:zest/features/discovery/data/cocktail_db_client.dart';
import 'package:zest/features/discovery/domain/recipe.dart';
import 'package:zest/features/discovery/presentation/discovery_widgets.dart';

import '../../../support/catalog_fixtures.dart';
import '../../../support/catalog_wiring.dart';
import '../../../support/collection_test_overrides.dart';
import '../../../support/in_memory_session.dart';
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
  ImageProvider<Object> Function(String)? imageProvider,
  Size size = const Size(412, 1600),
  List<Recipe> catalogRecipes = const [],
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
  final catalogDatabase = openInMemoryCatalog();
  addTearDown(catalogDatabase.close);
  final catalogRepository = CatalogRepository(database: catalogDatabase);
  if (catalogRecipes.isNotEmpty) {
    await catalogRepository.applySnapshot(
      catalogSnapshotFixture(drinks: catalogRecipes),
    );
  }
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...collectionTestOverrides(repository: repository),
        ...sessionTestOverrides(),
        catalogRepositoryProvider.overrideWithValue(catalogRepository),
        cocktailDbClientProvider.overrideWithValue(client),
        nowProvider.overrideWithValue(() => DateTime(2026, 9, 13, 12)),
        if (imageProvider != null)
          recipeImageProvider.overrideWithValue(imageProvider),
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

  testWidgets('each save from recipe detail is a new entry dated today', (
    tester,
  ) async {
    final repository = await openApp(
      tester,
      location: '/discover/recipe/99001',
      respond: (_) async => discoveryResponse([
        discoveryRecipe(id: '99001', name: 'Paper Garden 1'),
      ]),
    );
    expect(
      find.text(
        'Save this drink to today in your calendar. You can change the day '
        'later.',
      ),
      findsOneWidget,
    );

    await activate(tester, keyed('recipe-save'));
    expect(find.text('Saved to your calendar once.'), findsOneWidget);
    await activate(tester, keyed('recipe-save'));
    expect(find.text('Saved to your calendar 2 times.'), findsOneWidget);

    final entries = await repository.watchEntries().first;
    expect(entries, hasLength(2));
    expect(entries.map((entry) => entry.day).toSet(), {DateTime(2026, 9, 13)});

    await activate(tester, keyed('recipe-saved-${entries.first.id}'));
    expect(router(tester).state.uri.path, '/collection/${entries.first.id}');
    expect(find.text('Sunday, September 13, 2026'), findsOneWidget);
  });

  testWidgets('the calendar opens a single drink directly and lists several', (
    tester,
  ) async {
    final repository = await openApp(tester, location: '/collection');
    expect(find.text('Nothing saved yet'), findsOneWidget);
    expect(find.text('September 2026'), findsOneWidget);

    final single = await repository.saveRecipe(
      seedRecipe(id: '99001', name: 'Paper Garden 1'),
    );
    await repository.moveToDay(single.id, DateTime(2026, 9, 10));
    final saved = await repository.saveRecipe(
      seedRecipe(id: '99002', name: 'Paper Garden 2'),
    );
    await repository.createVariation(
      seedRecipe(id: '99003', name: 'Paper Garden 3'),
      seedVariation(name: 'My Twist'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nothing saved yet'), findsNothing);
    expect(
      find.bySemanticsLabel('Thursday, September 10, 2026, 1 drink'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Sunday, September 13, 2026, today, 2 drinks'),
      findsOneWidget,
    );

    await activate(tester, keyed('calendar-day-2026-09-10'));
    expect(router(tester).state.uri.path, '/collection/${single.id}');
    router(tester).pop();
    await tester.pumpAndSettle();

    await activate(tester, keyed('calendar-day-2026-09-13'));
    expect(find.text('2 drinks on this day.'), findsOneWidget);
    expect(find.text('Your variation of Paper Garden 3'), findsOneWidget);
    expect(find.text('Saved recipe'), findsOneWidget);
    await activate(tester, keyed('collection-${saved.id}'));
    expect(router(tester).state.uri.path, '/collection/${saved.id}');
    expectReadable(tester);
  });

  testWidgets('the calendar credits source thumbnails in copy and semantics', (
    tester,
  ) async {
    final repository = await openApp(
      tester,
      location: '/collection',
      imageProvider: (_) => MemoryImage(validTinyPng().bytes),
    );
    await repository.saveRecipe(
      Recipe.fromJson(
        discoveryRecipe(
          id: '99004',
          name: 'Paper Garden 4',
          thumbnailUrl: 'https://images.example.test/paper-garden.png',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Days without a photo of your own show a small image from '
        'TheCocktailDB.',
      ),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(
        'Sunday, September 13, 2026, today, 1 drink, image from '
        'TheCocktailDB',
      ),
      findsOneWidget,
    );
  });

  testWidgets('an entry can be moved to another day', (tester) async {
    final repository = await openApp(tester, location: '/collection');
    final entry = await repository.saveRecipe(
      seedRecipe(id: '99001', name: 'Paper Garden 1'),
    );
    router(tester).go('/collection/${entry.id}');
    await tester.pumpAndSettle();
    expect(find.text('Sunday, September 13, 2026'), findsOneWidget);

    await activate(tester, keyed('entry-change-date'));
    await tester.tap(find.text('11'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.text('Friday, September 11, 2026'), findsOneWidget);
    expect(
      (await repository.watchEntry(entry.id).first)!.day,
      DateTime(2026, 9, 11),
    );
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
      // The prefilled fields below are a copy of the source recipe, so its
      // credit and link stay visible even before anything is edited.
      expect(
        find.text('Recipe data and imagery: TheCocktailDB'),
        findsOneWidget,
      );
      expect(find.text('Open source recipe'), findsOneWidget);
      expect(
        tester.widget<TextField>(keyed('variation-name')).controller!.text,
        'Paper Garden 1',
      );
      expect(
        tester
            .widget<TextFormField>(
              find.descendant(
                of: keyed('variation-ingredient-name-0'),
                matching: find.byType(TextFormField),
              ),
            )
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

  testWidgets(
    'an ingredient row suggests catalog labels; free text stays valid',
    (tester) async {
      await openApp(
        tester,
        location: '/discover/recipe/99001',
        respond: (_) async => discoveryResponse([
          discoveryRecipe(id: '99001', name: 'Paper Garden 1'),
        ]),
        // Carries the default fixture ingredients, including "Imaginary
        // leaf syrup" — the same identity the source recipe's row starts
        // with, so the index has a suggestion for it.
        catalogRecipes: [seedRecipe(id: '99050', name: 'Ginger Fix')],
      );
      await activate(tester, keyed('recipe-make-variation'));

      final nameField = find.descendant(
        of: keyed('variation-ingredient-name-0'),
        matching: find.byType(TextFormField),
      );
      await tester.enterText(nameField, 'Imaginary');
      await tester.pumpAndSettle();
      // The suggestion is the catalog's own spelling for this identity.
      expect(find.text('Imaginary leaf syrup'), findsWidgets);

      // Free text remains valid: typing something not in the catalog and
      // saving still succeeds.
      await tester.enterText(nameField, 'My own bitters blend');
      await tester.pumpAndSettle();
      await activate(tester, keyed('variation-save'));
      expect(find.text('Your variation of Paper Garden 1'), findsOneWidget);
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
    // Editing an existing variation still credits and links its source.
    expect(find.text('Recipe data and imagery: TheCocktailDB'), findsOneWidget);
    expect(find.text('Open source recipe'), findsOneWidget);
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
