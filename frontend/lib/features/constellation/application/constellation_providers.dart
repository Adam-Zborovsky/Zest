import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../catalog/application/catalog_providers.dart';
import '../../catalog/domain/sync_state.dart';
import '../domain/ingredient_graph.dart';

/// The ingredient co-occurrence graph over the analyzed on-device collection
/// — every recipe the catalog has loaded, bounded to the top 40 identities by
/// prevalence. Counts are collection prevalence within the recipes loaded on
/// this device; nothing here speaks for the full provider catalog.
final constellationGraphProvider = FutureProvider<IngredientGraph>((ref) async {
  final recipes = await ref.watch(catalogRepositoryProvider).allRecipes();
  return IngredientGraph.build(recipes);
});

/// The one place that keeps store-derived data fresh as the sync engine
/// changes state. The catalog layer documents that consumers watching the
/// sync should invalidate the stored coverage when sync state changes; the
/// constellation graph reads the same store, so both refresh together.
///
/// Invalidation is coalesced: coverage (a cheap query) refreshes on every
/// data-changing emission, but the graph rebuild re-decodes the entire
/// stored catalog and computes a fresh layout, so it is skipped while the
/// run is syncing and runs once when the run settles into any other status
/// (finished, paused, or stopped). Pure "current letter" progress updates
/// carry no new data, so they never trigger a refresh at all. Home watches
/// this provider to arm the listener.
final catalogFreshnessProvider = Provider<void>((ref) {
  ref.listen(catalogSyncProvider, (previous, next) {
    final dataChanged =
        previous == null ||
        previous.status != next.status ||
        previous.lettersDone != next.lettersDone ||
        previous.recipesLoaded != next.recipesLoaded;
    if (!dataChanged) return;
    ref.invalidate(catalogCoverageProvider);
    if (next.status != CatalogSyncStatus.syncing) {
      ref.invalidate(constellationGraphProvider);
    }
  });
});
