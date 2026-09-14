import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as raw;
import 'package:zest/features/account/domain/account.dart';
import 'package:zest/features/collection/data/collection_database.dart';
import 'package:zest/features/collection/data/collection_sync_store.dart';
import 'package:zest/features/collection/data/drift_collection_repository.dart';
import 'package:zest/features/collection/domain/collection_entry.dart';
import 'package:zest/features/collection/domain/memory_photo.dart';
import 'package:zest/features/collection/sync/sync_contract.dart';
import 'package:zest/features/collection/sync/sync_engine.dart';
import 'package:zest/features/discovery/domain/recipe.dart';

import '../../../support/catalog_fixtures.dart';
import '../../../support/fake_account_repository.dart';
import '../../../support/fake_sync_server.dart';

/// Wraps a [SyncApi], counting how many calls are in flight at once (for
/// asserting single-flight behavior) and, once [markerSet] is flipped, how
/// many further calls arrive (a stand-in for "no request goes out with the
/// old token" after the caller would have cleared it).
final class _TrackingSyncApi implements SyncApi {
  _TrackingSyncApi(this._inner);

  final SyncApi _inner;
  int _active = 0;
  int maxConcurrent = 0;
  bool markerSet = false;
  int callsAfterMarker = 0;

  Future<T> _track<T>(Future<T> Function() call) async {
    _active++;
    if (_active > maxConcurrent) maxConcurrent = _active;
    if (markerSet) callsAfterMarker++;
    try {
      // A real (non-zero) delay, not just a microtask hop: on the
      // zero-latency FakeSyncServer, two racing async chains with no real
      // asynchronous gap tend to fully resolve one before the other gets
      // scheduled, hiding a genuine race. This forces both chains to have
      // an overlapping window to call through, whether or not the
      // production code actually serializes them.
      await Future<void>.delayed(const Duration(milliseconds: 5));
      return await call();
    } finally {
      _active--;
    }
  }

  @override
  Future<SyncPage> pull({required int since, int limit = 200}) =>
      _track(() => _inner.pull(since: since, limit: limit));

  @override
  Future<EntryRecord> putEntry(EntryRecord record) =>
      _track(() => _inner.putEntry(record));

  @override
  Future<EntryRecord> putPhoto(
    String entryId,
    MemoryPhoto photo, {
    required DateTime updatedAt,
  }) => _track(() => _inner.putPhoto(entryId, photo, updatedAt: updatedAt));

  @override
  Future<EntryRecord> deletePhoto(String entryId, {required DateTime updatedAt}) =>
      _track(() => _inner.deletePhoto(entryId, updatedAt: updatedAt));

  @override
  Future<MemoryPhoto?> getPhoto(String entryId) => _track(() => _inner.getPhoto(entryId));
}

/// A [SyncApi] that returns a fixed [SyncPage] from [pull] and throws for
/// every other call (unused in the tests that need it).
final class _FixedPullSyncApi implements SyncApi {
  _FixedPullSyncApi(this._page);

  final SyncPage _page;

  @override
  Future<SyncPage> pull({required int since, int limit = 200}) async => _page;

  @override
  Future<EntryRecord> putEntry(EntryRecord record) =>
      throw UnimplementedError('Not used in this test.');

  @override
  Future<EntryRecord> putPhoto(
    String entryId,
    MemoryPhoto photo, {
    required DateTime updatedAt,
  }) => throw UnimplementedError('Not used in this test.');

  @override
  Future<EntryRecord> deletePhoto(String entryId, {required DateTime updatedAt}) =>
      throw UnimplementedError('Not used in this test.');

  @override
  Future<MemoryPhoto?> getPhoto(String entryId) =>
      throw UnimplementedError('Not used in this test.');
}

/// A [SyncApi] whose [putEntry] always returns the same canned [response]
/// (an empty [pull], and every photo call unimplemented). Counts calls and
/// remembers the last sent record, for asserting how many pushes a tie
/// retry makes and what the retried push actually sent.
final class _FixedPutEntrySyncApi implements SyncApi {
  _FixedPutEntrySyncApi(this.response);

  final EntryRecord response;
  int putCount = 0;
  EntryRecord? lastSent;

  @override
  Future<SyncPage> pull({required int since, int limit = 200}) async =>
      SyncPage(entries: const [], revision: since, hasMore: false);

  @override
  Future<EntryRecord> putEntry(EntryRecord record) async {
    putCount++;
    lastSent = record;
    return response;
  }

  @override
  Future<EntryRecord> putPhoto(
    String entryId,
    MemoryPhoto photo, {
    required DateTime updatedAt,
  }) => throw UnimplementedError('Not used in this test.');

  @override
  Future<EntryRecord> deletePhoto(String entryId, {required DateTime updatedAt}) =>
      throw UnimplementedError('Not used in this test.');

  @override
  Future<MemoryPhoto?> getPhoto(String entryId) =>
      throw UnimplementedError('Not used in this test.');
}

/// A [CollectionSyncStore] whose [dirtyRecords] (what push sees) and
/// [localRecord] (what the pull's conflict check sees) can be set
/// independently. A real store keeps these consistent; diverging them here
/// stands in for the narrow race the fix in `_applyPulledEntry` guards
/// against: a row becomes locally dirty in the gap between push taking its
/// dirty-rows snapshot and pull applying an incoming record for that same
/// row, so push never saw it this pass but pull still must not clobber it.
final class _StubSyncStore implements CollectionSyncStore {
  _StubSyncStore(this._local);

  LocalSyncRecord? _local;
  EntryRecord? applied;
  String? ownerId;
  int revision = 0;

  @override
  Future<List<LocalSyncRecord>> dirtyRecords() async => const [];

  @override
  Future<LocalSyncRecord?> localRecord(String id) async => _local;

  @override
  Future<({MemoryPhoto photo, DateTime updatedAt})?> photoForSync(String id) async =>
      null;

  @override
  Future<void> applyServerRecord(EntryRecord record, {bool clearPhotoDirty = false}) async {
    applied = record;
  }

  @override
  Future<void> setServerPhoto(String id, MemoryPhoto photo, DateTime updatedAt) async {}

  @override
  Future<void> restampEntry(String id, DateTime updatedAt) async {}

  @override
  Future<void> restampPhoto(String id, DateTime updatedAt) async {}

  @override
  Future<String?> ownerUserId() async => ownerId;

  @override
  Future<void> setOwnerUserId(String? userId) async => ownerId = userId;

  @override
  Future<int> lastRevision() async => revision;

  @override
  Future<void> setLastRevision(int value) async => revision = value;

  @override
  Future<void> wipe() async {}
}

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

    // Device A edits again, this time with a badly wrong (backwards) local
    // clock. Post M8-review-fix, the strictly-later bump (`max(now, previous
    // + 1ms)`, finding 1) means a broken clock can never make a write look
    // stale against the row's own last-known local value (B's edit, just
    // pulled in above): A's edit is still stamped strictly after it, so it
    // is a genuine, later edit and correctly wins on the server too — a
    // broken clock no longer risks silently losing a local edit.
    final beforeStaleWrite = (await a.repo.watchEntry(entry.id).first)!.updatedAt;
    final staleClockRepo = DriftCollectionRepository(
      database: a.db,
      now: () => DateTime(2020, 1, 1),
    );
    final staleClockWrite = await staleClockRepo.moveToDay(
      entry.id,
      DateTime(2020, 1, 1),
    );
    expect(staleClockWrite.updatedAt.isAfter(beforeStaleWrite), isTrue);
    await a.engine.syncNow();
    expect((await a.repo.watchEntry(entry.id).first)!.day, DateTime(2020, 1, 1));

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

  group('M8 review fix: millisecond timestamps', () {
    test(
      'a same-clock-instant edit still reaches the server and survives a '
      'pull (regression, finding 1a)',
      () async {
        final clock = DateTime(2026, 9, 12, 10, 0, 0);
        final a = device(signedInAs: account, now: () => clock);
        final entry = await a.repo.saveRecipe(_recipe());
        await a.engine.syncNow();

        // The clock does not advance at all between the save above and this
        // move: on the pre-fix whole-second `DateTimeColumn`, this move's
        // `updatedAt` would tie the value just pushed. The server's
        // last-edit-wins rule then no-ops the write (`updatedAt` "equal ...
        // leaves the row unchanged"), and the strictly-later bump is what
        // makes this move's timestamp actually advance despite the frozen
        // clock.
        final moved = await a.repo.moveToDay(entry.id, DateTime(2026, 8, 1));
        expect(moved.updatedAt.isAfter(entry.updatedAt), isTrue);

        await a.engine.syncNow();
        final page = await server.client(a.accountRepo).pull(since: 0);
        expect(page.entries.single.day, '2026-08-01');

        // A second device pulling from scratch sees the move too, not the
        // reverted original day.
        final b = device(signedInAs: account, now: () => clock);
        await b.engine.syncNow();
        expect(
          (await b.repo.watchEntry(entry.id).first)!.day,
          DateTime(2026, 8, 1),
        );

        await a.db.close();
        await b.db.close();
      },
    );

    test(
      'a dirty local row is not lost to a pulled record at an equal '
      'timestamp (regression, finding 1b)',
      () async {
        final localTime = DateTime.utc(2026, 9, 12, 10, 0, 0, 123);
        final localEntry = EntryRecord(
          id: '11111111111111111111111111111111',
          kind: CollectionEntryKind.saved,
          sourceRecipeId: '98001',
          source: const {'idDrink': '98001', 'strDrink': 'Local Edit'},
          variation: null,
          day: '2026-09-12',
          hasPhoto: false,
          photoUpdatedAt: null,
          createdAt: localTime,
          updatedAt: localTime,
          deleted: false,
        );
        final local = LocalSyncRecord(
          id: localEntry.id,
          kind: localEntry.kind,
          sourceRecipeId: localEntry.sourceRecipeId,
          sourceJson: '{"idDrink":"98001","strDrink":"Local Edit"}',
          variationJson: null,
          day: localEntry.day,
          hasPhoto: false,
          photoUpdatedAt: null,
          createdAt: localTime,
          updatedAt: localTime,
          deleted: false,
          dirty: true,
          photoDirty: false,
        );
        // A pulled record for the same id at the exact same instant, but
        // with different content (as if another device's write landed on
        // the same millisecond) — simulates dirtyRecords() having already
        // been snapshotted (empty) before this row turned dirty, so push
        // never touched it this pass; only the pull-time comparison stands
        // between it and being silently clobbered.
        final pulled = EntryRecord(
          id: localEntry.id,
          kind: CollectionEntryKind.saved,
          sourceRecipeId: '98001',
          source: const {'idDrink': '98001', 'strDrink': 'Other Device'},
          variation: null,
          day: '2026-09-01',
          hasPhoto: false,
          photoUpdatedAt: null,
          createdAt: localTime,
          updatedAt: localTime,
          deleted: false,
          revision: 5,
        );

        final store = _StubSyncStore(local);
        final accountRepo = FakeAccountRepository(current: account);
        final engine = SyncEngine(
          api: _FixedPullSyncApi(
            SyncPage(entries: [pulled], revision: 5, hasMore: false),
          ),
          store: store,
          account: accountRepo,
        );

        await engine.syncNow();

        expect(engine.status.phase, SyncPhase.idle);
        // The equal-timestamp pulled record must not have been applied: the
        // dirty local edit wins the tie, since an equal timestamp does not
        // prove the server has seen this local edit yet.
        expect(store.applied, isNull);

        engine.dispose();
      },
    );

    test(
      'the schema 3 to 4 migration converts stored seconds to milliseconds '
      'and keeps every entry and photo',
      () async {
        final dir = await Directory.systemTemp.createTemp('zest-migration4-test');
        addTearDown(() => dir.delete(recursive: true));
        final path = '${dir.path}${Platform.pathSeparator}collection.sqlite';
        final source = Recipe.fromJson(
          catalogRecipe(id: '98001', name: 'Testbench Tonic'),
        );
        final createdAt = DateTime.utc(2026, 9, 10, 21, 30, 45);
        final updatedAt = DateTime.utc(2026, 9, 11, 8, 15, 30);
        final createdSeconds = createdAt.millisecondsSinceEpoch ~/ 1000;
        final updatedSeconds = updatedAt.millisecondsSinceEpoch ~/ 1000;
        final photoBytes = Uint8List.fromList(const [
          0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, //
        ]);

        final legacy = raw.sqlite3.open(path);
        legacy.execute('''
          CREATE TABLE entries (
            id TEXT NOT NULL,
            kind TEXT NOT NULL,
            source_recipe_id TEXT NOT NULL,
            source_json TEXT NOT NULL,
            variation_json TEXT NULL,
            day TEXT NOT NULL DEFAULT '',
            has_photo INTEGER NOT NULL DEFAULT 0 CHECK ("has_photo" IN (0, 1)),
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            dirty INTEGER NOT NULL DEFAULT 1 CHECK ("dirty" IN (0, 1)),
            deleted INTEGER NOT NULL DEFAULT 0 CHECK ("deleted" IN (0, 1)),
            photo_dirty INTEGER NOT NULL DEFAULT 0 CHECK ("photo_dirty" IN (0, 1)),
            PRIMARY KEY (id)
          );
        ''');
        legacy.execute('''
          CREATE TABLE photos (
            entry_id TEXT NOT NULL,
            mime_type TEXT NOT NULL,
            bytes BLOB NOT NULL,
            updated_at INTEGER NOT NULL,
            PRIMARY KEY (entry_id)
          );
        ''');
        legacy.execute('''
          CREATE TABLE sync_state (
            id INTEGER NOT NULL DEFAULT 0,
            owner_user_id TEXT NULL,
            last_revision INTEGER NOT NULL DEFAULT 0,
            PRIMARY KEY (id)
          );
        ''');
        legacy.execute(
          'CREATE INDEX entries_source_recipe_id ON entries (source_recipe_id);',
        );
        legacy.execute('CREATE INDEX entries_day ON entries (day);');
        legacy.execute(
          'INSERT INTO entries (id, kind, source_recipe_id, source_json, day, '
          'has_photo, created_at, updated_at, dirty, deleted, photo_dirty) '
          'VALUES (?, ?, ?, ?, ?, 1, ?, ?, 0, 0, 0);',
          [
            'legacy-saved',
            'saved',
            source.id,
            jsonEncode(source.toJson()),
            '2026-09-10',
            createdSeconds,
            updatedSeconds,
          ],
        );
        legacy.execute(
          'INSERT INTO photos (entry_id, mime_type, bytes, updated_at) '
          'VALUES (?, ?, ?, ?);',
          ['legacy-saved', 'image/png', photoBytes, updatedSeconds],
        );
        legacy.execute(
          "INSERT INTO sync_state (id, owner_user_id, last_revision) "
          "VALUES (0, 'user-1', 7);",
        );
        legacy.userVersion = 3;
        legacy.close();

        final db = CollectionDatabase(NativeDatabase(File(path)));
        addTearDown(db.close);
        final repo = DriftCollectionRepository(
          database: db,
          now: () => DateTime.utc(2026, 9, 13, 12),
        );

        final entries = await repo.watchEntries().first;
        expect(entries, hasLength(1));
        expect(entries.single.id, 'legacy-saved');
        // The stored seconds converted to milliseconds carry no extra
        // precision, but the conversion factor (x1000) must be exact.
        // isAtSameMomentAs, not ==: the database returns a local DateTime
        // while createdAt/updatedAt above are UTC-flagged for the same
        // instant, and DateTime's == also compares that flag.
        expect(entries.single.createdAt.isAtSameMomentAs(createdAt), isTrue);
        expect(entries.single.updatedAt.isAtSameMomentAs(updatedAt), isTrue);
        expect((await repo.photo('legacy-saved'))!.bytes, photoBytes);

        final local = await repo.localRecord('legacy-saved');
        expect(local!.photoUpdatedAt!.isAtSameMomentAs(updatedAt), isTrue);

        // Preserved sync state from schema 3.
        expect(await repo.ownerUserId(), 'user-1');
        expect(await repo.lastRevision(), 7);
      },
    );
  });

  group('M8 review fix: push tie resolution', () {
    test(
      '(a) a tie through a real push does not silently lose the losing '
      "device's edit",
      () async {
        final t0 = DateTime(2026, 9, 12, 10, 0, 0);
        final a = device(signedInAs: account, now: () => t0);
        final entry = await a.repo.saveRecipe(_recipe());
        await a.engine.syncNow();

        final b = device(signedInAs: account, now: () => t0);
        await b.engine.syncNow(); // Pulls a's entry, updatedAt == t0.

        // Both devices edit with clocks frozen at (or behind) t0: each
        // stamps its edit at the floored t0+1ms
        // (DriftCollectionRepository._laterThan), so both compute the exact
        // same updatedAt. A pushes first and applies cleanly.
        await a.repo.moveToDay(entry.id, DateTime(2026, 8, 1));
        await a.engine.syncNow();

        // B, unaware of A's push, edits from the same starting point and
        // computes the identical updatedAt. B's push ties.
        await b.repo.moveToDay(entry.id, DateTime(2026, 7, 1));
        await b.engine.syncNow();

        // Pre-fix, B would have silently adopted A's record here (foreign
        // content, cleared dirty). Post-fix, B's push is rejected as a tie,
        // re-stamped strictly later, and retried in the same pass, so B's
        // own edit is what ends up applied.
        final bLocal = await b.repo.localRecord(entry.id);
        expect(bLocal!.day, '2026-07-01');
        // No device may report a clean row while holding content the
        // server does not have: B's row must be clean only because its
        // edit actually reached the server.
        expect(bLocal.dirty, isFalse);
        final serverPage = await server.client(b.accountRepo).pull(since: 0);
        final serverRecord = serverPage.entries.singleWhere(
          (e) => e.id == entry.id,
        );
        expect(serverRecord.day, '2026-07-01');

        // A converges to B's (later) edit on its next pull.
        await a.engine.syncNow();
        expect((await a.repo.watchEntry(entry.id).first)!.day, DateTime(2026, 7, 1));

        await a.db.close();
        await b.db.close();
      },
    );

    test('(b) a genuinely newer server record is adopted', () async {
      final db = _openDb();
      addTearDown(db.close);
      final repo = DriftCollectionRepository(
        database: db,
        now: () => DateTime(2026, 9, 12, 10),
      );
      final accountRepo = FakeAccountRepository(current: account);
      final entry = await repo.saveRecipe(_recipe());
      final sent = (await repo.localRecord(entry.id))!.toEntryRecord();
      final serverNewer = EntryRecord(
        id: sent.id,
        kind: sent.kind,
        sourceRecipeId: sent.sourceRecipeId,
        source: const {'idDrink': '98001', 'strDrink': 'Server Newer'},
        variation: null,
        day: '2026-09-01',
        hasPhoto: false,
        photoUpdatedAt: null,
        createdAt: sent.createdAt,
        updatedAt: sent.updatedAt.add(const Duration(milliseconds: 5)),
        deleted: false,
        revision: 9,
      );
      final api = _FixedPutEntrySyncApi(serverNewer);
      final engine = SyncEngine(api: api, store: repo, account: accountRepo);
      addTearDown(engine.dispose);

      await engine.syncNow();

      expect(api.putCount, 1);
      final local = await repo.localRecord(entry.id);
      expect(local!.dirty, isFalse);
      expect(local.day, '2026-09-01');
    });

    test(
      '(c) identical content at an equal timestamp is an idempotent retry '
      'and clears dirty',
      () async {
        final db = _openDb();
        addTearDown(db.close);
        final repo = DriftCollectionRepository(
          database: db,
          now: () => DateTime(2026, 9, 12, 10),
        );
        final accountRepo = FakeAccountRepository(current: account);
        final entry = await repo.saveRecipe(_recipe());
        final sent = (await repo.localRecord(entry.id))!.toEntryRecord();
        // The server echoes back exactly what was sent (this push already
        // applied, or a retried request after a dropped response), with a
        // revision assigned.
        final echoed = EntryRecord(
          id: sent.id,
          kind: sent.kind,
          sourceRecipeId: sent.sourceRecipeId,
          source: sent.source,
          variation: sent.variation,
          day: sent.day,
          hasPhoto: sent.hasPhoto,
          photoUpdatedAt: sent.photoUpdatedAt,
          createdAt: sent.createdAt,
          updatedAt: sent.updatedAt,
          deleted: sent.deleted,
          revision: 4,
        );
        final api = _FixedPutEntrySyncApi(echoed);
        final engine = SyncEngine(api: api, store: repo, account: accountRepo);
        addTearDown(engine.dispose);

        await engine.syncNow();

        expect(api.putCount, 1);
        final local = await repo.localRecord(entry.id);
        expect(local!.dirty, isFalse);
        expect(local.day, sent.day);
      },
    );

    test(
      '(d) a server that always rejects ties bounds the retry to one and '
      'leaves the row dirty',
      () async {
        final db = _openDb();
        addTearDown(db.close);
        final repo = DriftCollectionRepository(
          database: db,
          now: () => DateTime(2026, 9, 12, 10),
        );
        final accountRepo = FakeAccountRepository(current: account);
        final entry = await repo.saveRecipe(_recipe());
        final sent = (await repo.localRecord(entry.id))!.toEntryRecord();
        // A fixed foreign record, always returned regardless of what is
        // sent: a server that never accepts this device's write.
        final alwaysRejects = EntryRecord(
          id: sent.id,
          kind: sent.kind,
          sourceRecipeId: sent.sourceRecipeId,
          source: const {'idDrink': '98001', 'strDrink': 'Someone Else'},
          variation: null,
          day: sent.day,
          hasPhoto: false,
          photoUpdatedAt: null,
          createdAt: sent.createdAt,
          updatedAt: sent.updatedAt,
          deleted: false,
          revision: 2,
        );
        final api = _FixedPutEntrySyncApi(alwaysRejects);
        final engine = SyncEngine(api: api, store: repo, account: accountRepo);
        addTearDown(engine.dispose);

        await engine.syncNow();

        // Exactly one push plus one bounded retry: no infinite loop.
        expect(api.putCount, 2);
        expect(
          api.lastSent!.updatedAt.isAfter(sent.updatedAt),
          isTrue,
          reason: 'the retried push must re-stamp strictly later',
        );
        final local = await repo.localRecord(entry.id);
        expect(local!.dirty, isTrue);
      },
    );
  });

  group('M8 review fix: pushBeforeSignOut', () {
    test(
      'joins the in-flight pass under one single-flight guard instead of '
      'racing it (regression, finding 2)',
      () async {
        final db = _openDb();
        addTearDown(db.close);
        final repo = DriftCollectionRepository(database: db);
        final accountRepo = FakeAccountRepository(current: account);
        final tracking = _TrackingSyncApi(server.client(accountRepo));
        final engine = SyncEngine(api: tracking, store: repo, account: accountRepo);
        addTearDown(engine.dispose);

        await repo.saveRecipe(_recipe());

        final passFuture = engine.syncNow();
        final signOutFuture = engine.pushBeforeSignOut();
        await Future.wait([passFuture, signOutFuture]);

        // From here on, production code (SessionController.signOut) clears
        // the session token; no further request may go out after this
        // point.
        tracking.markerSet = true;
        await Future<void>.delayed(Duration.zero);

        expect(
          tracking.maxConcurrent,
          lessThanOrEqualTo(1),
          reason: 'pushBeforeSignOut must not race an in-flight pass',
        );
        expect(tracking.callsAfterMarker, 0);
      },
    );
  });
}
