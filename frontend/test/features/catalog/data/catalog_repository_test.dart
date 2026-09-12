import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zest/features/catalog/data/catalog_database.dart';
import 'package:zest/features/catalog/data/catalog_repository.dart';
import 'package:zest/features/catalog/domain/coverage_report.dart';
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

    await repository.upsertLetter('p', [original]);

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
    await repository.upsertLetter('b', [original]);
    expectSameRecipe((await repository.allRecipes()).single, original);
  });

  test('re-syncing a letter replaces its recipes without duplicates', () async {
    await repository.upsertLetter('a', [
      drink('700201', name: 'Aria One'),
      drink('700202', name: 'Aria Two'),
    ]);
    await repository.upsertLetter('a', [
      drink('700202', name: 'Aria Two, revised'),
      drink('700203', name: 'Aria Three'),
    ]);

    final stored = await repository.allRecipes();
    expect(stored.map((recipe) => recipe.id), unorderedEquals(['700202', '700203']));
    expect(stored.singleWhere((recipe) => recipe.id == '700202').name,
        'Aria Two, revised');
    expect(await repository.recipeCount(), 2);

    final statuses = await repository.letterStatuses();
    expect(statuses['a']!.recipeCount, 2);
    expect(statuses['a']!.completedAt, stamp);
  });

  test('re-syncing one letter leaves other letters untouched', () async {
    await repository.upsertLetter('a', [drink('700301', name: 'Alpha Fizz')]);
    await repository.upsertLetter('b', [drink('700302', name: 'Bravo Fizz')]);
    await repository.upsertLetter('a', [drink('700303', name: 'Alpha Two')]);

    final names = (await repository.allRecipes()).map((recipe) => recipe.name);
    expect(names, unorderedEquals(['Alpha Two', 'Bravo Fizz']));
  });

  test('ingredient usages are stored per normalized identity, distinct per recipe', () async {
    await repository.upsertLetter('m', [
      Recipe.fromJson(
        catalogRecipe(
          id: '700401',
          name: 'Muddled Test',
          ingredients: const [
            ('Mint Leaves', '6'),
            ('mint leaves', '3'),
            ('Ice Cubes', null),
            ('Invented Botanical Syrup', '½ oz'),
          ],
        ),
      ),
    ]);

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

  test('stale ingredient usages are removed when a letter is re-synced', () async {
    await repository.upsertLetter('t', [
      drink('700501', name: 'Old Test', ingredients: const [('Mint Leaves', '6')]),
    ]);
    expect((await repository.ingredientPrevalence()).keys, ['mint leaf']);

    await repository.upsertLetter('t', [
      drink('700501', name: 'New Test', ingredients: const [('Ice Cubes', '1')]),
    ]);

    final prevalence = await repository.ingredientPrevalence();
    expect(prevalence.keys, ['ice cube']);
  });

  test('prevalence counts distinct recipes across letters', () async {
    await repository.upsertLetter('c', [
      drink('700601', ingredients: const [('Ice Cubes', '1')]),
      drink('700602', ingredients: const [('Ice Cubes', '2'), ('Mint Leaves', '3')]),
    ]);
    await repository.upsertLetter('d', [
      drink('700603', ingredients: const [('Ice Cubes', '1')]),
    ]);

    final prevalence = await repository.ingredientPrevalence();
    expect(prevalence['ice cube'], 3);
    expect(prevalence['mint leaf'], 1);
  });

  test('a letter with zero recipes is a valid completed letter', () async {
    await repository.upsertLetter('q', []);

    expect(await repository.allRecipes(), isEmpty);
    expect(await repository.recipeCount(), 0);
    final statuses = await repository.letterStatuses();
    expect(statuses, containsPair('q', isNotNull));
    expect(statuses['q']!.recipeCount, 0);
    expect(statuses['q']!.completedAt, stamp);
    expect(await repository.pendingLetters(), isNot(contains('q')));
  });

  test('coverage reflects completed letters, not full-catalog claims', () async {
    expect((await repository.coverage()).lettersCompleted, 0);

    await repository.upsertLetter('a', [drink('700701')]);
    await repository.upsertLetter('b', [drink('700702'), drink('700703')]);

    final partial = await repository.coverage();
    expect(partial.lettersCompleted, 2);
    expect(partial.lettersTotal, 26);
    expect(partial.recipeCount, 3);
    expect(partial.isAtoZComplete, isFalse);
    expect(partial.lastCompletedAt, stamp);

    for (final letter in 'cdefghijklmnopqrstuvwxyz'.split('')) {
      await repository.upsertLetter(letter, []);
    }
    final complete = await repository.coverage();
    expect(complete.lettersCompleted, 26);
    expect(complete.isAtoZComplete, isTrue);
    // Bookkeeping only — the report documents that this is not a
    // full-catalog completeness claim.
    expect(CoverageReport.completenessGuidance, contains('not a claim'));
  });

  test('pending letters are the alphabet minus the synced ones, in order', () async {
    expect(await repository.pendingLetters(), 'abcdefghijklmnopqrstuvwxyz'.split(''));

    await repository.upsertLetter('c', [drink('700801')]);
    await repository.upsertLetter('a', [drink('700802')]);

    final pending = await repository.pendingLetters();
    expect(pending.first, 'b');
    expect(pending.any('ac'.contains), isFalse);
    expect(pending, hasLength(24));
  });

  test('letters outside a–z are rejected', () async {
    await expectLater(repository.upsertLetter('1', []), throwsArgumentError);
    await expectLater(repository.upsertLetter('ab', []), throwsArgumentError);
    await expectLater(repository.upsertLetter(' ', []), throwsArgumentError);
  });
}
