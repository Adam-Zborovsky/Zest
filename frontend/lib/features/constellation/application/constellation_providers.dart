import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../catalog/application/catalog_providers.dart';
import '../domain/ingredient_graph.dart';

/// The ingredient co-occurrence graph over the on-device shared catalog —
/// every stored recipe, bounded to the top 40 identities by prevalence.
/// Counts are the catalog snapshot's own prevalence; nothing here speaks for
/// full provider completeness.
///
/// `CatalogUpdateController` invalidates this directly whenever it applies a
/// new snapshot (docs/M11.md, independent review finding #3), so it stays
/// fresh even on a cold deep link that never visits a screen that used to
/// "arm" that invalidation via a feature-local freshness provider.
final constellationGraphProvider = FutureProvider<IngredientGraph>((ref) async {
  final recipes = await ref.watch(catalogRepositoryProvider).allRecipes();
  return IngredientGraph.build(recipes);
});
