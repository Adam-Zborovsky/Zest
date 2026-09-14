import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../catalog/application/catalog_providers.dart';
import '../../catalog/domain/coverage_report.dart';
import '../../discovery/domain/recipe.dart';
import '../data/home_bar_repository.dart';
import '../domain/home_bar_item.dart';
import '../sync/home_bar_sync_providers.dart';
import 'home_bar_storage_providers.dart';
import 'sync_triggering_home_bar_repository.dart';

/// A selectable catalog identity and its deterministic human spelling.
final class HomeBarCatalogIngredient {
  const HomeBarCatalogIngredient({
    required this.ingredientId,
    required this.displayName,
  });

  final String ingredientId;
  final String displayName;
}

/// UI mutations go through this sync-triggering repository. Tests can
/// override it with an in-memory repository without constructing a syncer.
final homeBarRepositoryProvider = Provider<HomeBarRepository>((ref) {
  return SyncTriggeringHomeBarRepository(
    ref.watch(driftHomeBarRepositoryProvider),
    onWrite: () => ref.read(homeBarSyncProvider).scheduleAfterLocalWrite(),
  );
});

final homeBarItemsProvider = StreamProvider<List<HomeBarItem>>(
  (ref) => ref.watch(homeBarRepositoryProvider).watchItems(),
  retry: (retryCount, error) => null,
);

/// Normalized stocked identities ready for the existing M4 matcher.
final stockedIngredientIdsProvider = StreamProvider<Set<String>>(
  (ref) => ref
      .watch(homeBarRepositoryProvider)
      .watchItems()
      .map(
        (items) => Set.unmodifiable({
          for (final item in items)
            if (item.location == HomeBarLocation.stocked) item.ingredientId,
        }),
      ),
  retry: (retryCount, error) => null,
);

final homeBarCatalogRecipesProvider = FutureProvider<List<Recipe>>(
  (ref) => ref.watch(catalogRepositoryProvider).allRecipes(),
  retry: (retryCount, error) => null,
);

final homeBarCatalogCoverageProvider = FutureProvider<CoverageReport>(
  (ref) => ref.watch(catalogRepositoryProvider).coverage(),
  retry: (retryCount, error) => null,
);

/// Catalog options use the first raw recipe spelling encountered in the
/// catalog's deterministic recipe/ingredient order for each normalized id.
final homeBarCatalogIngredientOptionsProvider =
    FutureProvider<List<HomeBarCatalogIngredient>>((ref) async {
      final recipes = await ref.watch(homeBarCatalogRecipesProvider.future);
      final choices = <String, HomeBarCatalogIngredient>{};
      for (final recipe in recipes) {
        for (final ingredient in recipe.ingredients) {
          choices.putIfAbsent(
            ingredient.normalizedName,
            () => HomeBarCatalogIngredient(
              ingredientId: ingredient.normalizedName,
              displayName: ingredient.name,
            ),
          );
        }
      }
      final result = choices.values.toList()
        ..sort((a, b) {
          final display = a.displayName.toLowerCase().compareTo(
            b.displayName.toLowerCase(),
          );
          return display != 0
              ? display
              : a.ingredientId.compareTo(b.ingredientId);
        });
      return List.unmodifiable(result);
    }, retry: (retryCount, error) => null);
