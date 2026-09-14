import 'dart:async';

import 'package:zest/features/collection/sync/sync_contract.dart';

/// A controllable [CollectionSync] for profile sheet tests: [emit] pushes a
/// new [SyncStatus] to every listener, and [syncNow] just counts calls
/// (optionally driven by [onSyncNow]) instead of running a real pass.
final class FakeCollectionSync implements CollectionSync {
  FakeCollectionSync({SyncStatus initial = const SyncStatus(SyncPhase.idle)})
    : _status = initial;

  SyncStatus _status;
  final _controller = StreamController<SyncStatus>.broadcast();

  int syncNowCalls = 0;

  /// When set, called (and awaited) from [syncNow] instead of doing nothing —
  /// lets a test simulate a pass that ends by calling [emit].
  Future<void> Function()? onSyncNow;

  @override
  SyncStatus get status => _status;

  @override
  Stream<SyncStatus> watchStatus() async* {
    yield _status;
    yield* _controller.stream;
  }

  void emit(SyncStatus status) {
    _status = status;
    if (!_controller.isClosed) _controller.add(status);
  }

  @override
  Future<void> syncNow() async {
    syncNowCalls++;
    final callback = onSyncNow;
    if (callback != null) await callback();
  }

  int scheduleAfterLocalWriteCalls = 0;
  int pushBeforeSignOutCalls = 0;

  @override
  void scheduleAfterLocalWrite() => scheduleAfterLocalWriteCalls++;

  @override
  Future<void> pushBeforeSignOut() async => pushBeforeSignOutCalls++;

  void dispose() => _controller.close();
}
