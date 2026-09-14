import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as raw;
import 'package:zest/features/collection/data/collection_database.dart';
import 'package:zest/features/collection/data/drift_collection_repository.dart';
import 'package:zest/features/collection/domain/collection_entry.dart';
import 'package:zest/features/collection/sync/sync_contract.dart';
import 'package:zest/features/discovery/domain/recipe.dart';

import '../../../support/catalog_fixtures.dart';
import '../../../support/in_memory_collection_repository.dart';

CollectionDatabase openInMemoryCollection() => CollectionDatabase(
  DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
);

void main() {
  group('schema 3 sync flags', () {
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

    Recipe recipe() =>
        Recipe.fromJson(catalogRecipe(id: '98001', name: 'Testbench Tonic'));

    test('a new saved entry is dirty', () async {
      final entry = await repository.saveRecipe(recipe());
      final dirty = await repository.dirtyRecords();
      expect(dirty.map((r) => r.id), contains(entry.id));
      expect(dirty.single.dirty, isTrue);
      expect(dirty.single.deleted, isFalse);
    });

    test('delete writes a tombstone, hides the entry from reads, and removes '
        'the photo', () async {
      final entry = await repository.saveRecipe(recipe());
      await repository.setPhoto(entry.id, validTinyPng());

      await repository.delete(entry.id);

      expect(await repository.watchEntry(entry.id).first, isNull);
      expect(await repository.watchEntries().first, isEmpty);
      expect(await repository.photo(entry.id), isNull);

      final local = await repository.localRecord(entry.id);
      expect(local, isNotNull);
      expect(local!.deleted, isTrue);
      expect(local.dirty, isTrue);
      expect(local.hasPhoto, isFalse);
    });

    test('setPhoto and removePhoto mark the row dirty and photoDirty', () async {
      final entry = await repository.saveRecipe(recipe());
      final asPushed = (await repository.localRecord(entry.id))!.toEntryRecord();
      await repository.applyServerRecord(
        EntryRecord(
          id: asPushed.id,
          kind: asPushed.kind,
          sourceRecipeId: asPushed.sourceRecipeId,
          source: asPushed.source,
          variation: asPushed.variation,
          day: asPushed.day,
          hasPhoto: asPushed.hasPhoto,
          photoUpdatedAt: asPushed.photoUpdatedAt,
          createdAt: asPushed.createdAt,
          updatedAt: asPushed.updatedAt,
          deleted: asPushed.deleted,
          revision: 1,
        ),
      );
      expect((await repository.localRecord(entry.id))!.dirty, isFalse);

      await repository.setPhoto(entry.id, validTinyPng());
      final afterSet = await repository.localRecord(entry.id);
      expect(afterSet!.dirty, isTrue);
      expect(afterSet.photoDirty, isTrue);

      await repository.applyServerRecord(
        afterSet.toEntryRecord(),
        clearPhotoDirty: true,
      );
      expect((await repository.localRecord(entry.id))!.photoDirty, isFalse);

      await repository.removePhoto(entry.id);
      final afterRemove = await repository.localRecord(entry.id);
      expect(afterRemove!.dirty, isTrue);
      expect(afterRemove.photoDirty, isTrue);
    });

    test('applyServerRecord adopts server content and clears dirty', () async {
      final entry = await repository.saveRecipe(recipe());
      final server = EntryRecord(
        id: entry.id,
        kind: CollectionEntryKind.saved,
        sourceRecipeId: entry.sourceRecipeId,
        source: entry.source.toJson(),
        variation: null,
        day: '2026-09-01',
        hasPhoto: false,
        photoUpdatedAt: null,
        createdAt: entry.createdAt,
        updatedAt: DateTime(2026, 9, 13, 10),
        deleted: false,
        revision: 9,
      );

      await repository.applyServerRecord(server);

      final local = await repository.localRecord(entry.id);
      expect(local!.dirty, isFalse);
      expect(local.day, '2026-09-01');
      expect(local.updatedAt.isAtSameMomentAs(DateTime(2026, 9, 13, 10)), isTrue);
    });

    test(
      'applyServerRecord removes the local photo when the server has none '
      'and no local photo change is pending',
      () async {
        final entry = await repository.saveRecipe(recipe());
        await repository.setPhoto(entry.id, validTinyPng());
        // Settle the photo push so photoDirty is false, as it would be by
        // the time a later pull's server-authoritative record (e.g. another
        // device removed the photo) arrives.
        final afterSet = (await repository.localRecord(entry.id))!;
        await repository.applyServerRecord(
          afterSet.toEntryRecord(),
          clearPhotoDirty: true,
        );

        await repository.applyServerRecord(
          EntryRecord(
            id: entry.id,
            kind: CollectionEntryKind.saved,
            sourceRecipeId: entry.sourceRecipeId,
            source: entry.source.toJson(),
            variation: null,
            day: '2026-09-12',
            hasPhoto: false,
            photoUpdatedAt: null,
            createdAt: entry.createdAt,
            updatedAt: DateTime(2026, 9, 13, 11),
            deleted: false,
            revision: 2,
          ),
        );

        expect(await repository.photo(entry.id), isNull);
      },
    );

    test(
      'applyServerRecord keeps a not-yet-pushed local photo instead of '
      'deleting it when the record carries a stale hasPhoto: false '
      '(M8 fix: entry PUT does not own photo state)',
      () async {
        final entry = await repository.saveRecipe(recipe());
        await repository.setPhoto(entry.id, validTinyPng());
        final afterSet = (await repository.localRecord(entry.id))!;
        expect(afterSet.photoDirty, isTrue);

        // Simulates the response to an entry PUT (or a pull) that has not
        // observed this device's still-unpushed photo: hasPhoto: false,
        // clearPhotoDirty not set. This must not delete the local photo
        // bytes or misreport the entry as photo-less before the photo push
        // runs.
        await repository.applyServerRecord(
          EntryRecord(
            id: entry.id,
            kind: CollectionEntryKind.saved,
            sourceRecipeId: entry.sourceRecipeId,
            source: entry.source.toJson(),
            variation: null,
            day: afterSet.day,
            hasPhoto: false,
            photoUpdatedAt: null,
            createdAt: entry.createdAt,
            updatedAt: DateTime(2026, 9, 13, 11),
            deleted: false,
            revision: 2,
          ),
        );

        expect(await repository.photo(entry.id), isNotNull);
        final local = await repository.localRecord(entry.id);
        expect(local!.hasPhoto, isTrue);
        expect(local.photoDirty, isTrue);
        // The entry-level fields still adopt the server record.
        expect(local.dirty, isFalse);
        expect(local.day, afterSet.day);
      },
    );

    test(
      'applyServerRecord removes the local photo for a tombstone even with '
      'a photo change pending',
      () async {
        final entry = await repository.saveRecipe(recipe());
        await repository.setPhoto(entry.id, validTinyPng());

        await repository.applyServerRecord(
          EntryRecord(
            id: entry.id,
            kind: CollectionEntryKind.saved,
            sourceRecipeId: entry.sourceRecipeId,
            source: null,
            variation: null,
            day: '2026-09-12',
            hasPhoto: false,
            photoUpdatedAt: null,
            createdAt: entry.createdAt,
            updatedAt: DateTime(2026, 9, 13, 11),
            deleted: true,
            revision: 2,
          ),
        );

        expect(await repository.photo(entry.id), isNull);
      },
    );

    test('owner id and last revision round-trip through sync state', () async {
      expect(await repository.ownerUserId(), isNull);
      expect(await repository.lastRevision(), 0);

      await repository.setOwnerUserId('user-1');
      await repository.setLastRevision(42);

      expect(await repository.ownerUserId(), 'user-1');
      expect(await repository.lastRevision(), 42);
    });

    test('wipe clears entries and photos but keeps the owner id', () async {
      final entry = await repository.saveRecipe(recipe());
      await repository.setPhoto(entry.id, validTinyPng());
      await repository.setOwnerUserId('user-1');
      await repository.setLastRevision(7);

      await repository.wipe();

      expect(await repository.watchEntries().first, isEmpty);
      expect(await repository.photo(entry.id), isNull);
      expect(await repository.ownerUserId(), 'user-1');
      expect(await repository.lastRevision(), 0);
    });
  });

  group('schema 2 to 3 migration', () {
    test('marks every existing entry dirty and creates the sync_state table', () async {
      final dir = await Directory.systemTemp.createTemp('zest-migration3-test');
      addTearDown(() => dir.delete(recursive: true));
      final path = '${dir.path}${Platform.pathSeparator}collection.sqlite';
      final source = Recipe.fromJson(
        catalogRecipe(id: '98001', name: 'Testbench Tonic'),
      );
      final createdAt = DateTime(2026, 9, 10, 21, 30);
      final seconds = createdAt.millisecondsSinceEpoch ~/ 1000;

      final legacy = raw.sqlite3.open(path);
      legacy.execute('''
        CREATE TABLE entries (
          id TEXT NOT NULL,
          kind TEXT NOT NULL,
          source_recipe_id TEXT NOT NULL,
          source_json TEXT NOT NULL,
          variation_json TEXT NULL,
          day TEXT NOT NULL DEFAULT '',
          has_photo INTEGER NOT NULL DEFAULT 0 CHECK ("has_photo" IN (0, 1)),
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          PRIMARY KEY (id)
        );
      ''');
      legacy.execute('''
        CREATE TABLE photos (
          entry_id TEXT NOT NULL,
          mime_type TEXT NOT NULL,
          bytes BLOB NOT NULL,
          updated_at INTEGER NOT NULL,
          PRIMARY KEY (entry_id)
        );
      ''');
      legacy.execute(
        'CREATE INDEX entries_source_recipe_id ON entries (source_recipe_id);',
      );
      legacy.execute('CREATE INDEX entries_day ON entries (day);');
      legacy.execute(
        'INSERT INTO entries (id, kind, source_recipe_id, source_json, day, '
        'has_photo, created_at, updated_at) VALUES (?, ?, ?, ?, ?, 1, ?, ?);',
        [
          'legacy-saved',
          'saved',
          source.id,
          jsonEncode(source.toJson()),
          '2026-09-10',
          seconds,
          seconds,
        ],
      );
      legacy.execute(
        'INSERT INTO photos (entry_id, mime_type, bytes, updated_at) '
        'VALUES (?, ?, ?, ?);',
        ['legacy-saved', 'image/png', validTinyPng().bytes, seconds],
      );
      legacy.userVersion = 2;
      legacy.close();

      final db = CollectionDatabase(NativeDatabase(File(path)));
      addTearDown(db.close);
      final repo = DriftCollectionRepository(
        database: db,
        now: () => DateTime(2026, 9, 13, 12),
      );

      final entries = await repo.watchEntries().first;
      expect(entries, hasLength(1));
      expect(entries.single.id, 'legacy-saved');
      expect((await repo.photo('legacy-saved'))!.bytes, validTinyPng().bytes);

      final local = await repo.localRecord('legacy-saved');
      expect(local!.dirty, isTrue);
      expect(local.deleted, isFalse);
      expect(local.photoDirty, isFalse);

      expect(await repo.ownerUserId(), isNull);
      expect(await repo.lastRevision(), 0);
    });
  });
}
