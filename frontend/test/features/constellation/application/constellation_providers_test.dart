import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zest/core/network/cocktail_api_exception.dart';
import 'package:zest/features/catalog/application/catalog_providers.dart';
import 'package:zest/features/catalog/data/catalog_database.dart';
import 'package:zest/features/catalog/domain/sync_state.dart';
import 'package:zest/features/constellation/application/constellation_providers.dart';
import 'package:zest/features/constellation/domain/ingredient_graph.dart';
import 'package:zest/features/discovery/domain/recipe.dart';

import '../../../support/catalog_fixtures.dart';
import '../../../support/catalog_wiring.dart';

/// Lets pending provider re-reads (drift futures) land before asserting.
Future<void> settleReads() =>
    Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  final stamp = DateTime(2026, 9, 12, 10);

  ({
    ProviderContainer container,
    CatalogDatabase database,
    FakeCatalogLetterSource source,
  }) setup({
    Map<String, List<Recipe>> letters = const {},
    Map<String, Object> failures = const {},
  }) {
    final database = openInMemoryCatalog();
    final source = FakeCatalogLetterSource(
      letters: letters,
      failures: failures,
    );
    final container = ProviderContainer(
      overrides: [
        ...catalogTestOverrides(
          database: database,
          source: source,
          now: () => stamp,
        ),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(database.close);
    return (container: container, database: database, source: source);
  }

  test('the graph provider builds over the stored collection', () async {
    final test = setup(
      letters: {
        'a': catalogLetterRecipes('a'),
        'b': catalogLetterRecipes('b'),
      },
    );
    final repository = test.container.read(catalogRepositoryProvider);
    await repository.upsertLetter('a', catalogLetterRecipes('a'));
    await repository.upsertLetter('b', catalogLetterRecipes('b'));

    final graph = await test.container.read(constellationGraphProvider.future);

    // The fixtures share three identities across both letters.
    expect(graph.recipeCount, 2);
    expect(graph.node('mint leaf')!.prevalence, 2);
    expect(graph.node('ice cube')!.prevalence, 2);
    expect(
      graph.edge('mint leaf', 'ice cube')!.sharedRecipeIds,
      hasLength(2),
    );
  });

  test('an empty store yields the empty graph', () async {
    final test = setup();
    final graph = await test.container.read(constellationGraphProvider.future);
    expect(graph.isEmpty, isTrue);
    expect(graph.recipeCount, 0);
  });

  test('coverage and the graph refresh when a letter applies during sync',
      () async {
    final test = setup(letters: everyCatalogLetter());
    final container = test.container;
    final notifier = container.read(catalogSyncProvider.notifier);
    // Arm the freshness wiring the way home does.
    container.read(catalogFreshnessProvider);

    final coverageValues = <int>[];
    container.listen(catalogCoverageProvider, (_, next) {
      final value = next.value;
      if (value != null) coverageValues.add(value.recipeCount);
    });
    final graphSizes = <int>[];
    container.listen(constellationGraphProvider, (_, next) {
      final value = next.value;
      if (value != null) graphSizes.add(value.nodeCount);
    });

    await notifier.start();
    await settleReads();

    // a–z applied: coverage was re-read as the store grew. The graph is
    // coalesced (see catalogFreshnessProvider): skipped while the run syncs
    // and rebuilt once when the run settles into finished.
    expect(
      container.read(catalogSyncProvider).status,
      CatalogSyncStatus.finished,
    );
    expect(coverageValues.first, 0);
    expect(coverageValues.last, 26);
    // Every intermediate letter count was observed, not just the endpoints.
    expect(coverageValues.toSet(), containsAll([1, 7, 13, 25]));
    expect(graphSizes, isNotEmpty);
    // The fixture recipes share three identities, so the bounded graph has
    // three nodes however many letters load.
    expect(graphSizes.last, 3);

    final graph = await container.read(constellationGraphProvider.future);
    expect(graph.recipeCount, 26);
    expect(graph.node('mint leaf')!.prevalence, 26);
  });

  test('the graph rebuild is coalesced: skipped per letter, run once when '
      'the sync settles', () async {
    final database = openInMemoryCatalog();
    final source = FakeCatalogLetterSource(letters: everyCatalogLetter());
    var graphBuilds = 0;
    final container = ProviderContainer(
      overrides: [
        ...catalogTestOverrides(
          database: database,
          source: source,
          now: () => stamp,
        ),
        constellationGraphProvider.overrideWith((ref) async {
          graphBuilds++;
          final recipes =
              await ref.watch(catalogRepositoryProvider).allRecipes();
          return IngredientGraph.build(recipes);
        }),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(database.close);
    // Arm the freshness wiring the way home does.
    container.read(catalogFreshnessProvider);
    // Home actively watches the graph; an active listener keeps the
    // provider out of Riverpod's paused state, so invalidations schedule
    // real rebuilds exactly as they do in the app.
    container.listen(constellationGraphProvider, (_, __) {});

    // First read materializes the graph over the empty store.
    final initial = await container.read(constellationGraphProvider.future);
    expect(initial.isEmpty, isTrue);
    expect(graphBuilds, 1);

    await container.read(catalogSyncProvider.notifier).start();
    await settleReads();

    expect(
      container.read(catalogSyncProvider).status,
      CatalogSyncStatus.finished,
    );
    // Per-letter progress emissions never rebuilt the graph (a full catalog
    // decode plus layout each); the settle into finished did — one rebuild
    // for the whole 26-letter run.
    expect(graphBuilds, 2);
    final settled = await container.read(constellationGraphProvider.future);
    expect(settled.recipeCount, 26);
    expect(settled.node('mint leaf')!.prevalence, 26);
  });

  test('a pause refreshes coverage even though no letter applied', () async {
    final test = setup(
      letters: everyCatalogLetter(),
      failures: {
        'c': CocktailApiException(
          CocktailApiErrorKind.rateLimited,
          statusCode: 429,
          retryAfter: const Duration(seconds: 7),
          retryAt: stamp.add(const Duration(seconds: 7)),
        ),
      },
    );
    final container = test.container;

    await container.read(catalogSyncProvider.notifier).start();

    expect(
      container.read(catalogSyncProvider).status,
      CatalogSyncStatus.pausedCooldown,
    );
    // The status change alone refreshed the stored coverage: a and b are
    // visible without waiting for any further letter.
    final coverage = await container.read(catalogCoverageProvider.future);
    expect(coverage.lettersCompleted, 2);
    expect(coverage.recipeCount, 2);
  });

  test('a no-change state emission does not re-trigger a refresh', () async {
    final test = setup(letters: everyCatalogLetter());
    final container = test.container;
    final notifier = container.read(catalogSyncProvider.notifier);
    container.read(catalogFreshnessProvider);

    final dataReads = <int>[];
    container.listen(catalogCoverageProvider, (_, next) {
      final value = next.value;
      if (value != null) dataReads.add(value.recipeCount);
    });

    await notifier.start();
    expect(
      container.read(catalogSyncProvider).status,
      CatalogSyncStatus.finished,
    );
    await settleReads();

    // A stop that actually changes status (finished → idle) refreshes.
    notifier.stop();
    await settleReads();
    final baseline = dataReads.length;

    // A second stop is a no-change emission: idle → idle with identical
    // counts, so no refresh cycle runs at all.
    notifier.stop();
    await settleReads();
    expect(dataReads.length, baseline);
  });
}
