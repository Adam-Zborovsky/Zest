import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../collection/application/collection_storage_providers.dart';
import '../../discovery/application/discovery_providers.dart';
import '../data/drift_home_bar_repository.dart';

/// Raw Drift store used by sync and wrapped UI mutations. The integrator
/// passes this exact object to `HomeBarSyncEngine`.
final driftHomeBarRepositoryProvider = Provider<DriftHomeBarRepository>(
  (ref) => DriftHomeBarRepository(
    database: ref.watch(collectionDatabaseProvider),
    now: ref.watch(nowProvider),
  ),
);
