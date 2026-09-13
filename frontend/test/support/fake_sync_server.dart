import 'package:zest/features/account/data/account_repository.dart';
import 'package:zest/features/collection/domain/memory_photo.dart';
import 'package:zest/features/collection/sync/sync_contract.dart';
import 'package:zest/features/collection/sync/sync_exceptions.dart';

/// An in-memory server backing zero or more [SyncApi] "devices", following
/// the rules of `docs/ACCOUNTS.md`: per-user revision counter, last-edit-wins
/// by `updatedAt`, final tombstones, and photo bytes keyed by entry.
///
/// Call [client] once per simulated device, each with its own
/// [AccountRepository] (so two clients sharing an account id simulate two
/// devices signed into the same account).
final class FakeSyncServer {
  final _users = <String, _UserRecords>{};
  final _revokedUserIds = <String>{};

  /// When true, every call from every client throws [SyncOfflineException].
  bool offline = false;

  void revokeSession(String userId) => _revokedUserIds.add(userId);

  void restoreSession(String userId) => _revokedUserIds.remove(userId);

  SyncApi client(AccountRepository account) => _FakeSyncApi(this, account);

  _UserRecords _recordsFor(String userId) =>
      _users.putIfAbsent(userId, () => _UserRecords());
}

class _StoredEntry {
  _StoredEntry(this.record, this.photo);

  EntryRecord record;
  MemoryPhoto? photo;
}

class _UserRecords {
  int revision = 0;
  final entries = <String, _StoredEntry>{};
}

final class _FakeSyncApi implements SyncApi {
  _FakeSyncApi(this._server, this._account);

  final FakeSyncServer _server;
  final AccountRepository _account;

  Future<String> _authorize() async {
    if (_server.offline) throw const SyncOfflineException();
    final id = _account.currentAccount?.id;
    if (id == null || _server._revokedUserIds.contains(id)) {
      await _account.expireSession();
      throw const SyncUnauthorizedException();
    }
    return id;
  }

  @override
  Future<SyncPage> pull({required int since, int limit = 200}) async {
    final userId = await _authorize();
    final records = _server._recordsFor(userId);
    final matching =
        records.entries.values
            .map((stored) => stored.record)
            .where((record) => record.revision! > since)
            .toList()
          ..sort((a, b) => a.revision!.compareTo(b.revision!));
    final page = matching.take(limit).toList();
    final hasMore = matching.length > page.length;
    final revision = page.isEmpty ? since : page.last.revision!;
    return SyncPage(entries: page, revision: revision, hasMore: hasMore);
  }

  @override
  Future<EntryRecord> putEntry(EntryRecord incoming) async {
    final userId = await _authorize();
    final records = _server._recordsFor(userId);
    final existing = records.entries[incoming.id];
    if (existing != null && existing.record.deleted) {
      // Tombstones are final.
      return existing.record;
    }
    if (existing == null || incoming.updatedAt.isAfter(existing.record.updatedAt)) {
      records.revision += 1;
      final stored = EntryRecord(
        id: incoming.id,
        kind: incoming.kind,
        sourceRecipeId: incoming.sourceRecipeId,
        source: incoming.deleted ? null : incoming.source,
        variation: incoming.deleted ? null : incoming.variation,
        day: incoming.day,
        hasPhoto: incoming.deleted ? false : incoming.hasPhoto,
        photoUpdatedAt: incoming.deleted ? null : incoming.photoUpdatedAt,
        createdAt: incoming.createdAt,
        updatedAt: incoming.updatedAt,
        deleted: incoming.deleted,
        revision: records.revision,
      );
      final photo = incoming.deleted ? null : existing?.photo;
      records.entries[incoming.id] = _StoredEntry(stored, photo);
      return stored;
    }
    return existing.record;
  }

  @override
  Future<EntryRecord> putPhoto(
    String entryId,
    MemoryPhoto photo, {
    required DateTime updatedAt,
  }) async {
    final userId = await _authorize();
    final records = _server._recordsFor(userId);
    final existing = records.entries[entryId];
    if (existing == null || existing.record.deleted) {
      throw const SyncApiException(404, 'not_found');
    }
    final currentPhotoUpdatedAt = existing.record.photoUpdatedAt;
    if (currentPhotoUpdatedAt == null || updatedAt.isAfter(currentPhotoUpdatedAt)) {
      records.revision += 1;
      existing.record = _withPhoto(
        existing.record,
        hasPhoto: true,
        photoUpdatedAt: updatedAt,
        revision: records.revision,
      );
      existing.photo = photo;
    }
    return existing.record;
  }

  @override
  Future<EntryRecord> deletePhoto(
    String entryId, {
    required DateTime updatedAt,
  }) async {
    final userId = await _authorize();
    final records = _server._recordsFor(userId);
    final existing = records.entries[entryId];
    if (existing == null || existing.record.deleted) {
      throw const SyncApiException(404, 'not_found');
    }
    final currentPhotoUpdatedAt = existing.record.photoUpdatedAt;
    if (currentPhotoUpdatedAt == null || updatedAt.isAfter(currentPhotoUpdatedAt)) {
      records.revision += 1;
      existing.record = _withPhoto(
        existing.record,
        hasPhoto: false,
        photoUpdatedAt: null,
        revision: records.revision,
      );
      existing.photo = null;
    }
    return existing.record;
  }

  @override
  Future<MemoryPhoto?> getPhoto(String entryId) async {
    final userId = await _authorize();
    final records = _server._recordsFor(userId);
    return records.entries[entryId]?.photo;
  }

  EntryRecord _withPhoto(
    EntryRecord record, {
    required bool hasPhoto,
    required DateTime? photoUpdatedAt,
    required int revision,
  }) => EntryRecord(
    id: record.id,
    kind: record.kind,
    sourceRecipeId: record.sourceRecipeId,
    source: record.source,
    variation: record.variation,
    day: record.day,
    hasPhoto: hasPhoto,
    photoUpdatedAt: photoUpdatedAt,
    createdAt: record.createdAt,
    updatedAt: record.updatedAt,
    deleted: record.deleted,
    revision: revision,
  );
}
