import 'package:drift/drift.dart';

import '../domain/collection_entry.dart';

part 'collection_database.g.dart';

class CollectionEntryKindConverter
    extends TypeConverter<CollectionEntryKind, String> {
  const CollectionEntryKindConverter();

  @override
  CollectionEntryKind fromSql(String fromDb) =>
      CollectionEntryKind.values.byName(fromDb);

  @override
  String toSql(CollectionEntryKind value) => value.name;
}

/// One collection entry: a saved drink or a personal variation on one
/// calendar day.
///
/// [sourceJson] keeps the full `Recipe.toJson()` snapshot taken when the
/// entry was created, so the entry stays readable offline and never changes
/// when the catalog does. [variationJson] holds `VariationDetails.toJson()`
/// and is present exactly when [kind] is [CollectionEntryKind.variation].
/// [day] is the local calendar day as `YYYY-MM-DD` text (see
/// `collectionDayKey`), so a stored day never shifts with time zones.
///
/// Schema 2 allows any number of saved entries per recipe; schema 1's
/// one-saved-entry unique index is dropped in the migration.
@TableIndex(name: 'entries_source_recipe_id', columns: {#sourceRecipeId})
@TableIndex(name: 'entries_day', columns: {#day})
class Entries extends Table {
  TextColumn get id => text()();
  TextColumn get kind => text().map(const CollectionEntryKindConverter())();
  TextColumn get sourceRecipeId => text()();
  TextColumn get sourceJson => text()();
  TextColumn get variationJson => text().nullable()();
  TextColumn get day => text().withDefault(const Constant(''))();
  BoolColumn get hasPhoto => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  /// Schema 3 (M8 sync). True while this row has local changes the server
  /// has not yet seen. New rows are dirty by default so an offline save
  /// still uploads once the person signs in or reconnects.
  BoolColumn get dirty => boolean().withDefault(const Constant(true))();

  /// Schema 3. A tombstone: the row is kept (its sync history matters) but
  /// every read hides it. Set by `DriftCollectionRepository.delete`.
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();

  /// Schema 3. True while this entry's photo has a local change (set or
  /// removed) not yet pushed, independent of [dirty].
  BoolColumn get photoDirty => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Schema 3 (M8 sync). One row (id 0) tracking which account owns this
/// device's collection data and how far its pull has progressed.
class SyncState extends Table {
  IntColumn get id => integer().withDefault(const Constant(0))();

  /// Null until an account has claimed this device's data.
  TextColumn get ownerUserId => text().nullable()();
  IntColumn get lastRevision => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

/// The photo bytes for one entry, kept in a separate table so listing
/// entries never loads image bytes. Deleting an entry deletes its photo row
/// in the same transaction (`DriftCollectionRepository.delete`).
class Photos extends Table {
  TextColumn get entryId => text()();
  TextColumn get mimeType => text()();
  BlobColumn get bytes => blob()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {entryId};
}

@DriftDatabase(tables: [Entries, Photos, SyncState])
final class CollectionDatabase extends _$CollectionDatabase {
  /// Tests pass an in-memory or temp-file executor; the app passes the
  /// platform-appropriate connection from `openCollectionConnection`.
  CollectionDatabase(super.executor);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        // The calendar: every entry gets a day, and one recipe may be saved
        // on many days, so the one-saved-entry-per-recipe index goes.
        await m.addColumn(entries, entries.day);
        await customStatement(
          'DROP INDEX IF EXISTS entries_saved_source_unique;',
        );
        await customStatement(
          'CREATE INDEX IF NOT EXISTS entries_day ON entries (day);',
        );
      }
      if (from < 3) {
        // M8 sync: every existing row predates accounts, so it is marked
        // dirty (the column's own default) to upload on the first sign-in.
        await m.addColumn(entries, entries.dirty);
        await m.addColumn(entries, entries.deleted);
        await m.addColumn(entries, entries.photoDirty);
        await m.createTable(syncState);
      }
      if (from < 2) {
        // Date each existing entry by the local day it was created. Done in
        // Dart rather than SQL so the day matches the app's own local time,
        // which SQLite on the web cannot see. Runs after every column for
        // the target schema exists, so mapping a row here never hits a
        // column that has not been added yet.
        final rows = await select(entries).get();
        for (final row in rows) {
          await (update(entries)..where((t) => t.id.equals(row.id))).write(
            EntriesCompanion(day: Value(collectionDayKey(row.createdAt))),
          );
        }
      }
    },
  );
}
