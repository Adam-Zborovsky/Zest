import 'dart:convert';

import 'package:drift/drift.dart';

import '../../discovery/domain/recipe.dart';
import '../domain/collection_entry.dart';
import '../domain/memory_photo.dart';
import '../sync/sync_contract.dart';
import 'collection_database.dart';
import 'collection_repository.dart';
import 'collection_sync_store.dart';

/// Drift-backed [CollectionRepository]. See the interface doc for the
/// invariants this implementation holds; the shared contract suite in
/// `test/support/collection_repository_contract.dart` checks them.
///
/// Also implements [CollectionSyncStore], the internal seam `SyncEngine`
/// uses to read and write the schema 3 sync flags (`dirty`, `deleted`,
/// `photoDirty`) and the `sync_state` row. Every write here marks the row
/// dirty (and, for photo writes, `photoDirty`); reads hide `deleted` rows.
final class DriftCollectionRepository
    implements CollectionRepository, CollectionSyncStore {
  DriftCollectionRepository({
    required CollectionDatabase database,
    DateTime Function()? now,
    String Function()? newId,
  }) : _database = database,
       _now = now ?? DateTime.now,
       _newId = newId ?? newCollectionEntryId;

  final CollectionDatabase _database;
  final DateTime Function() _now;
  final String Function() _newId;

  /// The timestamp for a write that touches a row last stamped [previous]:
  /// `max(now, previous + 1ms)`. Guarantees every local write strictly
  /// advances the compared timestamp even when the clock reads the same
  /// value twice in a row (a stopped test clock, or two writes within the
  /// same millisecond), so the sync engine's last-edit-wins comparisons
  /// never see a tie against a row's own history. [previous] is null for a
  /// brand-new row, where there is nothing to advance past.
  DateTime _laterThan(DateTime? previous) {
    final now = _now();
    if (previous == null) return now;
    final floor = previous.add(const Duration(milliseconds: 1));
    return now.isAfter(floor) ? now : floor;
  }

  SimpleSelectStatement<$EntriesTable, Entry> _ordered(
    Expression<bool> Function($EntriesTable t)? filter,
  ) {
    final query = _database.select(_database.entries)
      ..where((t) => t.deleted.equals(false));
    if (filter != null) query.where(filter);
    return query..orderBy([
      (t) => OrderingTerm.desc(t.day),
      (t) => OrderingTerm.desc(t.updatedAt),
      (t) => OrderingTerm.asc(t.id),
    ]);
  }

  @override
  Stream<List<CollectionEntry>> watchEntries() => _ordered(
    null,
  ).watch().map((rows) => List.unmodifiable(rows.map(_mapRow)));

  @override
  Stream<CollectionEntry?> watchEntry(String id) {
    final query = _database.select(_database.entries)
      ..where((t) => t.id.equals(id) & t.deleted.equals(false));
    return query.watchSingleOrNull().map(
      (row) => row == null ? null : _mapRow(row),
    );
  }

  @override
  Stream<List<CollectionEntry>> watchSavedEntriesFor(String sourceRecipeId) =>
      _ordered(
        (t) =>
            t.sourceRecipeId.equals(sourceRecipeId) &
            t.kind.equalsValue(CollectionEntryKind.saved),
      ).watch().map((rows) => List.unmodifiable(rows.map(_mapRow)));

  @override
  Future<CollectionEntry> saveRecipe(Recipe source) async {
    final now = _now();
    final id = _newId();
    await _database
        .into(_database.entries)
        .insert(
          EntriesCompanion.insert(
            id: id,
            kind: CollectionEntryKind.saved,
            sourceRecipeId: source.id,
            sourceJson: jsonEncode(source.toJson()),
            day: Value(collectionDayKey(collectionDay(now))),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return CollectionEntry.saved(
      id: id,
      source: source,
      day: now,
      createdAt: now,
      updatedAt: now,
    );
  }

  @override
  Future<CollectionEntry> createVariation(
    Recipe source,
    VariationDetails details,
  ) async {
    final now = _now();
    final id = _newId();
    await _database
        .into(_database.entries)
        .insert(
          EntriesCompanion.insert(
            id: id,
            kind: CollectionEntryKind.variation,
            sourceRecipeId: source.id,
            sourceJson: jsonEncode(source.toJson()),
            variationJson: Value(jsonEncode(details.toJson())),
            day: Value(collectionDayKey(collectionDay(now))),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return CollectionEntry.variation(
      id: id,
      source: source,
      details: details,
      day: now,
      createdAt: now,
      updatedAt: now,
    );
  }

  @override
  Future<CollectionEntry> updateVariation(String id, VariationDetails details) {
    return _database.transaction(() async {
      final row = await _entryRow(id);
      if (row == null) throw StateError('No collection entry $id.');
      if (row.kind != CollectionEntryKind.variation) {
        throw StateError('Collection entry $id is not a variation.');
      }
      await (_database.update(
        _database.entries,
      )..where((t) => t.id.equals(id))).write(
        EntriesCompanion(
          variationJson: Value(jsonEncode(details.toJson())),
          updatedAt: Value(_laterThan(row.updatedAt)),
          dirty: const Value(true),
        ),
      );
      return _mapRow((await _entryRow(id))!);
    });
  }

  @override
  Future<CollectionEntry> moveToDay(String id, DateTime day) {
    return _database.transaction(() async {
      final row = await _entryRow(id);
      if (row == null) throw StateError('No collection entry $id.');
      await (_database.update(
        _database.entries,
      )..where((t) => t.id.equals(id))).write(
        EntriesCompanion(
          day: Value(collectionDayKey(collectionDay(day))),
          updatedAt: Value(_laterThan(row.updatedAt)),
          dirty: const Value(true),
        ),
      );
      return _mapRow((await _entryRow(id))!);
    });
  }

  @override
  Future<void> delete(String id) {
    return _database.transaction(() async {
      final row = await _entryRow(id);
      if (row == null || row.deleted) return;
      await (_database.delete(
        _database.photos,
      )..where((t) => t.entryId.equals(id))).go();
      await (_database.update(
        _database.entries,
      )..where((t) => t.id.equals(id))).write(
        EntriesCompanion(
          deleted: const Value(true),
          dirty: const Value(true),
          photoDirty: const Value(false),
          hasPhoto: const Value(false),
          updatedAt: Value(_laterThan(row.updatedAt)),
        ),
      );
    });
  }

  @override
  Future<void> setPhoto(String id, MemoryPhoto photo) {
    return _database.transaction(() async {
      final row = await _entryRow(id);
      if (row == null) throw StateError('No collection entry $id.');
      final existingPhoto = await (_database.select(
        _database.photos,
      )..where((t) => t.entryId.equals(id))).getSingleOrNull();
      final photoUpdatedAt = _laterThan(existingPhoto?.updatedAt);
      await _database
          .into(_database.photos)
          .insertOnConflictUpdate(
            PhotosCompanion.insert(
              entryId: id,
              mimeType: photo.mimeType,
              bytes: photo.bytes,
              updatedAt: photoUpdatedAt,
            ),
          );
      await (_database.update(
        _database.entries,
      )..where((t) => t.id.equals(id))).write(
        EntriesCompanion(
          hasPhoto: const Value(true),
          updatedAt: Value(_laterThan(row.updatedAt)),
          dirty: const Value(true),
          photoDirty: const Value(true),
        ),
      );
    });
  }

  @override
  Future<void> removePhoto(String id) {
    return _database.transaction(() async {
      final row = await _entryRow(id);
      final deletedCount = await (_database.delete(
        _database.photos,
      )..where((t) => t.entryId.equals(id))).go();
      if (deletedCount == 0 || row == null) return;
      await (_database.update(
        _database.entries,
      )..where((t) => t.id.equals(id))).write(
        EntriesCompanion(
          hasPhoto: const Value(false),
          updatedAt: Value(_laterThan(row.updatedAt)),
          dirty: const Value(true),
          photoDirty: const Value(true),
        ),
      );
    });
  }

  @override
  Future<MemoryPhoto?> photo(String id) async {
    final row = await (_database.select(
      _database.photos,
    )..where((t) => t.entryId.equals(id))).getSingleOrNull();
    if (row == null) return null;
    return MemoryPhoto.fromBytes(row.bytes);
  }

  Future<Entry?> _entryRow(String id) => (_database.select(
    _database.entries,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Rehydrates a stored row into a [CollectionEntry]. The source snapshot,
  /// the day, and for a variation the variation details are parsed here;
  /// malformed stored data throws a clear [FormatException] naming the entry
  /// instead of surfacing as a silently empty or misdated entry.
  CollectionEntry _mapRow(Entry row) {
    final Recipe source;
    try {
      source = Recipe.fromJson(
        jsonDecode(row.sourceJson) as Map<String, dynamic>,
      );
    } catch (error) {
      throw FormatException(
        'Malformed source snapshot for collection entry ${row.id}: $error',
      );
    }
    final DateTime day;
    try {
      day = parseCollectionDayKey(row.day);
    } on FormatException catch (error) {
      throw FormatException(
        'Malformed day for collection entry ${row.id}: ${error.message}',
      );
    }
    switch (row.kind) {
      case CollectionEntryKind.saved:
        return CollectionEntry.saved(
          id: row.id,
          source: source,
          day: day,
          createdAt: row.createdAt,
          updatedAt: row.updatedAt,
          hasPhoto: row.hasPhoto,
        );
      case CollectionEntryKind.variation:
        final variationJson = row.variationJson;
        if (variationJson == null) {
          throw FormatException(
            'Collection entry ${row.id} is a variation with no variation '
            'details.',
          );
        }
        final VariationDetails details;
        try {
          details = VariationDetails.fromJson(
            jsonDecode(variationJson) as Map<String, dynamic>,
          );
        } catch (error) {
          throw FormatException(
            'Malformed variation details for collection entry ${row.id}: '
            '$error',
          );
        }
        return CollectionEntry.variation(
          id: row.id,
          source: source,
          details: details,
          day: day,
          createdAt: row.createdAt,
          updatedAt: row.updatedAt,
          hasPhoto: row.hasPhoto,
        );
    }
  }

  // --- CollectionSyncStore -------------------------------------------------

  @override
  Future<List<LocalSyncRecord>> dirtyRecords() async {
    final rows = await (_database.select(
      _database.entries,
    )..where((t) => t.dirty.equals(true) | t.photoDirty.equals(true))).get();
    final records = <LocalSyncRecord>[];
    for (final row in rows) {
      records.add(await _toLocalSyncRecord(row));
    }
    return records;
  }

  @override
  Future<LocalSyncRecord?> localRecord(String id) async {
    final row = await _entryRow(id);
    if (row == null) return null;
    return _toLocalSyncRecord(row);
  }

  Future<LocalSyncRecord> _toLocalSyncRecord(Entry row) async {
    DateTime? photoUpdatedAt;
    if (row.hasPhoto) {
      final photoRow = await (_database.select(
        _database.photos,
      )..where((t) => t.entryId.equals(row.id))).getSingleOrNull();
      photoUpdatedAt = photoRow?.updatedAt;
    }
    return LocalSyncRecord(
      id: row.id,
      kind: row.kind,
      sourceRecipeId: row.sourceRecipeId,
      sourceJson: row.sourceJson,
      variationJson: row.variationJson,
      day: row.day,
      hasPhoto: row.hasPhoto,
      photoUpdatedAt: photoUpdatedAt,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      deleted: row.deleted,
      dirty: row.dirty,
      photoDirty: row.photoDirty,
    );
  }

  @override
  Future<({MemoryPhoto photo, DateTime updatedAt})?> photoForSync(
    String id,
  ) async {
    final row = await (_database.select(
      _database.photos,
    )..where((t) => t.entryId.equals(id))).getSingleOrNull();
    if (row == null) return null;
    return (photo: MemoryPhoto.fromBytes(row.bytes), updatedAt: row.updatedAt);
  }

  @override
  Future<void> applyServerRecord(
    EntryRecord record, {
    bool clearPhotoDirty = false,
  }) {
    return _database.transaction(() async {
      final existing = await _entryRow(record.id);
      // A local photo change not yet pushed (`photoDirty`) must survive an
      // apply that is not itself the photo push's own resolution. `record`
      // here can come from an entry PUT response or a pull, and on the real
      // server photo state is not client-authoritative on the entry route:
      // `upsertEntry` in `backend/src/accounts/repository.ts` carries
      // `hasPhoto`/`photoUpdatedAt` over from the existing row regardless of
      // what was sent. Adopting `record.hasPhoto == false` here while a
      // local photo add is still queued would delete the not-yet-pushed
      // photo bytes and misreport the entry as photo-less before
      // `_pushPhoto` ever runs. Only `_pushPhoto`'s own success
      // (`clearPhotoDirty: true`) or a tombstone (which removes the photo
      // unconditionally, per `docs/ACCOUNTS.md`) may touch the local photo
      // state here.
      final keepLocalPhoto =
          !clearPhotoDirty && !record.deleted && (existing?.photoDirty ?? false);

      await _database
          .into(_database.entries)
          .insertOnConflictUpdate(
            EntriesCompanion.insert(
              id: record.id,
              kind: record.kind,
              sourceRecipeId: record.sourceRecipeId,
              sourceJson: record.deleted ? '{}' : jsonEncode(record.source),
              variationJson: record.variation == null
                  ? const Value.absent()
                  : Value(jsonEncode(record.variation)),
              day: Value(record.day),
              hasPhoto: keepLocalPhoto
                  ? Value(existing!.hasPhoto)
                  : Value(record.hasPhoto),
              createdAt: record.createdAt,
              updatedAt: record.updatedAt,
              deleted: Value(record.deleted),
              dirty: const Value(false),
              photoDirty: clearPhotoDirty
                  ? const Value(false)
                  : const Value.absent(),
            ),
          );
      // Keep an existing variation snapshot when the server omitted one but
      // the row is not actually a variation switch; a live variation always
      // carries its own variationJson from the server, so this only matters
      // for a tombstone, where we intentionally clear it.
      if (record.deleted || record.variation == null) {
        await (_database.update(
          _database.entries,
        )..where((t) => t.id.equals(record.id))).write(
          const EntriesCompanion(variationJson: Value(null)),
        );
      }
      if (!record.hasPhoto && !keepLocalPhoto) {
        await (_database.delete(
          _database.photos,
        )..where((t) => t.entryId.equals(record.id))).go();
      }
    });
  }

  @override
  Future<void> restampEntry(String id, DateTime updatedAt) async {
    final row = await _entryRow(id);
    if (row == null) return;
    final next = updatedAt.isAfter(row.updatedAt)
        ? updatedAt
        : row.updatedAt.add(const Duration(milliseconds: 1));
    await (_database.update(
      _database.entries,
    )..where((t) => t.id.equals(id))).write(
      EntriesCompanion(updatedAt: Value(next), dirty: const Value(true)),
    );
  }

  @override
  Future<void> restampPhoto(String id, DateTime updatedAt) async {
    final photoRow = await (_database.select(
      _database.photos,
    )..where((t) => t.entryId.equals(id))).getSingleOrNull();
    if (photoRow == null) return;
    final next = updatedAt.isAfter(photoRow.updatedAt)
        ? updatedAt
        : photoRow.updatedAt.add(const Duration(milliseconds: 1));
    await (_database.update(
      _database.photos,
    )..where((t) => t.entryId.equals(id))).write(
      PhotosCompanion(updatedAt: Value(next)),
    );
    await (_database.update(
      _database.entries,
    )..where((t) => t.id.equals(id))).write(
      const EntriesCompanion(photoDirty: Value(true)),
    );
  }

  @override
  Future<void> setServerPhoto(
    String id,
    MemoryPhoto photo,
    DateTime updatedAt,
  ) async {
    await _database
        .into(_database.photos)
        .insertOnConflictUpdate(
          PhotosCompanion.insert(
            entryId: id,
            mimeType: photo.mimeType,
            bytes: photo.bytes,
            updatedAt: updatedAt,
          ),
        );
  }

  Future<SyncStateData> _syncStateRow() async {
    final existing = await (_database.select(
      _database.syncState,
    )..where((t) => t.id.equals(0))).getSingleOrNull();
    if (existing != null) return existing;
    await _database
        .into(_database.syncState)
        .insertOnConflictUpdate(const SyncStateCompanion(id: Value(0)));
    return (_database.select(
      _database.syncState,
    )..where((t) => t.id.equals(0))).getSingle();
  }

  @override
  Future<String?> ownerUserId() async => (await _syncStateRow()).ownerUserId;

  @override
  Future<void> setOwnerUserId(String? userId) async {
    await _syncStateRow();
    await (_database.update(
      _database.syncState,
    )..where((t) => t.id.equals(0))).write(
      SyncStateCompanion(ownerUserId: Value(userId)),
    );
  }

  @override
  Future<int> lastRevision() async => (await _syncStateRow()).lastRevision;

  @override
  Future<void> setLastRevision(int revision) async {
    await _syncStateRow();
    await (_database.update(
      _database.syncState,
    )..where((t) => t.id.equals(0))).write(
      SyncStateCompanion(lastRevision: Value(revision)),
    );
  }

  @override
  Future<void> wipe() {
    return _database.transaction(() async {
      await _database.delete(_database.photos).go();
      await _database.delete(_database.entries).go();
      await _syncStateRow();
      await (_database.update(
        _database.syncState,
      )..where((t) => t.id.equals(0))).write(
        const SyncStateCompanion(lastRevision: Value(0)),
      );
    });
  }
}
