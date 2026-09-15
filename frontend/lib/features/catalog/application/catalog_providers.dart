import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../discovery/domain/recipe.dart';
import '../data/catalog_connection.dart';
import '../data/catalog_database.dart';
import '../data/catalog_repository.dart';
import '../data/catalog_snapshot_client.dart';
import '../domain/catalog_search_index.dart';
import '../domain/coverage_report.dart';

/// Injectable clock for deterministic update-controller behavior. Shared
/// with the discovery layer's own `nowProvider` would create a cross-feature
/// dependency for no benefit; this one is catalog-scoped.
final catalogNowProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// The application-scoped catalog database, opened through the documented
/// cross-platform connection. Tests override this provider with an
/// in-memory or temp-file backed database.
final catalogDatabaseProvider = Provider<CatalogDatabase>((ref) {
  final database = CatalogDatabase(openCatalogConnection());
  ref.onDispose(database.close);
  return database;
});

final catalogRepositoryProvider = Provider<CatalogRepository>((ref) {
  return CatalogRepository(
    database: ref.watch(catalogDatabaseProvider),
    now: ref.watch(catalogNowProvider),
  );
});

/// The application-scoped shared-catalog snapshot client. Tests override
/// this with an injected client so no test touches the network.
final catalogSnapshotClientProvider = Provider<CatalogSnapshotClient>((ref) {
  final client = CatalogSnapshotClient(now: ref.watch(catalogNowProvider));
  ref.onDispose(client.close);
  return client;
});

/// Where the update controller's fetches come from: the snapshot client's
/// `fetch` method, wrapped as a function so tests can override it with a
/// fake straight from a `Map<String, List<Recipe>>`-style fixture builder —
/// no test constructs a real `CatalogSnapshotClient` or touches the network.
typedef CatalogSnapshotFetcher =
    Future<CatalogSnapshotFetch> Function({String? ifNoneMatchVersion});

final catalogSnapshotFetcherProvider = Provider<CatalogSnapshotFetcher>((ref) {
  return ref.watch(catalogSnapshotClientProvider).fetch;
});

/// The stored coverage snapshot. `CatalogUpdateController` invalidates this
/// whenever it applies a new snapshot, so consumers always see fresh counts.
final catalogCoverageProvider = FutureProvider<CoverageReport>(
  (ref) => ref.watch(catalogRepositoryProvider).coverage(),
  retry: (retryCount, error) => null,
);

/// Every locally stored recipe, decoded once. `catalogSearchIndexProvider`
/// and `catalogRecipesByIdProvider` both build from this single decode
/// (Riverpod caches a `FutureProvider`'s value across watchers) instead of
/// each calling `CatalogRepository.allRecipes()` — and therefore
/// re-decoding every recipe's source JSON — on its own (finding #20).
final catalogRecipesProvider = FutureProvider<List<Recipe>>(
  (ref) => ref.watch(catalogRepositoryProvider).allRecipes(),
  retry: (retryCount, error) => null,
);

/// The same recipes as [catalogRecipesProvider], keyed by provider id — what
/// a search result list needs to resolve matched ids into full records
/// without decoding the catalog again per query.
final catalogRecipesByIdProvider = FutureProvider<Map<String, Recipe>>((
  ref,
) async {
  final recipes = await ref.watch(catalogRecipesProvider.future);
  return {for (final recipe in recipes) recipe.id: recipe};
}, retry: (retryCount, error) => null);

/// The ranked search index over every locally stored recipe and ingredient
/// identity. `CatalogUpdateController` invalidates this directly whenever it
/// applies a new snapshot, so suggestions and local results stay in step
/// with the on-device catalog — including on a cold deep link that never
/// visits a screen which used to "arm" that invalidation (docs/M11.md,
/// independent review finding #3).
final catalogSearchIndexProvider = FutureProvider<CatalogSearchIndex>((
  ref,
) async {
  final recipes = await ref.watch(catalogRecipesProvider.future);
  return CatalogSearchIndex.fromRecipes(recipes);
}, retry: (retryCount, error) => null);
