import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../collection/sync/sync_contract.dart';
import 'home_bar_sync_contract.dart';

/// Integration overrides this with the shared account-sync coordinator.
final homeBarSyncProvider = Provider<HomeBarSync>(
  (ref) =>
      throw UnimplementedError('homeBarSyncProvider is overridden in main().'),
);

/// The home-bar child status; integration combines it with collection status
/// for the single profile-sheet status exposed by the app.
final homeBarSyncStatusProvider = StreamProvider<SyncStatus>(
  (ref) => ref.watch(homeBarSyncProvider).watchStatus(),
);
