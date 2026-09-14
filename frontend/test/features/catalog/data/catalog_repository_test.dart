import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zest/features/catalog/data/catalog_database.dart';
import 'package:zest/features/catalog/data/catalog_repository.dart';
import 'package:zest/features/discovery/domain/recipe.dart';

import '../../../support/catalog_fixtures.dart';

void main() {
  late CatalogDatabase database;
  late CatalogRepository repository;

  final stamp = DateTime(2026, 9, 12, 9, 30);

  setUp(() {
    database = CatalogDatabase(
      // Documented drift test setup: in-memory native executor, with
      // synchronously-closed streams so tests finish cleanly.
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    repository = CatalogRepository(database: database, now: () => stamp);
  });

  tearDown(() => database.close());

  Recipe drink(
    String id, {
    String name = 'Testbench Tonic',
    String? thumbnailUrl,
    List<(String, String?)> ingredients = const [('Imaginary leaf syrup', '1 1/2 oz')],
  }) => Recipe.fromJson(
    catalogRecipe(id: id, name: name, thumbnailUrl: thumbnailUrl, ingredients: ingredients),
  );

  test('a stored recipe rehydrates as an equal Recipe (source round-trip)', () async {
    final original = Recipe.fromJson(
      catalogRecipe(
        id: '700111',
        name: 'Paper Garden',
        thumbnailUrl: 'https://example.invalid/thumb.png',
        ingredients: const [
          ('Mint Leaves', ' 1 1/2 tsp '),
          ('Invented Botanical Syrup', '½ oz'),
          ('Test garnish', 'to taste'),
          ('Test water', null),
        ],
      ),
    );

    await repository.applySnapshot(catalogSnapshotFixture(drinks: [original]));

    final stored = await repository.allRecipes();
    expect(stored, hasLength(1));
    expectSameRecipe(stored.single, original);
  });

  test('recipes keep null metadata as null', () async {
    final original = Recipe.fromJson(
      catalogRecipe(
        id: '700112',
        name: 'Bare Bones Fizz',
        thumbnailUrl: null,
        instructions: null,
      ),
    );
    await repository.applySnapshot(catalogSnapshotFixture(drinks: [original]));
    expectSameRecipe((await repository.allRecipes()).single, original);
  });

  test('applying a new snapshot fully replaces the previous one', () async {
    await repository.applySnapshot(
      catalogSnapshotFixture(
        version: fakeCatalogVersion('one'),
        drinks: [drink('700201', name: 'Aria One'), drink('700202', name: 'Aria Two')],
      ),
    );
    await repository.applySnapshot(
      catalogSnapshotFixture(
        version: fakeCatalogVersion('two'),
        drinks: [drink('700202', name: 'Aria Two, revised'), drink('700203', name: 'Aria Three')],
      ),
    );

    final stored = await repository.allRecipes();
    expect(stored.map((recipe) => recipe.id), unorderedEquals(['700202', '700203']));
    expect(stored.singleWhere((recipe) => recipe.id == '700202').name,
        'Aria Two, revised');
    expect(await repository.recipeCount(), 2);
  });

  test('applySnapshot reports added, removed, and changed counts', () async {
    await repository.applySnapshot(
      catalogSnapshotFixture(
        version: fakeCatalogVersion('base'),
        drinks: [drink('700301', name: 'Alpha'), drink('700302', name: 'Bravo')],
      ),
    );

    final diff = await repository.applySnapshot(
      catalogSnapshotFixture(
        version: fakeCatalogVersion('next'),
        drinks: [
          drink('700301', name: 'Alpha, revised'), // changed
          drink('700303', name: 'Charlie'), // added
          // 700302 removed
        ],
      ),
    );

    expect(diff.added, 1);
    expect(diff.removed, 1);
    expect(diff.changed, 1);
    expect(diff.addedRecipeNames, ['Charlie']);
    expect(diff.isNoOp, isFalse);
  });

  test('applying an identical snapshot again is a no-op diff', () async {
    final snapshot = catalogSnapshotFixture(
      version: fakeCatalogVersion('same'),
      drinks: [drink('700401', name: 'Same Same')],
    );
    await repository.applySnapshot(snapshot);
    final diff = await repository.applySnapshot(snapshot);

    expect(diff.isNoOp, isTrue);
    expect(diff.added, 0);
    expect(diff.removed, 0);
    expect(diff.changed, 0);
  });

  test('previewDiff measures without writing anything', () async {
    await repository.applySnapshot(
      catalogSnapshotFixture(
        version: fakeCatalogVersion('base'),
        drinks: [drink('700501', name: 'Original')],
      ),
    );

    final preview = await repository.previewDiff(
      catalogSnapshotFixture(
        version: fakeCatalogVersion('preview'),
        drinks: [drink('700501', name: 'Changed'), drink('700502', name: 'New')],
      ),
    );

    expect(preview.added, 1);
    expect(preview.changed, 1);
    expect(preview.addedRecipeNames, ['New']);
    // Nothing was actually written.
    expect(await repository.recipeCount(), 1);
    expect((await repository.allRecipes()).single.name, 'Original');
    expect((await repository.currentSnapshot())!.version, fakeCatalogVersion('base'));
  });

  test('ingredient usages are stored per normalized identity, distinct per recipe', () async {
    await repository.applySnapshot(
      catalogSnapshotFixture(
        drinks: [
          Recipe.fromJson(
            catalogRecipe(
              id: '700601',
              name: 'Muddled Test',
              ingredients: const [
                ('Mint Leaves', '6'),
                ('mint leaves', '3'),
                ('Ice Cubes', null),
                ('Invented Botanical Syrup', '½ oz'),
              ],
            ),
          ),
        ],
      ),
    );

    final prevalence = await repository.ingredientPrevalence();
    // Aliases apply ("mint leaves" → "mint leaf"), duplicates collapse, and
    // the raw names stay untouched in the source JSON.
    expect(prevalence.keys,
        unorderedEquals(['mint leaf', 'ice cube', 'invented botanical syrup']));
    expect(prevalence['mint leaf'], 1);

    final stored = (await repository.allRecipes()).single;
    expect(stored.ingredients.map((ingredient) => ingredient.rawName),
        ['Mint Leaves', 'mint leaves', 'Ice Cubes', 'Invented Botanical Syrup']);
  });

  test('prevalence counts distinct recipes across the whole snapshot', () async {
    await repository.applySnapshot(
      catalogSnapshotFixture(
        drinks: [
          drink('700701', ingredients: const [('Ice Cubes', '1')]),
          drink('700702', ingredients: const [('Ice Cubes', '2'), ('Mint Leaves', '3')]),
          drink('700703', ingredients: const [('Ice Cubes', '1')]),
        ],
      ),
    );

    final prevalence = await repository.ingredientPrevalence();
    expect(prevalence['ice cube'], 3);
    expect(prevalence['mint leaf'], 1);
  });

  test('recipeById finds a stored recipe and returns null otherwise', () async {
    await repository.applySnapshot(
      catalogSnapshotFixture(drinks: [drink('700801', name: 'Findable')]),
    );

    expect((await repository.recipeById('700801'))!.name, 'Findable');
    expect(await repository.recipeById('999999'), isNull);
  });

  test('currentSnapshot is null before any snapshot has been applied', () async {
    expect(await repository.currentSnapshot(), isNull);
    expect((await repository.coverage()).hasSnapshot, isFalse);
    expect((await repository.coverage()).recipeCount, 0);
  });

  test('currentSnapshot and coverage reflect the last applied snapshot', () async {
    final publishedAt = DateTime.utc(2026, 9, 10);
    await repository.applySnapshot(
      catalogSnapshotFixture(
        version: fakeCatalogVersion('applied'),
        publishedAt: publishedAt,
        drinks: [drink('700901'), drink('700902')],
      ),
    );

    final snapshot = await repository.currentSnapshot();
    expect(snapshot!.version, fakeCatalogVersion('applied'));
    // Drift's dateTime() column returns a local-flavored DateTime on the
    // native backend (see collection_database.dart's UtcMillisConverter
    // note); compare by instant, not by the UTC/local flag.
    expect(snapshot.publishedAt.isAtSameMomentAs(publishedAt), isTrue);
    expect(snapshot.recipeCount, 2);
    expect(snapshot.appliedAt.isAtSameMomentAs(stamp), isTrue);

    final coverage = await repository.coverage();
    expect(coverage.hasSnapshot, isTrue);
    expect(coverage.recipeCount, 2);
    expect(coverage.publishedAt!.isAtSameMomentAs(publishedAt), isTrue);
    expect(coverage.version, fakeCatalogVersion('applied'));
  });

  test('applySnapshot rejects duplicate provider ids in the same snapshot', () async {
    // Guards against a caller bypassing the snapshot client's own duplicate
    // check: the primary key on `recipes` would otherwise silently keep
    // only one of two conflicting rows.
    final duplicate = catalogSnapshotFixture(
      drinks: [drink('701001', name: 'First'), drink('701001', name: 'Second')],
    );
    await expectLater(
      repository.applySnapshot(duplicate),
      throwsA(anything),
    );
  });

  group('transactionality', () {
    test('a failure mid-apply leaves the prior catalog untouched', () async {
      final poisoned = CatalogDatabase(
        DatabaseConnection(
          NativeDatabase.memory(),
          closeStreamsSynchronously: true,
        ).interceptWith(_PoisonIngredientBatch()),
      );
      addTearDown(poisoned.close);
      final poisonedRepository = CatalogRepository(
        database: poisoned,
        now: () => stamp,
      );

      await poisonedRepository.applySnapshot(
        catalogSnapshotFixture(
          version: fakeCatalogVersion('good'),
          drinks: [drink('701101', name: 'Kept Recipe')],
        ),
      );
      expect(await poisonedRepository.recipeCount(), 1);

      await expectLater(
        poisonedRepository.applySnapshot(
          catalogSnapshotFixture(
            version: fakeCatalogVersion('poisoned'),
            drinks: [drink('701102', name: 'Never Lands')],
          ),
        ),
        throwsA(isA<StateError>()),
      );

      // The whole transaction rolled back: recipes, usages and the snapshot
      // row are all exactly as they were before the failed apply.
      final stored = await poisonedRepository.allRecipes();
      expect(stored, hasLength(1));
      expect(stored.single.name, 'Kept Recipe');
      expect((await poisonedRepository.currentSnapshot())!.version,
          fakeCatalogVersion('good'));
    });
  });
}

/// Lets the first `applySnapshot` (the test's initial "good" state) land
/// normally, then throws on the *next* ingredient-usages batch — after the
/// recipes table has already been replaced — simulating a mid-transaction
/// failure so the rollback guarantee can be verified end to end.
final class _PoisonIngredientBatch extends QueryInterceptor {
  bool _allowedOne = false;

  @override
  Future<void> runBatched(
    QueryExecutor executor,
    BatchedStatements statements,
  ) async {
    final targetsUsages = statements.statements.any(
      (sql) => sql.contains('ingredient_usages'),
    );
    if (targetsUsages) {
      if (!_allowedOne) {
        _allowedOne = true;
      } else {
        throw StateError('simulated failure while writing ingredient usages');
      }
    }
    return executor.runBatched(statements);
  }
}
