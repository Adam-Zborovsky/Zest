import 'dart:async';

import '../../collection/sync/sync_contract.dart';
import '../../home_bar/sync/home_bar_sync_contract.dart';

/// Presents collection and home-bar synchronization as one account-level
/// lifecycle seam. Session, profile, and mutation code can keep using their
/// existing interfaces while both independent revision streams run together.
final class AccountSyncCoordinator implements CollectionSync, HomeBarSync {
  AccountSyncCoordinator({
    required CollectionSync collection,
    required HomeBarSync homeBar,
  }) : _collection = collection,
       _homeBar = homeBar,
       _collectionStatus = collection.status,
       _homeBarStatus = homeBar.status {
    _collectionSubscription = collection.watchStatus().listen((status) {
      _collectionStatus = status;
      _publishCombinedStatus();
    });
    _homeBarSubscription = homeBar.watchStatus().listen((status) {
      _homeBarStatus = status;
      _publishCombinedStatus();
    });
  }

  final CollectionSync _collection;
  final HomeBarSync _homeBar;
  final _statusController = StreamController<SyncStatus>.broadcast();

  late final StreamSubscription<SyncStatus> _collectionSubscription;
  late final StreamSubscription<SyncStatus> _homeBarSubscription;
  late SyncStatus _collectionStatus;
  late SyncStatus _homeBarStatus;
  Future<void>? _inFlight;
  bool _closed = false;

  @override
  SyncStatus get status => _combine(_collectionStatus, _homeBarStatus);

  @override
  Stream<SyncStatus> watchStatus() async* {
    yield status;
    yield* _statusController.stream;
  }

  @override
  Future<void> syncNow() {
    final running = _inFlight;
    if (running != null) return running;
    final pass = Future.wait([
      _collection.syncNow(),
      _homeBar.syncNow(),
    ]).then((_) {});
    _inFlight = pass;
    pass.whenComplete(() {
      if (identical(_inFlight, pass)) _inFlight = null;
    });
    return pass;
  }

  @override
  void scheduleAfterLocalWrite() {
    _collection.scheduleAfterLocalWrite();
    _homeBar.scheduleAfterLocalWrite();
  }

  @override
  Future<void> pushBeforeSignOut() => Future.wait([
    _collection.pushBeforeSignOut(),
    _homeBar.pushBeforeSignOut(),
  ]).then((_) {});

  void _publishCombinedStatus() {
    if (!_closed) _statusController.add(status);
  }

  /// Failure and offline states stay visible even if the other stream is
  /// still running. A completed timestamp represents the older of the two
  /// successful passes: both streams are known synced through at least that
  /// instant.
  static SyncStatus _combine(SyncStatus collection, SyncStatus homeBar) {
    final phase = switch ((collection.phase, homeBar.phase)) {
      (SyncPhase.failed, _) || (_, SyncPhase.failed) => SyncPhase.failed,
      (SyncPhase.offline, _) || (_, SyncPhase.offline) => SyncPhase.offline,
      (SyncPhase.syncing, _) || (_, SyncPhase.syncing) => SyncPhase.syncing,
      _ => SyncPhase.idle,
    };
    final collectionAt = collection.lastSyncedAt;
    final homeBarAt = homeBar.lastSyncedAt;
    final lastSyncedAt = collectionAt == null || homeBarAt == null
        ? null
        : collectionAt.isBefore(homeBarAt)
        ? collectionAt
        : homeBarAt;
    return SyncStatus(phase, lastSyncedAt: lastSyncedAt);
  }

  void dispose() {
    _closed = true;
    unawaited(_collectionSubscription.cancel());
    unawaited(_homeBarSubscription.cancel());
    unawaited(_statusController.close());
  }
}
