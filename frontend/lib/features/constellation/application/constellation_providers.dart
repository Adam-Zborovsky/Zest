import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../catalog/application/catalog_providers.dart';
import '../../catalog/application/catalog_update_controller.dart';
import '../../catalog/domain/catalog_update_state.dart';
import '../domain/ingredient_graph.dart';

/// The ingredient co-occurrence graph over the on-device shared catalog —
/// every stored recipe, bounded to the top 40 identities by prevalence.
/// Counts are the catalog snapshot's own prevalence; nothing here speaks for
/// full provider completeness.
final constellationGraphProvider = FutureProvider<IngredientGraph>((ref) async {
  final recipes = await ref.watch(catalogRepositoryProvider).allRecipes();
  return IngredientGraph.build(recipes);
});

/// The one place that keeps store-derived data fresh as the update
/// controller applies snapshots. Home watches this provider to arm the
/// listener: whenever `CatalogUpdateController` finishes applying a
/// snapshot (status becomes `updated` or `staged` — a staged snapshot is
/// still previewed via a coverage-independent diff, but the applied case is
/// what actually changed the store), the stored coverage and the graph are
/// invalidated so the next read rebuilds from the fresh store.
final catalogFreshnessProvider = Provider<void>((ref) {
  ref.listen(catalogUpdateControllerProvider, (previous, next) {
    final applied =
        next.status == CatalogUpdateStatus.updated &&
        previous?.status != next.status;
    if (!applied) return;
    ref.invalidate(catalogCoverageProvider);
    ref.invalidate(constellationGraphProvider);
  });
});
