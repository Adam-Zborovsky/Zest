import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/catalog_connection.dart';
import '../data/catalog_database.dart';
import '../data/catalog_repository.dart';
import '../data/catalog_snapshot_client.dart';
import '../domain/catalog_search_index.dart';
import '../domain/coverage_report.dart';
import 'catalog_update_controller.dart';
import '../domain/catalog_update_state.dart';

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

/// The ranked search index over every locally stored recipe and ingredient
/// identity. `catalogFreshnessProvider` invalidates this whenever the update
/// controller applies a new snapshot, so suggestions and local results stay
/// in step with the on-device catalog.
final catalogSearchIndexProvider = FutureProvider<CatalogSearchIndex>((
  ref,
) async {
  final recipes = await ref.watch(catalogRepositoryProvider).allRecipes();
  return CatalogSearchIndex.fromRecipes(recipes);
}, retry: (retryCount, error) => null);

/// Keeps [catalogSearchIndexProvider] fresh as the update controller applies
/// new snapshots. Every surface that suggests from the index (Discover,
/// constellation, the home-bar picker, and the variation editor) watches
/// this provider once to arm the listener; it is not `autoDispose`, so the
/// index stays correct even for a surface visited after another one armed
/// it.
final catalogSearchIndexFreshnessProvider = Provider<void>((ref) {
  ref.listen(catalogUpdateControllerProvider, (previous, next) {
    final applied =
        next.status == CatalogUpdateStatus.updated &&
        previous?.status != next.status;
    if (!applied) return;
    ref.invalidate(catalogSearchIndexProvider);
  });
});
