import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zest/features/collection/data/collection_database.dart';
import 'package:zest/features/collection/data/drift_collection_repository.dart';
import 'package:zest/features/collection/domain/collection_entry.dart';
import 'package:zest/features/discovery/domain/recipe.dart';

import '../../../support/catalog_fixtures.dart';
import '../../../support/collection_repository_contract.dart';
import '../../../support/in_memory_collection_repository.dart';

CollectionDatabase openInMemoryCollection() => CollectionDatabase(
  DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
);

void main() {
  CollectionDatabase? database;

  runCollectionRepositoryContract('DriftCollectionRepository', (now) {
    final db = openInMemoryCollection();
    database = db;
    return DriftCollectionRepository(database: db, now: now);
  }, onTearDown: () async => database?.close());

  group('DriftCollectionRepository drift-specific behavior', () {
    late CollectionDatabase database;
    late DriftCollectionRepository repository;
    final stamp = DateTime(2026, 9, 12, 9, 30);

    setUp(() {
      database = openInMemoryCollection();
      repository = DriftCollectionRepository(
        database: database,
        now: () => stamp,
      );
    });

    tearDown(() => database.close());

    Recipe recipe({String id = '98001', String name = 'Testbench Tonic'}) =>
        Recipe.fromJson(catalogRecipe(id: id, name: name));

    test(
      'a unique saved entry per source recipe id is enforced at the database level',
      () async {
        final source = recipe();
        await repository.saveRecipe(source);

        // Bypass the app-level check-then-insert to prove the partial
        // unique index itself rejects a second saved row for the same
        // source, not merely the repository's own guard.
        await expectLater(
          database
              .into(database.entries)
              .insert(
                EntriesCompanion.insert(
                  id: 'forced-duplicate',
                  kind: CollectionEntryKind.saved,
                  sourceRecipeId: source.id,
                  sourceJson: '{}',
                  createdAt: stamp,
                  updatedAt: stamp,
                ),
              ),
          throwsA(anything),
        );
      },
    );

    test(
      'two variations of the same source do not collide with the unique index',
      () async {
        final source = recipe();
        await repository.createVariation(
          source,
          VariationDetails(name: 'A', ingredients: const []),
        );
        await repository.createVariation(
          source,
          VariationDetails(name: 'B', ingredients: const []),
        );

        expect(await repository.watchEntries().first, hasLength(2));
      },
    );

    test(
      'photo bytes live in the photos table and list queries never load them',
      () async {
        final entry = await repository.saveRecipe(recipe());
        await repository.setPhoto(entry.id, onePixelPng());

        // The entries table itself carries no bytes column, so a plain
        // select of entries physically cannot return image bytes.
        final entryRow = await (database.select(
          database.entries,
        )..where((t) => t.id.equals(entry.id))).getSingle();
        expect(entryRow.hasPhoto, isTrue);

        final photoRow = await (database.select(
          database.photos,
        )..where((t) => t.entryId.equals(entry.id))).getSingle();
        expect(photoRow.bytes, onePixelPng().bytes);
        expect(photoRow.mimeType, 'image/png');
      },
    );

    test('a reopened temp-file database keeps entries and photos', () async {
      final dir = await Directory.systemTemp.createTemp('zest-collection-test');
      addTearDown(() => dir.delete(recursive: true));
      final path = '${dir.path}${Platform.pathSeparator}collection.sqlite';

      var db = CollectionDatabase(NativeDatabase(File(path)));
      var repo = DriftCollectionRepository(database: db, now: () => stamp);
      final source = recipe();
      final saved = await repo.saveRecipe(source);
      await repo.setPhoto(saved.id, onePixelPng());
      await db.close();

      db = CollectionDatabase(NativeDatabase(File(path)));
      repo = DriftCollectionRepository(database: db, now: () => stamp);
      final reopened = await repo.watchEntry(saved.id).first;
      expect(reopened, isNotNull);
      expect(reopened!.source.toJson(), source.toJson());
      final photo = await repo.photo(saved.id);
      expect(photo, isNotNull);
      expect(photo!.bytes, onePixelPng().bytes);
      await db.close();
    });

    test(
      'malformed stored source JSON surfaces as a clear error, not a silent empty entry',
      () async {
        await database
            .into(database.entries)
            .insert(
              EntriesCompanion.insert(
                id: 'broken',
                kind: CollectionEntryKind.saved,
                sourceRecipeId: 'broken-source',
                sourceJson: 'not json',
                createdAt: stamp,
                updatedAt: stamp,
              ),
            );

        await expectLater(
          repository.watchEntry('broken').first,
          throwsA(isA<FormatException>()),
        );
      },
    );
  });
}
