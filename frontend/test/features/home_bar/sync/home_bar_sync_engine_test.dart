import 'dart:async';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zest/features/account/domain/account.dart';
import 'package:zest/features/collection/data/collection_database.dart';
import 'package:zest/features/collection/sync/sync_contract.dart';
import 'package:zest/features/home_bar/data/drift_home_bar_repository.dart';
import 'package:zest/features/home_bar/domain/home_bar_item.dart';
import 'package:zest/features/home_bar/sync/home_bar_sync_contract.dart';
import 'package:zest/features/home_bar/sync/home_bar_sync_engine.dart';

import '../../../support/fake_account_repository.dart';
import '../../../support/fake_home_bar_sync_server.dart';

CollectionDatabase _openDb() => CollectionDatabase(
  DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
);

Account _account(String id) => Account(
  id: id,
  email: '$id@example.test',
  createdAt: DateTime.utc(2026, 9, 1),
);

void main() {
  test(
    'first account claims and uploads existing offline home-bar data',
    () async {
      final db = _openDb();
      addTearDown(db.close);
      final store = DriftHomeBarRepository(database: db);
      await store.addToBar('Gin');
      final account = FakeAccountRepository(current: _account('one'));
      final server = FakeHomeBarSyncServer();
      final sync = HomeBarSyncEngine(
        api: server.client(account),
        store: store,
        account: account,
      );
      addTearDown(sync.dispose);

      await sync.syncNow();

      expect(await store.ownerUserId(), 'one');
      expect((await store.localRecord('gin'))!.dirty, isFalse);
      expect(
        (await server.client(account).pull(since: 0)).items.single.ingredientId,
        'gin',
      );
    },
  );

  test(
    'a different signed-in account wipes home-bar cache before pulling',
    () async {
      final db = _openDb();
      addTearDown(db.close);
      final store = DriftHomeBarRepository(database: db);
      final first = FakeAccountRepository(current: _account('one'));
      final server = FakeHomeBarSyncServer();
      final firstSync = HomeBarSyncEngine(
        api: server.client(first),
        store: store,
        account: first,
      );
      addTearDown(firstSync.dispose);
      await store.addToBar('Gin');
      await firstSync.syncNow();

      await store.addToShopping('Lime juice');
      final second = FakeAccountRepository(current: _account('two'));
      final secondSync = HomeBarSyncEngine(
        api: server.client(second),
        store: store,
        account: second,
      );
      addTearDown(secondSync.dispose);
      await secondSync.syncNow();

      expect(await store.ownerUserId(), 'two');
      expect(await store.watchItems().first, isEmpty);
    },
  );

  test(
    'an equal-timestamp foreign result is re-stamped and retried once',
    () async {
      var now = DateTime.utc(2026, 9, 14, 12);
      final server = FakeHomeBarSyncServer();
      final accountA = FakeAccountRepository(current: _account('one'));
      final accountB = FakeAccountRepository(current: _account('one'));
      final dbA = _openDb();
      final dbB = _openDb();
      addTearDown(dbA.close);
      addTearDown(dbB.close);
      final a = DriftHomeBarRepository(database: dbA, now: () => now);
      final b = DriftHomeBarRepository(database: dbB, now: () => now);
      final syncA = HomeBarSyncEngine(
        api: server.client(accountA),
        store: a,
        account: accountA,
      );
      final syncB = HomeBarSyncEngine(
        api: server.client(accountB),
        store: b,
        account: accountB,
      );
      addTearDown(syncA.dispose);
      addTearDown(syncB.dispose);

      await a.addToBar('Gin');
      await syncA.syncNow();
      await syncB.syncNow();
      await a.addToShopping('Gin');
      await b.remove('gin');
      final sentAt = (await b.localRecord('gin'))!.item.updatedAt;

      await syncA.syncNow();
      await syncB.syncNow();

      final winner = (await server.client(accountA).pull(since: 0)).items.last;
      expect(winner.deleted, isTrue);
      expect(winner.updatedAt.isAfter(sentAt), isTrue);
      expect((await b.localRecord('gin'))!.dirty, isFalse);
    },
  );

  test(
    'a local move made while PUT is in flight stays dirty and wins next sync',
    () async {
      var now = DateTime.utc(2026, 9, 14, 12);
      final db = _openDb();
      addTearDown(db.close);
      final store = DriftHomeBarRepository(database: db, now: () => now);
      final account = FakeAccountRepository(current: _account('one'));
      final server = FakeHomeBarSyncServer();
      final delayed = _DelayedFirstPutApi(server.client(account));
      final sync = HomeBarSyncEngine(
        api: delayed,
        store: store,
        account: account,
        debounce: const Duration(milliseconds: 1),
      );
      addTearDown(sync.dispose);
      await store.addToBar('Gin');

      final firstPass = sync.syncNow();
      await delayed.accepted;
      now = now.add(const Duration(seconds: 1));
      await store.addToShopping('Gin');
      sync.scheduleAfterLocalWrite();
      // Let the debounce expire while the first PUT response is still held.
      await Future<void>.delayed(const Duration(milliseconds: 10));
      delayed.release();
      await firstPass;
      await delayed.secondPut;
      await Future<void>.delayed(Duration.zero);

      final local = (await store.localRecord('gin'))!;
      expect(local.item.location, HomeBarLocation.shopping);
      expect(local.dirty, isFalse);
      final remote = (await server.client(account).pull(since: 0)).items.last;
      expect(remote.location, HomeBarLocation.shopping);
    },
  );

  test(
    'pull follows every page and advances only the home-bar cursor',
    () async {
      final server = FakeHomeBarSyncServer();
      final account = FakeAccountRepository(current: _account('one'));
      final sourceDb = _openDb();
      final targetDb = _openDb();
      addTearDown(sourceDb.close);
      addTearDown(targetDb.close);
      final source = DriftHomeBarRepository(database: sourceDb);
      final target = DriftHomeBarRepository(database: targetDb);
      final sourceSync = HomeBarSyncEngine(
        api: server.client(account),
        store: source,
        account: account,
      );
      final targetSync = HomeBarSyncEngine(
        api: _CappedApi(server.client(account)),
        store: target,
        account: FakeAccountRepository(current: _account('one')),
      );
      addTearDown(sourceSync.dispose);
      addTearDown(targetSync.dispose);
      await source.addToBar('Gin');
      await source.addToBar('Vodka');
      await source.addToShopping('Lime juice');
      await sourceSync.syncNow();

      await targetSync.syncNow();

      expect(await target.watchItems().first, hasLength(3));
      expect(await target.lastRevision(), 3);
    },
  );

  test(
    'offline and expired sessions keep dirty rows and expose M8 status',
    () async {
      final db = _openDb();
      addTearDown(db.close);
      final store = DriftHomeBarRepository(database: db);
      final account = FakeAccountRepository(current: _account('one'));
      final server = FakeHomeBarSyncServer()..offline = true;
      final sync = HomeBarSyncEngine(
        api: server.client(account),
        store: store,
        account: account,
      );
      addTearDown(sync.dispose);
      await store.addToBar('Gin');

      await sync.syncNow();
      expect(sync.status.phase, SyncPhase.offline);
      expect((await store.localRecord('gin'))!.dirty, isTrue);

      server.offline = false;
      server.revoke('one');
      await sync.syncNow();
      expect(sync.status.phase, SyncPhase.failed);
      expect(account.currentAccount, isNull);
      expect((await store.localRecord('gin'))!.dirty, isTrue);
    },
  );
}

final class _CappedApi implements HomeBarSyncApi {
  const _CappedApi(this._inner);

  final HomeBarSyncApi _inner;

  @override
  Future<HomeBarSyncPage> pull({required int since, int limit = 200}) =>
      _inner.pull(since: since, limit: 2);

  @override
  Future<HomeBarRecord> putItem(HomeBarRecord record) => _inner.putItem(record);
}

final class _DelayedFirstPutApi implements HomeBarSyncApi {
  _DelayedFirstPutApi(this._inner);

  final HomeBarSyncApi _inner;
  final _accepted = Completer<void>();
  final _release = Completer<void>();
  final _secondPut = Completer<void>();
  var _delayed = false;
  var _putCount = 0;

  Future<void> get accepted => _accepted.future;
  Future<void> get secondPut => _secondPut.future;

  void release() => _release.complete();

  @override
  Future<HomeBarSyncPage> pull({required int since, int limit = 200}) =>
      _inner.pull(since: since, limit: limit);

  @override
  Future<HomeBarRecord> putItem(HomeBarRecord record) async {
    _putCount++;
    final returned = await _inner.putItem(record);
    if (!_delayed) {
      _delayed = true;
      _accepted.complete();
      await _release.future;
    } else if (_putCount == 2) {
      _secondPut.complete();
    }
    return returned;
  }
}
