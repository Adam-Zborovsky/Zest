import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;
import 'package:zest/features/catalog/data/catalog_database.dart';

void main() {
  test('migration 1 -> 2 drops the letter-sync tables, keeps no stale rows, '
      'and creates catalog_snapshot', () async {
    final dir = await Directory.systemTemp.createTemp('zest_catalog_migration');
    addTearDown(() => dir.delete(recursive: true));
    final path = '${dir.path}${Platform.pathSeparator}catalog.sqlite';

    // Hand-build a schema-1 database: recipes(with first_letter),
    // ingredient_usages, and letter_sync, with one row in each, then stamp
    // it as schema 1 the way drift itself does (PRAGMA user_version).
    final legacy = sqlite3.sqlite3.open(path);
    legacy.execute('''
      CREATE TABLE recipes (
        provider_id TEXT NOT NULL,
        name TEXT NOT NULL,
        first_letter TEXT NOT NULL,
        source_json TEXT NOT NULL,
        updated_at INTEGER NOT NULL,
        PRIMARY KEY (provider_id)
      );
      CREATE TABLE ingredient_usages (
        recipe_id TEXT NOT NULL,
        normalized_ingredient TEXT NOT NULL,
        PRIMARY KEY (recipe_id, normalized_ingredient)
      );
      CREATE TABLE letter_sync (
        letter TEXT NOT NULL,
        completed_at INTEGER,
        recipe_count INTEGER NOT NULL,
        PRIMARY KEY (letter)
      );
      INSERT INTO recipes VALUES ('700001', 'Legacy Drink', 'a', '{}', 0);
      INSERT INTO ingredient_usages VALUES ('700001', 'legacy ingredient');
      INSERT INTO letter_sync VALUES ('a', 0, 1);
    ''');
    legacy.execute('PRAGMA user_version = 1;');
    legacy.close();

    final database = CatalogDatabase(NativeDatabase(File(path)));
    addTearDown(database.close);

    // Any query forces drift to open the database and run the migration.
    expect(await database.select(database.recipes).get(), isEmpty);
    expect(await database.select(database.ingredientUsages).get(), isEmpty);
    expect(await database.select(database.catalogSnapshotTable).get(), isEmpty);

    // The legacy table is gone outright, not just empty.
    await expectLater(
      database
          .customSelect("SELECT name FROM sqlite_master WHERE name = 'letter_sync'")
          .get()
          .then((rows) => rows.isEmpty),
      completion(isTrue),
    );

    // recipes lost its old first_letter column (schema-1 data is not
    // migrated forward — the catalog is re-downloadable provider data).
    final recipeColumns = await database
        .customSelect("PRAGMA table_info('recipes')")
        .get();
    expect(
      recipeColumns.map((row) => row.data['name']),
      isNot(contains('first_letter')),
    );

    // catalog_snapshot exists with the documented columns, unpopulated
    // until the app downloads and applies its first snapshot.
    final snapshotColumns = await database
        .customSelect("PRAGMA table_info('catalog_snapshot')")
        .get();
    expect(
      snapshotColumns.map((row) => row.data['name']),
      containsAll(['id', 'version', 'published_at', 'recipe_count', 'applied_at']),
    );
  });
}
