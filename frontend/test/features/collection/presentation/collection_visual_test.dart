import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:zest/app/zest_app.dart';
import 'package:zest/features/collection/domain/collection_entry.dart';
import 'package:zest/features/discovery/application/discovery_providers.dart';
import 'package:zest/features/discovery/data/cocktail_db_client.dart';
import 'package:zest/features/discovery/domain/recipe.dart';
import 'package:zest/features/discovery/presentation/discovery_widgets.dart';

import '../../../support/catalog_wiring.dart';
import '../../../support/collection_test_overrides.dart';
import '../../../support/in_memory_session.dart';
import '../../../support/discovery_fixtures.dart';
import '../../../support/in_memory_collection_repository.dart';
import '../../../support/load_fonts.dart';

Recipe _recipe({required String id, required String name}) =>
    Recipe.fromJson(discoveryRecipe(id: id, name: name));

Future<void> _renderAndCheck(
  WidgetTester tester,
  String name,
  Size size, {
  required InMemoryCollectionRepository repository,
  required String location,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final transport = MockClient(
    (_) async => discoveryResponse([discoveryRecipe(id: '99001')]),
  );
  final client = CocktailDbClient(client: transport);
  addTearDown(() {
    client.close();
    transport.close();
  });
  final capture = ValueKey('collection-capture-$name');
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...collectionTestOverrides(repository: repository),
        ...sessionTestOverrides(),
        emptyCatalogRepositoryOverride(),
        cocktailDbClientProvider.overrideWithValue(client),
        nowProvider.overrideWithValue(() => DateTime(2026, 9, 13, 12)),
        // Source thumbnails render a synthetic picture; no network.
        recipeImageProvider.overrideWithValue(
          (_) => MemoryImage(validTinyPng().bytes),
        ),
      ],
      child: RepaintBoundary(
        key: capture,
        child: ZestApp(initialLocation: location),
      ),
    ),
  );
  await tester.pumpAndSettle();
  // Each entry's memory-photo lookup chains a StreamProvider's first
  // emission into a further Future read, so draining once is not always
  // enough to settle every row before the golden capture; repeat until
  // nothing is pending.
  for (var i = 0; i < 3; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
  }
  // Image decoding does not complete inside the fake-async test zone, so
  // memory photos are decoded for real before capture; otherwise the golden
  // would show an empty image box instead of the person's photo.
  await tester.runAsync(() async {
    for (final element in find.byType(Image).evaluate()) {
      await precacheImage((element.widget as Image).image, element);
    }
  });
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
  await expectLater(
    find.byKey(capture),
    matchesGoldenFile('goldens/$name.png'),
  );
  final semantics = tester.ensureSemantics();
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  await expectLater(tester, meetsGuideline(textContrastGuideline));
  semantics.dispose();
}

void main() {
  setUpAll(loadZestFonts);

  testWidgets('collection-calendar Night Garden render', (tester) async {
    // A distinct clock per write keeps each day's bubble order stable.
    var clock = DateTime(2026, 9, 13, 9);
    DateTime tick() => clock = clock.add(const Duration(minutes: 1));
    final repository = InMemoryCollectionRepository(now: tick);
    Recipe thumbnailed(String id, String name) => Recipe.fromJson(
      discoveryRecipe(
        id: id,
        name: name,
        thumbnailUrl:
            'https://www.thecocktaildb.com/images/media/drink/$id.jpg',
      ),
    );

    Future<void> onDay(
      DateTime day,
      Recipe source, {
      bool photo = false,
    }) async {
      final entry = await repository.saveRecipe(source);
      await repository.moveToDay(entry.id, day);
      if (photo) await repository.setPhoto(entry.id, validTinyPng());
    }

    // Today: one drink with a memory photo.
    await onDay(
      DateTime(2026, 9, 13),
      _recipe(id: '99001', name: 'Paper Garden'),
      photo: true,
    );
    // Three drinks: two with source pictures, one with no picture at all.
    await onDay(DateTime(2026, 9, 10), thumbnailed('99002', 'Garden Sour'));
    await onDay(
      DateTime(2026, 9, 10),
      _recipe(id: '99003', name: 'Plain Fizz'),
    );
    await onDay(
      DateTime(2026, 9, 10),
      thumbnailed('99004', 'Leaf Spritz'),
      photo: true,
    );
    // Two drinks on one day.
    await onDay(DateTime(2026, 9, 5), thumbnailed('99005', 'Night Mule'));
    await onDay(DateTime(2026, 9, 5), thumbnailed('99006', 'Moss Collins'));
    // A single drink last month.
    await onDay(DateTime(2026, 8, 28), thumbnailed('99007', 'August Cooler'));

    await _renderAndCheck(
      tester,
      'collection-calendar',
      const Size(412, 1500),
      repository: repository,
      location: '/collection',
    );
  });

  testWidgets('collection-empty Night Garden render', (tester) async {
    await _renderAndCheck(
      tester,
      'collection-empty',
      const Size(412, 900),
      repository: InMemoryCollectionRepository(),
      location: '/collection',
    );
  });

  testWidgets('collection-entry-photo Night Garden render', (tester) async {
    final repository = InMemoryCollectionRepository(
      now: () => DateTime(2026, 9, 13, 9),
    );
    final entry = await repository.saveRecipe(
      _recipe(id: '99001', name: 'Paper Garden'),
    );
    // A decodable synthetic PNG, so the golden shows a rendered memory photo
    // rather than the decode-failure fallback.
    await repository.setPhoto(entry.id, validTinyPng());
    await _renderAndCheck(
      tester,
      'collection-entry-photo',
      const Size(412, 1600),
      repository: repository,
      location: '/collection/${entry.id}',
    );
  });

  testWidgets('collection-entry-variation Night Garden render', (tester) async {
    final repository = InMemoryCollectionRepository(
      now: () => DateTime(2026, 9, 13, 9),
    );
    final entry = await repository.createVariation(
      _recipe(id: '99002', name: 'Garden Sour'),
      VariationDetails(
        name: 'My Sour Twist',
        ingredients: [
          VariationIngredient(name: 'Imaginary gin', measure: '2 oz'),
          VariationIngredient(name: 'Lime juice', measure: '1 oz'),
          VariationIngredient(name: 'A pinch of salt'),
        ],
        method: 'Shake with ice and strain into a chilled glass.',
        notes: 'Better with a wide citrus twist.',
      ),
    );
    await _renderAndCheck(
      tester,
      'collection-entry-variation',
      const Size(412, 1700),
      repository: repository,
      location: '/collection/${entry.id}',
    );
  });

  testWidgets('collection-variation-editor Night Garden render', (
    tester,
  ) async {
    await _renderAndCheck(
      tester,
      'collection-variation-editor',
      const Size(412, 1900),
      repository: InMemoryCollectionRepository(),
      location: '/discover/recipe/99001/variation',
    );
  });
}
