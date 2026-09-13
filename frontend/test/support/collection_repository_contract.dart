import 'package:flutter_test/flutter_test.dart';
import 'package:zest/features/collection/data/collection_repository.dart';
import 'package:zest/features/collection/domain/collection_entry.dart';
import 'package:zest/features/discovery/domain/recipe.dart';

import 'catalog_fixtures.dart';
import 'in_memory_collection_repository.dart';

/// A reusable contract suite exercising every invariant documented on
/// [CollectionRepository]. Run it against every implementation so screens
/// built against one behave the same way against the others.
///
/// [create] builds a fresh, empty repository for one test, given the `now`
/// function that test controls (so ordering and `updatedAt` bumps can be
/// asserted deterministically). [onTearDown] releases whatever [create]
/// opened (a database connection, for example) after each test. (Named
/// [onTearDown], not `tearDown`, so it does not shadow `package:test`'s
/// top-level `tearDown` used below.)
void runCollectionRepositoryContract(
  String label,
  CollectionRepository Function(DateTime Function() now) create, {
  Future<void> Function()? onTearDown,
}) {
  group(label, () {
    late DateTime current;
    late CollectionRepository repository;

    DateTime now() => current;

    setUp(() {
      current = DateTime(2026, 9, 12, 10);
      repository = create(now);
    });

    tearDown(() async {
      await onTearDown?.call();
    });

    Recipe recipe({String id = '98001', String name = 'Testbench Tonic'}) =>
        Recipe.fromJson(catalogRecipe(id: id, name: name));

    VariationDetails details({String name = 'My Twist'}) => VariationDetails(
      name: name,
      ingredients: [VariationIngredient(name: 'Gin', measure: '2 oz')],
      method: 'Shake it.',
      notes: 'Extra citrusy.',
    );

    test('watchEntries starts empty', () async {
      expect(await repository.watchEntries().first, isEmpty);
    });

    test('watchEntry and watchSavedFor start null for an unknown id', () async {
      expect(await repository.watchEntry('missing').first, isNull);
      expect(await repository.watchSavedFor('missing').first, isNull);
    });

    test('saveRecipe creates a saved entry with the source snapshot', () async {
      final source = recipe();
      final entry = await repository.saveRecipe(source);

      expect(entry.kind, CollectionEntryKind.saved);
      expect(entry.isVariation, isFalse);
      expect(entry.sourceRecipeId, source.id);
      expect(entry.variation, isNull);
      expect(entry.hasPhoto, isFalse);
      expect(entry.createdAt, current);
      expect(entry.updatedAt, current);
      // The stored source snapshot round-trips to an equal `Recipe.toJson`.
      expect(entry.source.toJson(), source.toJson());
    });

    test('saveRecipe is idempotent per source recipe id', () async {
      final source = recipe();
      final first = await repository.saveRecipe(source);
      current = current.add(const Duration(minutes: 5));
      final second = await repository.saveRecipe(source);

      expect(second.id, first.id);
      expect(second.createdAt, first.createdAt);
      expect(second.updatedAt, first.updatedAt);
      expect(await repository.watchEntries().first, hasLength(1));
    });

    test(
      'saveRecipe allows different source recipes as separate entries',
      () async {
        await repository.saveRecipe(recipe(id: '1', name: 'One'));
        await repository.saveRecipe(recipe(id: '2', name: 'Two'));

        expect(await repository.watchEntries().first, hasLength(2));
      },
    );

    test('createVariation always creates a new entry', () async {
      final source = recipe();
      final first = await repository.createVariation(source, details());
      final second = await repository.createVariation(
        source,
        details(name: 'Second Twist'),
      );

      expect(first.id, isNot(second.id));
      expect(first.kind, CollectionEntryKind.variation);
      expect(first.isVariation, isTrue);
      expect(first.variation, details());
      expect(first.source.toJson(), source.toJson());
      expect(await repository.watchEntries().first, hasLength(2));
    });

    test(
      'a source can have many variations independent of being saved',
      () async {
        final source = recipe();
        await repository.saveRecipe(source);
        await repository.createVariation(source, details(name: 'A'));
        await repository.createVariation(source, details(name: 'B'));

        final entries = await repository.watchEntries().first;
        expect(entries, hasLength(3));
        expect(
          entries.where((e) => e.isVariation).map((e) => e.displayName),
          containsAll(<String>['A', 'B']),
        );
      },
    );

    test(
      'updateVariation replaces variation details and bumps updatedAt',
      () async {
        final entry = await repository.createVariation(recipe(), details());
        current = current.add(const Duration(minutes: 10));

        final updated = await repository.updateVariation(
          entry.id,
          details(name: 'Updated Twist'),
        );

        expect(updated.id, entry.id);
        expect(updated.variation!.name, 'Updated Twist');
        expect(updated.createdAt, entry.createdAt);
        expect(updated.updatedAt, current);
        expect(
          (await repository.watchEntry(entry.id).first)!.variation!.name,
          'Updated Twist',
        );
      },
    );

    test('updateVariation throws StateError for a missing id', () async {
      expect(
        () => repository.updateVariation('missing', details()),
        throwsA(isA<StateError>()),
      );
    });

    test('updateVariation throws StateError for a saved entry', () async {
      final entry = await repository.saveRecipe(recipe());
      expect(
        () => repository.updateVariation(entry.id, details()),
        throwsA(isA<StateError>()),
      );
    });

    test('delete removes the entry', () async {
      final entry = await repository.saveRecipe(recipe());
      await repository.delete(entry.id);

      expect(await repository.watchEntry(entry.id).first, isNull);
      expect(await repository.watchEntries().first, isEmpty);
    });

    test('deleting a missing id is a no-op', () async {
      await repository.delete('missing');
      expect(await repository.watchEntries().first, isEmpty);
    });

    test('deleting a saved recipe never deletes its variations', () async {
      final source = recipe();
      final saved = await repository.saveRecipe(source);
      final variation = await repository.createVariation(source, details());

      await repository.delete(saved.id);

      expect(await repository.watchEntry(saved.id).first, isNull);
      expect(await repository.watchEntry(variation.id).first, isNotNull);
    });

    test('delete removes the entry photo', () async {
      final entry = await repository.saveRecipe(recipe());
      await repository.setPhoto(entry.id, validTinyPng());
      await repository.delete(entry.id);

      expect(await repository.photo(entry.id), isNull);
    });

    test('setPhoto throws StateError for a missing id', () async {
      expect(
        () => repository.setPhoto('missing', validTinyPng()),
        throwsA(isA<StateError>()),
      );
    });

    test('setPhoto sets hasPhoto and stores the photo', () async {
      final entry = await repository.saveRecipe(recipe());
      await repository.setPhoto(entry.id, validTinyPng());

      final stored = await repository.watchEntry(entry.id).first;
      expect(stored!.hasPhoto, isTrue);
      final photo = await repository.photo(entry.id);
      expect(photo, isNotNull);
      expect(photo!.mimeType, 'image/png');
    });

    test('setPhoto replaces any existing photo', () async {
      final entry = await repository.saveRecipe(recipe());
      await repository.setPhoto(entry.id, validTinyPng());
      final replacement = syntheticPngPhoto();
      await repository.setPhoto(entry.id, replacement);

      final photo = await repository.photo(entry.id);
      expect(photo!.bytes, replacement.bytes);
    });

    test('removePhoto is a no-op when there is none', () async {
      final entry = await repository.saveRecipe(recipe());
      await repository.removePhoto(entry.id);

      expect((await repository.watchEntry(entry.id).first)!.hasPhoto, isFalse);
      expect(await repository.photo(entry.id), isNull);
    });

    test('removePhoto clears an existing photo', () async {
      final entry = await repository.saveRecipe(recipe());
      await repository.setPhoto(entry.id, validTinyPng());
      await repository.removePhoto(entry.id);

      expect((await repository.watchEntry(entry.id).first)!.hasPhoto, isFalse);
      expect(await repository.photo(entry.id), isNull);
    });

    test('photo returns null for a missing id', () async {
      expect(await repository.photo('missing'), isNull);
    });

    test('watchSavedFor tracks save and delete of the saved entry', () async {
      final source = recipe();
      expect(await repository.watchSavedFor(source.id).first, isNull);

      final saved = await repository.saveRecipe(source);
      expect((await repository.watchSavedFor(source.id).first)!.id, saved.id);

      await repository.delete(saved.id);
      expect(await repository.watchSavedFor(source.id).first, isNull);
    });

    test('watchEntries orders by updatedAt descending, then id', () async {
      current = DateTime(2026, 9, 12, 10);
      final a = await repository.saveRecipe(recipe(id: '101', name: 'A'));
      current = current.add(const Duration(minutes: 1));
      final b = await repository.saveRecipe(recipe(id: '102', name: 'B'));
      current = current.add(const Duration(minutes: 1));
      final c = await repository.saveRecipe(recipe(id: '103', name: 'C'));

      // Bump `a` back to the front by touching its photo, which bumps
      // `updatedAt` without changing its identity.
      current = current.add(const Duration(minutes: 1));
      await repository.setPhoto(a.id, validTinyPng());

      final ids = (await repository.watchEntries().first)
          .map((entry) => entry.id)
          .toList();
      expect(ids, [a.id, c.id, b.id]);
    });

    test('watchEntries emits again after a relevant change', () async {
      final events = <int>[];
      final subscription = repository.watchEntries().listen(
        (entries) => events.add(entries.length),
      );
      addTearDown(subscription.cancel);

      await pumpEventQueue();
      await repository.saveRecipe(recipe());
      await pumpEventQueue();

      expect(events, [0, 1]);
    });
  });
}
