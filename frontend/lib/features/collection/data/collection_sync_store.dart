import 'dart:convert';

import '../domain/collection_entry.dart';
import '../domain/memory_photo.dart';
import '../sync/sync_contract.dart';

/// One locally stored row as the sync engine needs to see it: the schema 3
/// flags plus enough of the row to build the wire [EntryRecord]. Internal to
/// the data layer and the sync engine; never exposed on [CollectionRepository].
final class LocalSyncRecord {
  const LocalSyncRecord({
    required this.id,
    required this.kind,
    required this.sourceRecipeId,
    required this.sourceJson,
    required this.variationJson,
    required this.day,
    required this.hasPhoto,
    required this.photoUpdatedAt,
    required this.createdAt,
    required this.updatedAt,
    required this.deleted,
    required this.dirty,
    required this.photoDirty,
  });

  final String id;
  final CollectionEntryKind kind;
  final String sourceRecipeId;

  /// The stored `Recipe.toJson()` snapshot. Always present locally, even for
  /// a tombstone (the row keeps its last known content); [toEntryRecord]
  /// nulls it out for the wire per the tombstone shape.
  final String sourceJson;
  final String? variationJson;
  final String day;
  final bool hasPhoto;
  final DateTime? photoUpdatedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool deleted;
  final bool dirty;
  final bool photoDirty;

  /// The `PUT /api/entries/:id` request body for this row.
  EntryRecord toEntryRecord() => EntryRecord(
    id: id,
    kind: kind,
    sourceRecipeId: sourceRecipeId,
    source: deleted
        ? null
        : jsonDecode(sourceJson) as Map<String, Object?>,
    variation: deleted || variationJson == null
        ? null
        : jsonDecode(variationJson!) as Map<String, Object?>,
    day: day,
    hasPhoto: deleted ? false : hasPhoto,
    photoUpdatedAt: deleted ? null : photoUpdatedAt,
    createdAt: createdAt,
    updatedAt: updatedAt,
    deleted: deleted,
  );
}

/// The internal seam the sync engine uses to read and write the local
/// collection database, kept off the public [CollectionRepository] interface.
/// `DriftCollectionRepository` implements this alongside `CollectionRepository`.
abstract interface class CollectionSyncStore {
  /// Every row with a pending push: [LocalSyncRecord.dirty] or
  /// [LocalSyncRecord.photoDirty], including tombstones.
  Future<List<LocalSyncRecord>> dirtyRecords();

  /// The row for [id] regardless of its `deleted` flag, or null when it does
  /// not exist locally. Used to compare against a pulled server record.
  Future<LocalSyncRecord?> localRecord(String id);

  /// The current photo bytes and their `updatedAt` for [id], or null when the
  /// entry has no local photo (a pending removal).
  Future<({MemoryPhoto photo, DateTime updatedAt})?> photoForSync(String id);

  /// Adopts a server-authoritative record: upserts the entry, clears `dirty`,
  /// and, when [clearPhotoDirty] is true, also clears `photoDirty`. Removes
  /// the local photo row when the record has no photo.
  Future<void> applyServerRecord(EntryRecord record, {bool clearPhotoDirty = false});

  /// Stores photo bytes fetched from the server for [id] without marking the
  /// row dirty.
  Future<void> setServerPhoto(String id, MemoryPhoto photo, DateTime updatedAt);

  /// Re-stamps entry [id]'s `updatedAt` to [updatedAt] (floored to strictly
  /// later than the row's current value, per [DriftCollectionRepository]'s
  /// `_laterThan` rule) without otherwise touching the row; `dirty` stays
  /// set. Used after a push's timestamp tie is rejected by the server (see
  /// `SyncEngine._push`), so the retried push strictly outraces the foreign
  /// write it tied with.
  Future<void> restampEntry(String id, DateTime updatedAt);

  /// The same re-stamp as [restampEntry], but for entry [id]'s photo row's
  /// `updatedAt`; `photoDirty` stays set. A no-op when the entry currently
  /// has no local photo row (the pending change was a photo delete, whose
  /// push timestamp is the entry's own `updatedAt` and is re-stamped via
  /// [restampEntry] instead).
  Future<void> restampPhoto(String id, DateTime updatedAt);

  Future<String?> ownerUserId();

  Future<void> setOwnerUserId(String? userId);

  Future<int> lastRevision();

  Future<void> setLastRevision(int revision);

  /// Erases every entry, photo, and the sync state's revision, but keeps
  /// [ownerUserId] untouched (the caller sets it right after).
  Future<void> wipe();
}
