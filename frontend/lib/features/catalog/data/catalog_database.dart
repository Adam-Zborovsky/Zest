import 'package:drift/drift.dart';

part 'catalog_database.g.dart';

/// How far a letter's A–Z browse has come. Rows only exist for letters whose
/// browse completed: a letter with no row is still pending, so the sync engine
/// resumes from the absent letters without seeding 26 rows at first open.
enum LetterSyncStatus { synced }

class LetterSyncStatusConverter extends TypeConverter<LetterSyncStatus, String> {
  const LetterSyncStatusConverter();

  @override
  LetterSyncStatus fromSql(String fromDb) => LetterSyncStatus.values.byName(fromDb);

  @override
  String toSql(LetterSyncStatus value) => value.name;
}

/// One loaded recipe. [providerId] is stored as text: the provider id is an
/// opaque numeric string by contract (1–20 digits, which can exceed int64),
/// and text keeps the source value byte-for-byte with no parse round-trip.
/// [sourceJson] keeps the full provider-shaped record via `Recipe.toJson` so
/// a stored recipe rehydrates as an equal `Recipe`.
@DataClassName('RecipeRow')
@TableIndex(name: 'recipes_first_letter', columns: {#firstLetter})
class Recipes extends Table {
  TextColumn get providerId => text()();
  TextColumn get name => text()();
  /// The browse that last wrote this row — never a letter derived from the
  /// recipe name. A recipe returned by two different letter browses is
  /// last-writer-wins: [CatalogRepository.upsertLetter] replaces the row
  /// (and its ingredient usages, which are primary-keyed on
  /// (recipeId, identity) and so cannot duplicate) with the newest browse's
  /// copy and stamps this column with that letter.
  TextColumn get firstLetter => text().withLength(min: 1, max: 1)();
  TextColumn get sourceJson => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {providerId};
}

/// One row per distinct normalized ingredient identity per recipe, written at
/// upsert time. This is the catalog's prevalence base for the M5 constellation
/// graph; identities come from `Ingredient.normalizedName` (aliases applied).
@DataClassName('IngredientUsageRow')
class IngredientUsages extends Table {
  TextColumn get recipeId => text()();
  TextColumn get normalizedIngredient => text()();

  @override
  Set<Column> get primaryKey => {recipeId, normalizedIngredient};
}

/// Completion bookkeeping for one A–Z browse letter. A row exists only after
/// that letter's browse was fully applied (transactional upsert), so a fresh
/// app session resumes from the missing rows.
@DataClassName('LetterSyncRow')
class LetterSync extends Table {
  TextColumn get letter => text().withLength(min: 1, max: 1)();
  DateTimeColumn get completedAt => dateTime().nullable()();
  IntColumn get recipeCount => integer()();

  @override
  Set<Column> get primaryKey => {letter};
}

@DriftDatabase(tables: [Recipes, IngredientUsages, LetterSync])
final class CatalogDatabase extends _$CatalogDatabase {
  /// Tests pass an in-memory or temp-file executor; the app passes the
  /// platform-appropriate connection from `openCatalogConnection`.
  CatalogDatabase(super.executor);

  @override
  int get schemaVersion => 1;
}
