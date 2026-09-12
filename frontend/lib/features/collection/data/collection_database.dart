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

/// One collection entry: a saved recipe or a personal variation.
///
/// [sourceJson] keeps the full `Recipe.toJson()` snapshot taken when the
/// entry was created, so the entry stays readable offline and never changes
/// when the catalog does. [variationJson] holds `VariationDetails.toJson()`
/// and is present exactly when [kind] is [CollectionEntryKind.variation].
///
/// At most one [CollectionEntryKind.saved] entry may exist per
/// [sourceRecipeId]: enforced durably by a partial unique index created in
/// `MigrationStrategy.onCreate` (`entries_saved_source_unique`), on top of
/// the transactional check-then-insert in `DriftCollectionRepository`.
@TableIndex(name: 'entries_source_recipe_id', columns: {#sourceRecipeId})
class Entries extends Table {
  TextColumn get id => text()();
  TextColumn get kind => text().map(const CollectionEntryKindConverter())();
  TextColumn get sourceRecipeId => text()();
  TextColumn get sourceJson => text()();
  TextColumn get variationJson => text().nullable()();
  BoolColumn get hasPhoto => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

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

@DriftDatabase(tables: [Entries, Photos])
final class CollectionDatabase extends _$CollectionDatabase {
  /// Tests pass an in-memory or temp-file executor; the app passes the
  /// platform-appropriate connection from `openCollectionConnection`.
  CollectionDatabase(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      // A partial unique index: only `saved` entries are constrained to one
      // per source recipe, so variations never collide with each other or
      // with a saved entry for the same source.
      await customStatement(
        'CREATE UNIQUE INDEX entries_saved_source_unique '
        "ON entries (source_recipe_id) WHERE kind = 'saved';",
      );
    },
  );
}
