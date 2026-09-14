import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:zest/features/account/application/account_sync_coordinator.dart';
import 'package:zest/features/collection/sync/sync_contract.dart';
import 'package:zest/features/home_bar/sync/home_bar_sync_contract.dart';

void main() {
  test('delegates lifecycle operations to both sync streams', () async {
    final collection = _FakeSync();
    final homeBar = _FakeSync();
    final coordinator = AccountSyncCoordinator(
      collection: collection,
      homeBar: homeBar,
    );
    addTearDown(() {
      coordinator.dispose();
      collection.dispose();
      homeBar.dispose();
    });

    coordinator.scheduleAfterLocalWrite();
    await coordinator.syncNow();
    await coordinator.pushBeforeSignOut();

    expect(collection.schedules, 1);
    expect(homeBar.schedules, 1);
    expect(collection.syncs, 1);
    expect(homeBar.syncs, 1);
    expect(collection.pushes, 1);
    expect(homeBar.pushes, 1);
  });

  test('combines status severity and uses the older completed time', () async {
    final collection = _FakeSync();
    final homeBar = _FakeSync();
    final coordinator = AccountSyncCoordinator(
      collection: collection,
      homeBar: homeBar,
    );
    addTearDown(() {
      coordinator.dispose();
      collection.dispose();
      homeBar.dispose();
    });
    final statuses = <SyncStatus>[];
    final subscription = coordinator.watchStatus().listen(statuses.add);
    addTearDown(subscription.cancel);
    await Future<void>.delayed(Duration.zero);

    collection.emit(const SyncStatus(SyncPhase.syncing));
    await Future<void>.delayed(Duration.zero);
    homeBar.emit(const SyncStatus(SyncPhase.offline));
    await Future<void>.delayed(Duration.zero);
    expect(statuses.last.phase, SyncPhase.offline);

    final earlier = DateTime.utc(2026, 9, 14, 10);
    final later = DateTime.utc(2026, 9, 14, 11);
    collection.emit(SyncStatus(SyncPhase.idle, lastSyncedAt: later));
    homeBar.emit(SyncStatus(SyncPhase.idle, lastSyncedAt: earlier));
    await Future<void>.delayed(Duration.zero);

    expect(statuses.last, SyncStatus(SyncPhase.idle, lastSyncedAt: earlier));
  });
}

final class _FakeSync implements CollectionSync, HomeBarSync {
  final _statuses = StreamController<SyncStatus>.broadcast();
  SyncStatus _status = const SyncStatus(SyncPhase.idle);
  int schedules = 0;
  int syncs = 0;
  int pushes = 0;

  @override
  SyncStatus get status => _status;

  void emit(SyncStatus value) {
    _status = value;
    _statuses.add(value);
  }

  @override
  Stream<SyncStatus> watchStatus() async* {
    yield _status;
    yield* _statuses.stream;
  }

  @override
  void scheduleAfterLocalWrite() => schedules++;

  @override
  Future<void> syncNow() async {
    syncs++;
  }

  @override
  Future<void> pushBeforeSignOut() async {
    pushes++;
  }

  void dispose() => _statuses.close();
}
