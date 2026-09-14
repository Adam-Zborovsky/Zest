import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:zest/features/collection/domain/collection_entry.dart';
import 'package:zest/features/collection/domain/memory_photo.dart';
import 'package:zest/features/collection/sync/sync_contract.dart';

import '../../../support/fake_account_repository.dart';
import '../../../support/fake_sync_server.dart';

/// Asserts [FakeSyncServer] tracks `backend/src/accounts/repository.ts`
/// exactly on the fields that route treats as server-owned. These would
/// pass against the pre-fix fake (which echoed the client instead), so they
/// exist to catch a future re-divergence, not to reproduce the sync engine
/// bug itself (see `sync_engine_test.dart`'s "entry PUT ignores
/// client-owned photo/createdAt fields" group for that).
void main() {
  final png = Uint8List.fromList(const [
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, //
  ]);

  EntryRecord entry({
    String id = '11111111111111111111111111111111',
    bool hasPhoto = false,
    DateTime? photoUpdatedAt,
    required DateTime createdAt,
    required DateTime updatedAt,
    bool deleted = false,
  }) => EntryRecord(
    id: id,
    kind: CollectionEntryKind.saved,
    sourceRecipeId: '98001',
    source: deleted ? null : const {'idDrink': '98001', 'strDrink': 'Tonic'},
    variation: null,
    day: '2026-09-13',
    hasPhoto: hasPhoto,
    photoUpdatedAt: photoUpdatedAt,
    createdAt: createdAt,
    updatedAt: updatedAt,
    deleted: deleted,
  );

  group('FakeSyncServer.putEntry mirrors upsertEntry', () {
    test('a brand-new entry gets hasPhoto false and null photoUpdatedAt '
        'regardless of what the client sent', () async {
      final server = FakeSyncServer();
      final account = FakeAccountRepository(current: _account);
      final api = server.client(account);

      final t0 = DateTime.utc(2026, 9, 13, 10);
      final stored = await api.putEntry(
        entry(
          hasPhoto: true,
          photoUpdatedAt: t0,
          createdAt: t0,
          updatedAt: t0,
        ),
      );

      expect(stored.hasPhoto, isFalse);
      expect(stored.photoUpdatedAt, isNull);
    });

    test('an update to an existing entry keeps the stored hasPhoto and '
        'photoUpdatedAt, ignoring the incoming values', () async {
      final server = FakeSyncServer();
      final account = FakeAccountRepository(current: _account);
      final api = server.client(account);

      final t0 = DateTime.utc(2026, 9, 13, 10);
      await api.putEntry(entry(createdAt: t0, updatedAt: t0));
      final photoAt = t0.add(const Duration(seconds: 1));
      await api.putPhoto(
        '11111111111111111111111111111111',
        MemoryPhoto.fromBytes(png),
        updatedAt: photoAt,
      );

      // A later entry PUT claims hasPhoto: false and a fresh photoUpdatedAt.
      // The server must keep the stored photo state (set above), not adopt
      // the incoming claim.
      final t1 = t0.add(const Duration(seconds: 2));
      final updated = await api.putEntry(
        entry(
          hasPhoto: false,
          photoUpdatedAt: t1,
          createdAt: t1,
          updatedAt: t1,
        ),
      );

      expect(updated.hasPhoto, isTrue);
      expect(updated.photoUpdatedAt, photoAt);
    });

    test('createdAt is kept from the existing row across an update', () async {
      final server = FakeSyncServer();
      final account = FakeAccountRepository(current: _account);
      final api = server.client(account);

      final firstCreated = DateTime.utc(2026, 9, 10, 8);
      await api.putEntry(entry(createdAt: firstCreated, updatedAt: firstCreated));

      final laterCreated = DateTime.utc(2026, 9, 13, 8);
      final t1 = firstCreated.add(const Duration(seconds: 1));
      final updated = await api.putEntry(
        entry(createdAt: laterCreated, updatedAt: t1),
      );

      expect(updated.createdAt, firstCreated);
    });

    test('a tombstone clears hasPhoto and photoUpdatedAt', () async {
      final server = FakeSyncServer();
      final account = FakeAccountRepository(current: _account);
      final api = server.client(account);

      final t0 = DateTime.utc(2026, 9, 13, 10);
      await api.putEntry(entry(createdAt: t0, updatedAt: t0));
      await api.putPhoto(
        '11111111111111111111111111111111',
        MemoryPhoto.fromBytes(png),
        updatedAt: t0.add(const Duration(seconds: 1)),
      );

      final t1 = t0.add(const Duration(seconds: 2));
      final tombstone = await api.putEntry(
        entry(createdAt: t0, updatedAt: t1, deleted: true),
      );

      expect(tombstone.hasPhoto, isFalse);
      expect(tombstone.photoUpdatedAt, isNull);
    });
  });

  group('FakeSyncServer.deletePhoto mirrors clearEntryPhoto', () {
    test('a successful clear stamps photoUpdatedAt with the request time, '
        'not null', () async {
      final server = FakeSyncServer();
      final account = FakeAccountRepository(current: _account);
      final api = server.client(account);

      final t0 = DateTime.utc(2026, 9, 13, 10);
      await api.putEntry(entry(createdAt: t0, updatedAt: t0));
      await api.putPhoto(
        '11111111111111111111111111111111',
        MemoryPhoto.fromBytes(png),
        updatedAt: t0.add(const Duration(seconds: 1)),
      );

      final clearAt = t0.add(const Duration(seconds: 2));
      final cleared = await api.deletePhoto(
        '11111111111111111111111111111111',
        updatedAt: clearAt,
      );

      expect(cleared.hasPhoto, isFalse);
      expect(cleared.photoUpdatedAt, clearAt);
    });
  });
}

final _account = syntheticAccount();
