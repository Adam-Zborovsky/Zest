import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:zest/app/zest_app.dart';
import 'package:zest/features/collection/data/image_picker_memory_photo_picker.dart';
import 'package:zest/features/collection/data/memory_photo_picker.dart';
import 'package:zest/features/collection/domain/memory_photo.dart';
import 'package:zest/features/discovery/application/discovery_providers.dart';
import 'package:zest/features/discovery/data/cocktail_db_client.dart';
import 'package:zest/features/discovery/domain/recipe.dart';

import '../../../support/collection_test_overrides.dart';
import '../../../support/in_memory_session.dart';
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

Future<String> openEntry(
  WidgetTester tester, {
  required InMemoryCollectionRepository repository,
  required FakeMemoryPhotoPicker picker,
}) async {
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
  final entry = await repository.saveRecipe(
    Recipe.fromJson(discoveryRecipe(id: '99001', name: 'Photo Garden')),
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...collectionTestOverrides(repository: repository, picker: picker),
        ...sessionTestOverrides(),
        cocktailDbClientProvider.overrideWithValue(client),
      ],
      child: ZestApp(initialLocation: '/collection/${entry.id}'),
    ),
  );
  await tester.pumpAndSettle();
  return entry.id;
}

void main() {
  setUpAll(loadZestFonts);

  testWidgets('adding a photo shows it and offers replace/remove', (
    tester,
  ) async {
    final repository = InMemoryCollectionRepository();
    final picker = FakeMemoryPhotoPicker(next: validTinyPng());
    await openEntry(tester, repository: repository, picker: picker);

    expect(find.text('No photo added yet'), findsNothing);
    expect(keyed('photo-add'), findsOneWidget);
    await activate(tester, keyed('photo-add'));
    expect(find.text('Choose from your photos'), findsOneWidget);
    expect(keyed('photo-take-camera'), findsOneWidget);
    await activate(tester, keyed('photo-choose-gallery'));

    expect(picker.requests, [PhotoSource.gallery]);
    expect(find.byType(Image), findsOneWidget);
    expect(keyed('photo-replace'), findsOneWidget);
    expect(keyed('photo-remove'), findsOneWidget);
    expect(keyed('photo-add'), findsNothing);

    // Replace with a second photo.
    picker.next = validTinyPng();
    await activate(tester, keyed('photo-replace'));
    await activate(tester, keyed('photo-choose-gallery'));
    expect(picker.requests, [PhotoSource.gallery, PhotoSource.gallery]);
    expect(find.byType(Image), findsOneWidget);

    // Remove requires confirmation.
    await activate(tester, keyed('photo-remove'));
    expect(find.text('Remove this photo?'), findsOneWidget);
    await activate(tester, keyed('photo-remove-confirm'));
    expect(find.byType(Image), findsNothing);
    expect(keyed('photo-add'), findsOneWidget);
  });

  testWidgets('cancelling the picker changes nothing', (tester) async {
    final repository = InMemoryCollectionRepository();
    final picker = FakeMemoryPhotoPicker(next: null);
    await openEntry(tester, repository: repository, picker: picker);

    await activate(tester, keyed('photo-add'));
    await activate(tester, keyed('photo-choose-gallery'));
    expect(picker.requests, [PhotoSource.gallery]);
    expect(find.byType(Image), findsNothing);
    expect(keyed('photo-add'), findsOneWidget);
  });

  testWidgets('a rejected photo shows its recoverable message', (tester) async {
    final repository = InMemoryCollectionRepository();
    final picker = FakeMemoryPhotoPicker(
      error: const PhotoRejected(PhotoRejection.tooLarge),
    );
    await openEntry(tester, repository: repository, picker: picker);

    await activate(tester, keyed('photo-add'));
    await activate(tester, keyed('photo-choose-gallery'));
    expect(
      find.text('That photo is too large to keep. Try a smaller one.'),
      findsOneWidget,
    );
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('a platform pick failure shows its recoverable message', (
    tester,
  ) async {
    final repository = InMemoryCollectionRepository();
    final picker = FakeMemoryPhotoPicker(
      error: const PhotoPickerUnavailable(
        'Zest could not reach your photos. Check permissions and try again.',
      ),
    );
    await openEntry(tester, repository: repository, picker: picker);

    await activate(tester, keyed('photo-add'));
    await activate(tester, keyed('photo-choose-gallery'));
    expect(
      find.text(
        'Zest could not reach your photos. Check permissions and try again.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('the camera option is hidden when the picker has no camera', (
    tester,
  ) async {
    final repository = InMemoryCollectionRepository();
    final picker = FakeMemoryPhotoPicker(supportsCamera: false);
    await openEntry(tester, repository: repository, picker: picker);

    await activate(tester, keyed('photo-add'));
    expect(keyed('photo-choose-gallery'), findsOneWidget);
    expect(keyed('photo-take-camera'), findsNothing);
  });
}
