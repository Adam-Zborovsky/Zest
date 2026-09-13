import 'dart:convert';

import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as raw;
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

    test('the day is stored as YYYY-MM-DD text', () async {
      final entry = await repository.saveRecipe(recipe());
      final row = await (database.select(
        database.entries,
      )..where((t) => t.id.equals(entry.id))).getSingle();
      expect(row.day, '2026-09-12');
    });

    test(
      'photo bytes live in the photos table and list queries never load them',
      () async {
        final entry = await repository.saveRecipe(recipe());
        await repository.setPhoto(entry.id, validTinyPng());

        // The entries table itself carries no bytes column, so a plain
        // select of entries physically cannot return image bytes.
        final entryRow = await (database.select(
          database.entries,
        )..where((t) => t.id.equals(entry.id))).getSingle();
        expect(entryRow.hasPhoto, isTrue);

        final photoRow = await (database.select(
          database.photos,
        )..where((t) => t.entryId.equals(entry.id))).getSingle();
        expect(photoRow.bytes, validTinyPng().bytes);
        expect(photoRow.mimeType, 'image/png');
      },
    );

    test(
      'a reopened temp-file database keeps entries, days, and photos',
      () async {
        final dir = await Directory.systemTemp.createTemp(
          'zest-collection-test',
        );
        addTearDown(() => dir.delete(recursive: true));
        final path = '${dir.path}${Platform.pathSeparator}collection.sqlite';

        var db = CollectionDatabase(NativeDatabase(File(path)));
        var repo = DriftCollectionRepository(database: db, now: () => stamp);
        final source = recipe();
        final saved = await repo.saveRecipe(source);
        await repo.moveToDay(saved.id, DateTime(2026, 9, 3));
        await repo.setPhoto(saved.id, validTinyPng());
        await db.close();

        db = CollectionDatabase(NativeDatabase(File(path)));
        repo = DriftCollectionRepository(database: db, now: () => stamp);
        final reopened = await repo.watchEntry(saved.id).first;
        expect(reopened, isNotNull);
        expect(reopened!.source.toJson(), source.toJson());
        expect(reopened.day, DateTime(2026, 9, 3));
        final photo = await repo.photo(saved.id);
        expect(photo, isNotNull);
        expect(photo!.bytes, validTinyPng().bytes);
        await db.close();
      },
    );

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
                day: const Value('2026-09-12'),
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

    test('a malformed stored day surfaces as a clear error', () async {
      final entry = await repository.saveRecipe(recipe());
      await (database.update(database.entries)
            ..where((t) => t.id.equals(entry.id)))
          .write(const EntriesCompanion(day: Value('13/09/2026')));

      await expectLater(
        repository.watchEntry(entry.id).first,
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('Malformed day'),
          ),
        ),
      );
    });
  });

  group('schema 1 to 2 migration', () {
    test('keeps every entry and photo, dates entries by their local creation '
        'day, and allows saving a recipe again', () async {
      final dir = await Directory.systemTemp.createTemp('zest-migration-test');
      addTearDown(() => dir.delete(recursive: true));
      final path = '${dir.path}${Platform.pathSeparator}collection.sqlite';
      final source = Recipe.fromJson(
        catalogRecipe(id: '98001', name: 'Testbench Tonic'),
      );
      final createdAt = DateTime(2026, 9, 10, 21, 30);
      final seconds = createdAt.millisecondsSinceEpoch ~/ 1000;

      // Build a schema 1 database exactly as M6 shipped it, including the
      // one-saved-entry-per-recipe unique index.
      final legacy = raw.sqlite3.open(path);
      legacy.execute('''
        CREATE TABLE entries (
          id TEXT NOT NULL,
          kind TEXT NOT NULL,
          source_recipe_id TEXT NOT NULL,
          source_json TEXT NOT NULL,
          variation_json TEXT NULL,
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
      legacy.execute(
        'CREATE UNIQUE INDEX entries_saved_source_unique '
        "ON entries (source_recipe_id) WHERE kind = 'saved';",
      );
      legacy.execute(
        'INSERT INTO entries (id, kind, source_recipe_id, source_json, '
        'has_photo, created_at, updated_at) VALUES (?, ?, ?, ?, 1, ?, ?);',
        [
          'legacy-saved',
          'saved',
          source.id,
          jsonEncode(source.toJson()),
          seconds,
          seconds,
        ],
      );
      legacy.execute(
        'INSERT INTO photos (entry_id, mime_type, bytes, updated_at) '
        'VALUES (?, ?, ?, ?);',
        ['legacy-saved', 'image/png', validTinyPng().bytes, seconds],
      );
      legacy.userVersion = 1;
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
      expect(entries.single.day, DateTime(2026, 9, 10));
      expect(entries.single.hasPhoto, isTrue);
      expect((await repo.photo('legacy-saved'))!.bytes, validTinyPng().bytes);

      // The unique index is gone: the same recipe saves again, today.
      final again = await repo.saveRecipe(source);
      expect(again.day, DateTime(2026, 9, 13));
      expect(await repo.watchSavedEntriesFor(source.id).first, hasLength(2));
    });
  });
}
