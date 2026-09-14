import 'dart:convert';

import 'package:drift/drift.dart';

import '../../discovery/domain/recipe.dart';
import '../domain/catalog_snapshot.dart';
import '../domain/coverage_report.dart';
import 'catalog_database.dart';

/// On-device store for the shared catalog snapshot (M11). Unlike the earlier
/// letter-by-letter sync, the whole catalog is replaced in one transaction
/// whenever a new snapshot is applied.
final class CatalogRepository {
  CatalogRepository({required CatalogDatabase database, DateTime Function()? now})
    : _database = database,
      _now = now ?? DateTime.now;

  final CatalogDatabase _database;
  final DateTime Function() _now;

  /// Every stored recipe, rehydrated from its source JSON: what went in as a
  /// `Recipe` comes back out as an equal `Recipe`.
  Future<List<Recipe>> allRecipes() async {
    final rows = await (_database.select(_database.recipes)
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.name)]))
        .get();
    return List.unmodifiable(
      rows.map((row) => Recipe.fromJson(jsonDecode(row.sourceJson))),
    );
  }

  /// One stored recipe by provider id, or null when it is not in the
  /// on-device catalog (the caller falls back to `lookup.php`).
  Future<Recipe?> recipeById(String providerId) async {
    final row =
        await (_database.select(_database.recipes)
              ..where((tbl) => tbl.providerId.equals(providerId)))
            .getSingleOrNull();
    if (row == null) return null;
    return Recipe.fromJson(jsonDecode(row.sourceJson));
  }

  Future<int> recipeCount() async {
    final count = _database.recipes.providerId.count();
    final query = _database.selectOnly(_database.recipes)..addColumns([count]);
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }

  /// Distinct recipe count per normalized ingredient identity — the
  /// prevalence basis for the constellation graph.
  Future<Map<String, int>> ingredientPrevalence() async {
    final identity = _database.ingredientUsages.normalizedIngredient;
    final count = _database.ingredientUsages.recipeId.count(distinct: true);
    final query = _database.selectOnly(_database.ingredientUsages)
      ..addColumns([identity, count])
      ..groupBy([identity]);
    final rows = await query.get();
    return {
      for (final row in rows)
        row.read(identity)!: row.read(count) ?? 0,
    };
  }

  /// The last applied snapshot's bookkeeping, or null before any snapshot
  /// has ever been applied.
  Future<CatalogSnapshotInfo?> currentSnapshot() async {
    final row = await (_database.select(
      _database.catalogSnapshotTable,
    )..where((tbl) => tbl.id.equals(1))).getSingleOrNull();
    if (row == null) return null;
    return CatalogSnapshotInfo(
      version: row.version,
      publishedAt: row.publishedAt,
      recipeCount: row.recipeCount,
      appliedAt: row.appliedAt,
    );
  }

  Future<CoverageReport> coverage() async {
    final snapshot = await currentSnapshot();
    return CoverageReport(
      recipeCount: snapshot?.recipeCount ?? await recipeCount(),
      publishedAt: snapshot?.publishedAt,
      version: snapshot?.version,
    );
  }

  /// The diff applying [snapshot] would measure, without writing anything —
  /// used to preview a staged download (`docs/M11.md`: "do not swap data
  /// under the person"). [applySnapshot] recomputes and applies it for real.
  Future<CatalogDiff> previewDiff(CatalogSnapshot snapshot) async {
    final existing = await _database.select(_database.recipes).get();
    return _diffAgainst(existing, snapshot);
  }

  CatalogDiff _diffAgainst(List<RecipeRow> existing, CatalogSnapshot snapshot) {
    final existingById = {
      for (final row in existing) row.providerId: row.sourceJson,
    };
    var added = 0;
    var changed = 0;
    final addedNames = <String>[];
    final newIds = <String>{};
    for (final recipe in snapshot.drinks) {
      newIds.add(recipe.id);
      final sourceJson = jsonEncode(recipe.toJson());
      final previous = existingById[recipe.id];
      if (previous == null) {
        added++;
        addedNames.add(recipe.name);
      } else if (previous != sourceJson) {
        changed++;
      }
    }
    final removed = existingById.keys
        .where((id) => !newIds.contains(id))
        .length;
    return CatalogDiff(
      added: added,
      removed: removed,
      changed: changed,
      addedRecipeNames: List.unmodifiable(addedNames),
    );
  }

  /// Replaces the entire on-device catalog (recipes, ingredient usages, and
  /// the snapshot record) with [snapshot] in one transaction: either every
  /// table lands in its new state, or none of them change. Returns the diff
  /// this replacement measured, for the update notice's wording.
  ///
  /// "Changed" means the same provider id with a different stored source
  /// JSON; a recipe whose source JSON is byte-identical to what was already
  /// stored counts as neither added nor changed.
  Future<CatalogDiff> applySnapshot(CatalogSnapshot snapshot) async {
    final stamp = _now();
    return _database.transaction(() async {
      final existing = await _database.select(_database.recipes).get();
      final diff = _diffAgainst(existing, snapshot);

      await _database.delete(_database.ingredientUsages).go();
      await _database.delete(_database.recipes).go();

      if (snapshot.drinks.isNotEmpty) {
        await _database.batch((batch) {
          batch.insertAll(_database.recipes, [
            for (final recipe in snapshot.drinks)
              RecipesCompanion.insert(
                providerId: recipe.id,
                name: recipe.name,
                sourceJson: jsonEncode(recipe.toJson()),
                updatedAt: stamp,
              ),
          ]);
        });
        await _database.batch((batch) {
          batch.insertAll(_database.ingredientUsages, [
            for (final recipe in snapshot.drinks)
              for (final identity
                  in recipe.ingredients.map((i) => i.normalizedName).toSet())
                IngredientUsagesCompanion.insert(
                  recipeId: recipe.id,
                  normalizedIngredient: identity,
                ),
          ]);
        });
      }

      await _database
          .into(_database.catalogSnapshotTable)
          .insertOnConflictUpdate(
            CatalogSnapshotTableCompanion.insert(
              id: const Value(1),
              version: snapshot.version,
              publishedAt: snapshot.publishedAt,
              recipeCount: snapshot.recipeCount,
              appliedAt: stamp,
            ),
          );

      return diff;
    });
  }
}
