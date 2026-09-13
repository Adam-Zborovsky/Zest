import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:zest/app/zest_app.dart';
import 'package:zest/features/discovery/application/discovery_providers.dart';
import 'package:zest/features/discovery/data/cocktail_db_client.dart';
import 'package:zest/features/discovery/domain/recipe.dart';
import 'package:zest/features/discovery/presentation/discovery_widgets.dart';

import '../../../support/collection_test_overrides.dart';
import '../../../support/discovery_fixtures.dart';
import '../../../support/in_memory_collection_repository.dart';
import '../../../support/load_fonts.dart';

Finder keyed(String value) => find.byKey(ValueKey(value));

Future<void> activate(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadZestFonts);

  testWidgets('an entry without a photo shows the cocktail picture with its '
      'source credit, and the person\'s photo replaces it', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(412, 1600);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final transport = MockClient((_) async => discoveryResponse(null));
    final client = CocktailDbClient(client: transport);
    addTearDown(() {
      client.close();
      transport.close();
    });
    final repository = InMemoryCollectionRepository(
      now: () => DateTime(2026, 9, 13, 12),
    );
    final picker = FakeMemoryPhotoPicker(next: validTinyPng());
    final requestedUrls = <String>[];
    final entry = await repository.saveRecipe(
      Recipe.fromJson(
        discoveryRecipe(
          id: '99001',
          name: 'Paper Garden',
          thumbnailUrl:
              'https://www.thecocktaildb.com/images/media/drink/garden.jpg',
        ),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...collectionTestOverrides(repository: repository, picker: picker),
          cocktailDbClientProvider.overrideWithValue(client),
          recipeImageProvider.overrideWithValue((url) {
            requestedUrls.add(url);
            return MemoryImage(validTinyPng().bytes);
          }),
        ],
        child: ZestApp(initialLocation: '/collection/${entry.id}'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      for (final element in find.byType(Image).evaluate()) {
        await precacheImage((element.widget as Image).image, element);
      }
    });
    await tester.pumpAndSettle();

    // No photo yet: the source picture, credited to the source.
    // The image provider is consulted on every rebuild; what matters is
    // that only the cocktail's own source picture is ever requested.
    expect(requestedUrls.toSet(), {
      'https://www.thecocktaildb.com/images/media/drink/garden.jpg',
    });
    expect(
      tester.widget<Image>(find.byType(Image)).semanticLabel,
      'Paper Garden — image from TheCocktailDB',
    );
    expect(find.text('Image: TheCocktailDB'), findsOneWidget);
    expect(keyed('photo-add'), findsOneWidget);
    expect(find.text('Your photo — private to this device'), findsNothing);

    // Adding a photo replaces the source picture with the person's own.
    await activate(tester, keyed('photo-add'));
    await activate(tester, keyed('photo-choose-gallery'));
    expect(find.byType(Image), findsOneWidget);
    expect(
      tester.widget<Image>(find.byType(Image)).semanticLabel,
      'Your photo of Paper Garden',
    );
    expect(find.text('Your photo — private to this device'), findsOneWidget);
    expect(find.text('Image: TheCocktailDB'), findsNothing);
  });
}
