import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/catalog_connection.dart';
import '../data/catalog_database.dart';
import '../data/catalog_repository.dart';
import '../data/catalog_snapshot_client.dart';
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
