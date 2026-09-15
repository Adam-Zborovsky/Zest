import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zest/features/catalog/application/catalog_providers.dart';
import 'package:zest/features/catalog/application/catalog_update_controller.dart';
import 'package:zest/features/catalog/data/catalog_database.dart';
import 'package:zest/features/catalog/domain/catalog_update_state.dart';
import 'package:zest/features/catalog/data/catalog_snapshot_client.dart';
import 'package:zest/features/constellation/application/constellation_providers.dart';

import '../../../support/catalog_fixtures.dart';
import '../../../support/catalog_wiring.dart';

void main() {
  final stamp = DateTime(2026, 9, 12, 10);

  ({
    ProviderContainer container,
    CatalogDatabase database,
    FakeCatalogSnapshotFetcher fetcher,
  }) setup() {
    final database = openInMemoryCatalog();
    final fetcher = FakeCatalogSnapshotFetcher();
    final container = ProviderContainer(
      overrides: [
        ...catalogTestOverrides(
          database: database,
          fetcher: fetcher,
          now: () => stamp,
        ),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(database.close);
    return (container: container, database: database, fetcher: fetcher);
  }

  test('the graph provider builds over the stored collection', () async {
    final test = setup();
    final repository = test.container.read(catalogRepositoryProvider);
    await repository.applySnapshot(
      catalogSnapshotFixture(
        drinks: [...catalogLetterRecipes('a'), ...catalogLetterRecipes('b')],
      ),
    );

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

  test('coverage and the graph refresh once an update applies', () async {
    final test = setup();
    final container = test.container;
    // No arming needed: CatalogUpdateController invalidates
    // catalogCoverageProvider/constellationGraphProvider directly once it
    // applies (finding #3) — no feature-local freshness provider to read.

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

    test.fetcher.enqueueAvailable(
      CatalogSnapshotAvailable(
        catalogSnapshotFixture(
          drinks: [
            for (final letter in 'abcdefghijklmnopqrstuvwxyz'.split(''))
              ...catalogLetterRecipes(letter),
          ],
        ),
      ),
    );
    await container.read(catalogUpdateControllerProvider.notifier).checkOnLaunch();
    // Let the coalesced invalidations settle.
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(
      container.read(catalogUpdateControllerProvider).status,
      CatalogUpdateStatus.updated,
    );
    expect(coverageValues, isNotEmpty);
    expect(coverageValues.last, 26);
    expect(graphSizes, isNotEmpty);
    // The fixture recipes share three identities, however many letters load.
    expect(graphSizes.last, 3);

    final graph = await container.read(constellationGraphProvider.future);
    expect(graph.recipeCount, 26);
    expect(graph.node('mint leaf')!.prevalence, 26);
  });

  test('a failed check does not refresh the graph or coverage', () async {
    final test = setup();
    final container = test.container;

    final graphRebuilds = <int>[];
    container.listen(constellationGraphProvider, (_, next) {
      if (next.hasValue) graphRebuilds.add(next.value!.nodeCount);
    });
    await container.read(constellationGraphProvider.future); // initial build

    test.fetcher.enqueueError(StateError('offline'));
    await container.read(catalogUpdateControllerProvider.notifier).checkOnLaunch();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(
      container.read(catalogUpdateControllerProvider).status,
      CatalogUpdateStatus.failed,
    );
    // Only the initial build happened — the failure triggered no refresh.
    expect(graphRebuilds, hasLength(1));
  });
}
