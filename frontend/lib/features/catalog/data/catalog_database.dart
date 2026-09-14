import 'package:drift/drift.dart';

part 'catalog_database.g.dart';

/// One loaded recipe. [providerId] is stored as text: the provider id is an
/// opaque numeric string by contract (1–20 digits, which can exceed int64),
/// and text keeps the source value byte-for-byte with no parse round-trip.
/// [sourceJson] keeps the full provider-shaped record via `Recipe.toJson` so
/// a stored recipe rehydrates as an equal `Recipe`.
///
/// Schema 2 (M11): the catalog is now a single shared, versioned snapshot
/// downloaded from the backend rather than a client-driven A–Z browse, so
/// `firstLetter` (which recorded browse provenance) is gone.
@DataClassName('RecipeRow')
class Recipes extends Table {
  TextColumn get providerId => text()();
  TextColumn get name => text()();
  TextColumn get sourceJson => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {providerId};
}

/// One row per distinct normalized ingredient identity per recipe, written
/// when a snapshot is applied. This is the catalog's prevalence base for the
/// constellation graph; identities come from `Ingredient.normalizedName`
/// (aliases applied).
@DataClassName('IngredientUsageRow')
class IngredientUsages extends Table {
  TextColumn get recipeId => text()();
  TextColumn get normalizedIngredient => text()();

  @override
  Set<Column> get primaryKey => {recipeId, normalizedIngredient};
}

/// Schema 2 (M11): a single row (id 1) describing the last catalog snapshot
/// applied to this device, replacing the letter-by-letter `letter_sync`
/// bookkeeping. Absence means no snapshot has ever been applied.
@DataClassName('CatalogSnapshotRow')
class CatalogSnapshotTable extends Table {
  @override
  String get tableName => 'catalog_snapshot';

  IntColumn get id => integer().withDefault(const Constant(1))();
  TextColumn get version => text()();
  DateTimeColumn get publishedAt => dateTime()();
  IntColumn get recipeCount => integer()();
  DateTimeColumn get appliedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Recipes, IngredientUsages, CatalogSnapshotTable])
final class CatalogDatabase extends _$CatalogDatabase {
  /// Tests pass an in-memory or temp-file executor; the app passes the
  /// platform-appropriate connection from `openCatalogConnection`.
  CatalogDatabase(super.executor);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        // The catalog is re-downloadable provider data, not personal data:
        // schema 1's letter-browse tables are dropped and recreated rather
        // than migrated in place. A fresh snapshot download repopulates
        // everything on next launch.
        await m.deleteTable('letter_sync');
        await m.deleteTable('ingredient_usages');
        await m.deleteTable('recipes');
        await m.createTable(recipes);
        await m.createTable(ingredientUsages);
        await m.createTable(catalogSnapshotTable);
      }
    },
  );
}
