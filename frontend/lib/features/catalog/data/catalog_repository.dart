import 'dart:convert';

import 'package:drift/drift.dart';

import '../../discovery/domain/recipe.dart';
import '../domain/coverage_report.dart';
import 'catalog_database.dart';

/// On-device source-preserving recipe catalog. Writes are transactional per
/// letter: a letter's recipes, ingredient usages and completion row are
/// applied together or not at all, so re-syncing and interrupted syncs never
/// leave duplicates or half-applied letters behind.
final class CatalogRepository {
  CatalogRepository({required CatalogDatabase database, DateTime Function()? now})
    : _database = database,
      _now = now ?? DateTime.now;

  static const _alphabet = [
    'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm',
    'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z',
  ];

  final CatalogDatabase _database;
  final DateTime Function() _now;

  /// Transactionally replaces one letter's recipes, their ingredient usages
  /// and the letter's completion row. Stale rows for the same letter are
  /// deleted first, so re-syncing never duplicates anything; other letters'
  /// data is untouched. The returned recipes are exactly what was stored.
  Future<void> upsertLetter(String letter, List<Recipe> recipes) async {
    final normalized = _normalizeLetter(letter);
    final stamp = _now();
    await _database.transaction(() async {
      final stale = await (_database.select(_database.recipes)
            ..where((tbl) => tbl.firstLetter.equals(normalized)))
          .get();
      final staleIds = stale.map((row) => row.providerId).toList();
      if (staleIds.isNotEmpty) {
        await (_database.delete(_database.ingredientUsages)
              ..where((tbl) => tbl.recipeId.isIn(staleIds)))
            .go();
      }
      await (_database.delete(_database.recipes)
            ..where((tbl) => tbl.firstLetter.equals(normalized)))
          .go();
      if (recipes.isNotEmpty) {
        await _database.batch((batch) {
          batch.insertAllOnConflictUpdate(_database.recipes, [
            for (final recipe in recipes)
              RecipesCompanion.insert(
                providerId: recipe.id,
                name: recipe.name,
                firstLetter: normalized,
                sourceJson: jsonEncode(recipe.toJson()),
                updatedAt: stamp,
              ),
          ]);
          batch.insertAllOnConflictUpdate(_database.ingredientUsages, [
            for (final recipe in recipes)
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
          .into(_database.letterSync)
          .insertOnConflictUpdate(
            LetterSyncCompanion.insert(
              letter: normalized,
              completedAt: Value(stamp),
              recipeCount: recipes.length,
            ),
          );
    });
  }

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

  Future<int> recipeCount() async {
    final count = _database.recipes.providerId.count();
    final query = _database.selectOnly(_database.recipes)..addColumns([count]);
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }

  /// Distinct recipe count per normalized ingredient identity — the
  /// collection-prevalence basis for the constellation graph. Only identities
  /// with at least one loaded recipe appear.
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

  /// The stored completion record per synced letter, keyed by letter.
  /// Letters of the alphabet absent from the map are still pending.
  Future<Map<String, CatalogLetterStatus>> letterStatuses() async {
    final rows = await _database.select(_database.letterSync).get();
    return {
      for (final row in rows)
        row.letter: CatalogLetterStatus(
          letter: row.letter,
          completedAt: row.completedAt,
          recipeCount: row.recipeCount,
        ),
    };
  }

  /// The pending letters, in A–Z order — the sync engine's resume point.
  Future<List<String>> pendingLetters() async {
    final statuses = await letterStatuses();
    return [
      for (final letter in _alphabet)
        if (!statuses.containsKey(letter)) letter,
    ];
  }

  Future<CoverageReport> coverage() async {
    final statuses = await letterStatuses();
    final completed = statuses.values
        .where((status) => status.completedAt != null)
        .toList(growable: false);
    DateTime? last;
    for (final status in completed) {
      final stamp = status.completedAt;
      if (stamp != null && (last == null || stamp.isAfter(last))) last = stamp;
    }
    return CoverageReport(
      lettersCompleted: completed.length,
      recipeCount: await recipeCount(),
      lastCompletedAt: last,
    );
  }

  String _normalizeLetter(String letter) {
    final trimmed = letter.trim().toLowerCase();
    if (trimmed.length != 1 || !RegExp(r'^[a-z]$').hasMatch(trimmed)) {
      throw ArgumentError.value(letter, 'letter', 'Must be one ASCII letter.');
    }
    return trimmed;
  }
}
