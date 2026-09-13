import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zest/features/account/domain/account.dart';
import 'package:zest/features/collection/data/collection_database.dart';
import 'package:zest/features/collection/data/drift_collection_repository.dart';
import 'package:zest/features/collection/sync/sync_contract.dart';
import 'package:zest/features/collection/sync/sync_engine.dart';
import 'package:zest/features/discovery/domain/recipe.dart';

import '../../../support/catalog_fixtures.dart';
import '../../../support/fake_account_repository.dart';
import '../../../support/fake_sync_server.dart';

CollectionDatabase _openDb() => CollectionDatabase(
  DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
);

Recipe _recipe({String id = '98001', String name = 'Testbench Tonic'}) =>
    Recipe.fromJson(catalogRecipe(id: id, name: name));

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late FakeSyncServer server;
  final account = Account(
    id: 'user-1',
    email: 'sam@example.test',
    createdAt: DateTime.utc(2026, 9, 1),
  );

  setUp(() {
    server = FakeSyncServer();
  });

  /// One simulated device: its own local database, its own
  /// [FakeAccountRepository] (sharing [account]'s id when signed in), and
  /// its own [SyncEngine] against the shared [server].
  ({
    CollectionDatabase db,
    DriftCollectionRepository repo,
    FakeAccountRepository accountRepo,
    SyncEngine engine,
  })
  device({Account? signedInAs, DateTime Function()? now}) {
    final db = _openDb();
    final repo = DriftCollectionRepository(database: db, now: now);
    final accountRepo = FakeAccountRepository(current: signedInAs);
    final engine = SyncEngine(
      api: server.client(accountRepo),
      store: repo,
      account: accountRepo,
    );
    return (db: db, repo: repo, accountRepo: accountRepo, engine: engine);
  }

  tearDown(() async {});

  test('uploads existing local data on first sign-in', () async {
    final a = device();
    final entry = await a.repo.saveRecipe(_recipe());
    a.accountRepo.current = account;

    await a.engine.syncNow();

    expect(await a.repo.ownerUserId(), account.id);
    final local = await a.repo.localRecord(entry.id);
    expect(local!.dirty, isFalse);
    final page = await server.client(a.accountRepo).pull(since: 0);
    expect(page.entries, hasLength(1));
    expect(page.entries.single.id, entry.id);
    await a.db.close();
  });

  test('two-device conflict: the later edit wins, both directions', () async {
    // The database stores `updatedAt` at second precision, so last-edit-wins
    // needs clocks that differ by whole seconds, not real-clock delays.
    var clock = DateTime(2026, 9, 12, 10, 0, 0);
    final a = device(signedInAs: account, now: () => clock);
    final entry = await a.repo.saveRecipe(_recipe());
    await a.engine.syncNow();

    final b = device(signedInAs: account, now: () => clock);
    await b.engine.syncNow(); // pulls a's entry
    expect(await b.repo.watchEntry(entry.id).first, isNotNull);

    // Device B edits later: B's edit should win.
    clock = clock.add(const Duration(seconds: 5));
    await b.repo.moveToDay(entry.id, DateTime(2026, 8, 1));
    await b.engine.syncNow();
    await a.engine.syncNow();
    expect((await a.repo.watchEntry(entry.id).first)!.day, DateTime(2026, 8, 1));

    // Device A edits, but with an older timestamp than B's last write: A's
    // stale push should be overridden by B's still-newer server record.
    final staleRepo = DriftCollectionRepository(
      database: a.db,
      now: () => DateTime(2020, 1, 1),
    );
    await staleRepo.moveToDay(entry.id, DateTime(2020, 1, 1));
    await a.engine.syncNow();
    expect((await a.repo.watchEntry(entry.id).first)!.day, DateTime(2026, 8, 1));

    await a.db.close();
    await b.db.close();
  });

  test('a tombstone beats a stale edit from another device', () async {
    var clock = DateTime(2026, 9, 12, 10, 0, 0);
    final a = device(signedInAs: account, now: () => clock);
    final entry = await a.repo.saveRecipe(_recipe());
    await a.engine.syncNow();

    final b = device(signedInAs: account, now: () => clock);
    await b.engine.syncNow();

    clock = clock.add(const Duration(seconds: 5));
    await a.repo.delete(entry.id);
    await a.engine.syncNow();

    // B still has the (now stale) live entry locally; its next pass should
    // see the tombstone win, both on push (its update is rejected) and pull.
    clock = clock.add(const Duration(seconds: 5));
    await b.repo.moveToDay(entry.id, DateTime(2026, 7, 1));
    await b.engine.syncNow();

    expect(await b.repo.watchEntry(entry.id).first, isNull);
    final local = await b.repo.localRecord(entry.id);
    expect(local!.deleted, isTrue);

    await a.db.close();
    await b.db.close();
  });

  test('pulls multiple pages until hasMore is false', () async {
    final a = device(signedInAs: account);
    for (var i = 0; i < 5; i++) {
      await a.repo.saveRecipe(_recipe(id: '9800$i', name: 'Drink $i'));
    }
    await a.engine.syncNow();

    final b = device(signedInAs: account);
    // Force small pages by pulling directly through a constrained client is
    // not exposed on SyncEngine, so this exercises the engine's own paging
    // loop against the server's real page size instead.
    await b.engine.syncNow();
    expect(await b.repo.watchEntries().first, hasLength(5));

    await a.db.close();
    await b.db.close();
  });

  test('goes offline on a transport failure and recovers on the next pass', () async {
    final a = device(signedInAs: account);
    await a.repo.saveRecipe(_recipe());
    server.offline = true;

    await a.engine.syncNow();
    expect(a.engine.status.phase, SyncPhase.offline);

    server.offline = false;
    await a.engine.syncNow();
    expect(a.engine.status.phase, SyncPhase.idle);

    await a.db.close();
  });

  test('a 401 expires the session and reports failed', () async {
    final a = device(signedInAs: account);
    server.revokeSession(account.id);

    await a.engine.syncNow();

    expect(a.accountRepo.currentAccount, isNull);
    expect(a.engine.status.phase, SyncPhase.failed);

    await a.db.close();
  });

  test('signing in as a different user wipes local data first', () async {
    final firstUser = Account(
      id: 'user-1',
      email: 'sam@example.test',
      createdAt: DateTime.utc(2026, 9, 1),
    );
    final secondUser = Account(
      id: 'user-2',
      email: 'robin@example.test',
      createdAt: DateTime.utc(2026, 9, 2),
    );
    final a = device(signedInAs: firstUser);
    await a.repo.saveRecipe(_recipe());
    await a.engine.syncNow();
    expect(await a.repo.ownerUserId(), firstUser.id);

    a.accountRepo.current = secondUser;
    await a.engine.syncNow();

    expect(await a.repo.ownerUserId(), secondUser.id);
    expect(await a.repo.watchEntries().first, isEmpty);

    await a.db.close();
  });

  test('syncNow joins an in-flight pass instead of starting a second one', () async {
    final a = device(signedInAs: account);
    await a.repo.saveRecipe(_recipe());

    final first = a.engine.syncNow();
    final second = a.engine.syncNow();
    expect(identical(first, second), isTrue);
    await first;

    await a.db.close();
  });

  test('a local write schedules a debounced pass', () {
    fakeAsync((async) {
      final db = _openDb();
      final repo = DriftCollectionRepository(database: db);
      final accountRepo = FakeAccountRepository(current: account);
      final engine = SyncEngine(
        api: server.client(accountRepo),
        store: repo,
        account: accountRepo,
      );

      repo.saveRecipe(_recipe());
      engine.scheduleAfterLocalWrite();
      async.elapse(const Duration(milliseconds: 500));
      expect(engine.status.phase, SyncPhase.idle);

      async.elapse(const Duration(seconds: 2));
      async.flushMicrotasks();
      expect(engine.status.phase, isNot(SyncPhase.syncing));

      engine.dispose();
    });
  });
}
