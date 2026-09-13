import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/testing.dart';
import 'package:zest/app/zest_app.dart';
import 'package:zest/features/collection/domain/collection_entry.dart';
import 'package:zest/features/collection/presentation/collection_screen.dart';
import 'package:zest/features/discovery/application/discovery_providers.dart';
import 'package:zest/features/discovery/data/cocktail_db_client.dart';
import 'package:zest/features/discovery/domain/recipe.dart';

import '../../../support/collection_test_overrides.dart';
import '../../../support/discovery_fixtures.dart';
import '../../../support/failing_collection_repository.dart';
import '../../../support/in_memory_collection_repository.dart';
import '../../../support/load_fonts.dart';

Finder keyed(String value) => find.byKey(ValueKey(value));

Recipe _recipe() =>
    Recipe.fromJson(discoveryRecipe(id: '99001', name: 'Paper Garden 1'));

Future<FailingCollectionRepository> _open(
  WidgetTester tester, {
  required String location,
  Future<void> Function(InMemoryCollectionRepository inner)? seed,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(412, 1600);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final inner = InMemoryCollectionRepository(
    now: () => DateTime(2026, 9, 13, 12),
  );
  await seed?.call(inner);
  final repository = FailingCollectionRepository(inner);
  final transport = MockClient(
    (_) async => discoveryResponse([
      discoveryRecipe(id: '99001', name: 'Paper Garden 1'),
    ]),
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

Future<void> _activate(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

GoRouter _router(WidgetTester tester) =>
    GoRouter.of(tester.element(find.byType(Scaffold).last));

void main() {
  setUpAll(loadZestFonts);

  testWidgets('a failed save on recipe detail is stated, not dropped', (
    tester,
  ) async {
    final repository = await _open(tester, location: '/discover/recipe/99001');
    repository.failSave = true;

    await _activate(tester, keyed('recipe-save'));

    expect(
      find.text('Zest could not save this recipe on this device. Try again.'),
      findsOneWidget,
    );
    expect(find.text('Saved to your calendar once.'), findsNothing);

    // Recovery: the next attempt succeeds and clears the message.
    repository.failSave = false;
    await _activate(tester, keyed('recipe-save'));
    expect(find.text('Saved to your calendar once.'), findsOneWidget);
    expect(find.textContaining('could not save this recipe'), findsNothing);
  });

  testWidgets('a failed delete keeps the entry open with a message', (
    tester,
  ) async {
    late CollectionEntry entry;
    final repository = await _open(
      tester,
      location: '/collection',
      seed: (inner) async => entry = await inner.saveRecipe(_recipe()),
    );
    _router(tester).go('/collection/${entry.id}');
    await tester.pumpAndSettle();
    repository.failDelete = true;

    await _activate(tester, keyed('entry-delete'));
    await _activate(tester, keyed('entry-delete-confirm'));

    expect(
      find.text('Zest could not remove this entry. Try again.'),
      findsOneWidget,
    );
    expect(_router(tester).state.uri.path, '/collection/${entry.id}');
  });

  testWidgets('a failed photo removal is stated', (tester) async {
    late CollectionEntry entry;
    final repository = await _open(
      tester,
      location: '/collection',
      seed: (inner) async {
        entry = await inner.saveRecipe(_recipe());
        await inner.setPhoto(entry.id, validTinyPng());
      },
    );
    _router(tester).go('/collection/${entry.id}');
    await tester.pumpAndSettle();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    repository.failRemovePhoto = true;

    await _activate(tester, keyed('photo-remove'));
    await _activate(tester, keyed('photo-remove-confirm'));

    expect(
      find.text('Zest could not remove this photo. Try again.'),
      findsOneWidget,
    );
  });

  testWidgets('a failed variation save keeps the edits and says so', (
    tester,
  ) async {
    late CollectionEntry entry;
    final repository = await _open(
      tester,
      location: '/collection',
      seed: (inner) async => entry = await inner.createVariation(
        _recipe(),
        VariationDetails(name: 'My Twist', ingredients: const []),
      ),
    );
    _router(tester).go('/collection/${entry.id}/edit');
    await tester.pumpAndSettle();
    repository.failVariation = true;

    await tester.enterText(keyed('variation-name'), 'My Better Twist');
    await tester.pumpAndSettle();
    await _activate(tester, keyed('variation-save'));

    expect(
      find.text(
        'Zest could not save this variation on this device. Your edits are '
        'still here. Try again.',
      ),
      findsOneWidget,
    );
    expect(_router(tester).state.uri.path, '/collection/${entry.id}/edit');
    expect(find.text('My Better Twist'), findsOneWidget);
  });

  testWidgets('the collection button never stacks the collection on itself', (
    tester,
  ) async {
    await _open(tester, location: '/collection');

    await _activate(tester, keyed('open-collection'));
    await _activate(tester, keyed('open-collection'));

    expect(_router(tester).state.uri.path, '/collection');
    expect(_router(tester).canPop(), isFalse);
    expect(find.byType(CollectionScreen), findsOneWidget);
  });
}
