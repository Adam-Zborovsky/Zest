import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zest/features/catalog/application/catalog_providers.dart';
import 'package:zest/features/catalog/application/catalog_update_controller.dart';
import 'package:zest/features/catalog/data/catalog_repository.dart';
import 'package:zest/features/catalog/data/catalog_snapshot_client.dart';
import 'package:zest/features/catalog/domain/catalog_search_index.dart';

import '../../../support/catalog_fixtures.dart';
import '../../../support/catalog_wiring.dart';

void main() {
  group('catalogSearchIndexProvider', () {
    test('builds from the on-device catalog', () async {
      final database = openInMemoryCatalog();
      addTearDown(database.close);
      final repository = CatalogRepository(database: database);
      await repository.applySnapshot(
        catalogSnapshotFixture(
          drinks: [catalogRecipeModel(id: '1', name: 'Old Fashioned')],
        ),
      );
      final container = ProviderContainer(
        overrides: [catalogRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final index = await container.read(catalogSearchIndexProvider.future);
      expect(
        index
            .suggest('old', kinds: const {CatalogSuggestionKind.recipe})
            .map((s) => s.label),
        ['Old Fashioned'],
      );
    });

    test(
      'rebuilds once the update controller applies a new snapshot',
      () async {
        final database = openInMemoryCatalog();
        addTearDown(database.close);
        final repository = CatalogRepository(database: database);
        final fetcher = FakeCatalogSnapshotFetcher();
        final container = ProviderContainer(
          overrides: [
            catalogRepositoryProvider.overrideWithValue(repository),
            catalogSnapshotFetcherProvider.overrideWithValue(fetcher.call),
          ],
        );
        addTearDown(container.dispose);
        // No arming needed: CatalogUpdateController invalidates the shared
        // decode directly once it applies (finding #3), which cascades to
        // the search index automatically.

        final before = await container.read(catalogSearchIndexProvider.future);
        expect(before.suggest('margarita'), isEmpty);

        fetcher.enqueueAvailable(
          CatalogSnapshotAvailable(
            catalogSnapshotFixture(
              drinks: [catalogRecipeModel(id: '1', name: 'Margarita')],
            ),
          ),
        );
        await container
            .read(catalogUpdateControllerProvider.notifier)
            .checkOnLaunch();

        final after = await container.read(catalogSearchIndexProvider.future);
        expect(
          after
              .suggest('margarita', kinds: const {CatalogSuggestionKind.recipe})
              .map((s) => s.label),
          ['Margarita'],
        );
      },
    );
  });
}
