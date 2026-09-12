import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../discovery/application/discovery_providers.dart';
import '../data/collection_connection.dart';
import '../data/collection_database.dart';
import '../data/drift_collection_repository.dart';

/// The application-scoped collection database, opened through the
/// documented cross-platform connection. Tests override this provider with
/// an in-memory or temp-file backed database.
final collectionDatabaseProvider = Provider<CollectionDatabase>((ref) {
  final database = CollectionDatabase(openCollectionConnection());
  ref.onDispose(database.close);
  return database;
});

/// The drift-backed collection repository. Integration points
/// `collectionRepositoryProvider` at this provider.
final driftCollectionRepositoryProvider = Provider<DriftCollectionRepository>((
  ref,
) {
  return DriftCollectionRepository(
    database: ref.watch(collectionDatabaseProvider),
    now: ref.watch(nowProvider),
  );
});
