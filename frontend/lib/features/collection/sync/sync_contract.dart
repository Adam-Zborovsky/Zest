import '../domain/collection_entry.dart';
import '../domain/memory_photo.dart';

/// One collection entry as it travels over the wire. See `docs/ACCOUNTS.md`.
///
/// A tombstone ([deleted] true) keeps identity, kind, source recipe id, day
/// and timestamps; [source] and [variation] are null and [hasPhoto] false.
final class EntryRecord {
  const EntryRecord({
    required this.id,
    required this.kind,
    required this.sourceRecipeId,
    required this.source,
    required this.variation,
    required this.day,
    required this.hasPhoto,
    required this.photoUpdatedAt,
    required this.createdAt,
    required this.updatedAt,
    required this.deleted,
    this.revision,
  });

  factory EntryRecord.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final kind = json['kind'];
    final sourceRecipeId = json['sourceRecipeId'];
    final source = json['source'];
    final variation = json['variation'];
    final day = json['day'];
    final hasPhoto = json['hasPhoto'];
    final photoUpdatedAt = json['photoUpdatedAt'];
    final deleted = json['deleted'];
    final revision = json['revision'];
    if (id is! String ||
        !_entryId.hasMatch(id) ||
        kind is! String ||
        sourceRecipeId is! String ||
        !_recipeId.hasMatch(sourceRecipeId) ||
        (source != null && source is! Map<String, Object?>) ||
        (variation != null && variation is! Map<String, Object?>) ||
        day is! String ||
        hasPhoto is! bool ||
        (photoUpdatedAt != null && photoUpdatedAt is! String) ||
        deleted is! bool ||
        (revision != null && revision is! int)) {
      throw const FormatException('Invalid entry record.');
    }
    final CollectionEntryKind parsedKind;
    try {
      parsedKind = CollectionEntryKind.values.byName(kind);
    } on ArgumentError {
      throw const FormatException('Invalid entry kind.');
    }
    parseCollectionDayKey(day);
    if (!deleted) {
      if (source == null) {
        throw const FormatException('A live entry needs its source.');
      }
      if ((parsedKind == CollectionEntryKind.variation) != (variation != null)) {
        throw const FormatException(
          'Variation details must be present exactly for variations.',
        );
      }
    }
    return EntryRecord(
      id: id,
      kind: parsedKind,
      sourceRecipeId: sourceRecipeId,
      source: source as Map<String, Object?>?,
      variation: variation as Map<String, Object?>?,
      day: day,
      hasPhoto: hasPhoto,
      photoUpdatedAt: photoUpdatedAt == null
          ? null
          : _parseTime(photoUpdatedAt as String),
      createdAt: _parseTime(json['createdAt']),
      updatedAt: _parseTime(json['updatedAt']),
      deleted: deleted,
      revision: revision as int?,
    );
  }

  final String id;
  final CollectionEntryKind kind;
  final String sourceRecipeId;

  /// The `Recipe.toJson()` snapshot; null only for a tombstone.
  final Map<String, Object?>? source;

  /// `VariationDetails.toJson()`; present exactly for a live variation.
  final Map<String, Object?>? variation;

  /// `YYYY-MM-DD`, see `collectionDayKey`.
  final String day;
  final bool hasPhoto;
  final DateTime? photoUpdatedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool deleted;

  /// Assigned by the server; null on a record the client is sending.
  final int? revision;

  /// The request body for `PUT /api/entries/:id`: never carries a revision.
  Map<String, Object?> toJson() => {
    'id': id,
    'kind': kind.name,
    'sourceRecipeId': sourceRecipeId,
    'source': source,
    'variation': variation,
    'day': day,
    'hasPhoto': hasPhoto,
    'photoUpdatedAt': photoUpdatedAt?.toUtc().toIso8601String(),
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'deleted': deleted,
  };

  static final _entryId = RegExp(r'^[0-9a-f]{32}$');
  static final _recipeId = RegExp(r'^[0-9]{1,20}$');

  static DateTime _parseTime(Object? value) {
    final parsed = value is String ? DateTime.tryParse(value) : null;
    if (parsed == null) throw const FormatException('Invalid timestamp.');
    return parsed.toUtc();
  }
}

/// One page of `GET /api/sync/entries`.
final class SyncPage {
  const SyncPage({
    required this.entries,
    required this.revision,
    required this.hasMore,
  });

  factory SyncPage.fromJson(Map<String, Object?> json) {
    final entries = json['entries'];
    final revision = json['revision'];
    final hasMore = json['hasMore'];
    if (entries is! List || revision is! int || revision < 0 || hasMore is! bool) {
      throw const FormatException('Invalid sync page.');
    }
    return SyncPage(
      entries: List.unmodifiable([
        for (final item in entries)
          if (item is Map<String, Object?>)
            EntryRecord.fromJson(item)
          else
            throw const FormatException('Invalid sync page entry.'),
      ]),
      revision: revision,
      hasMore: hasMore,
    );
  }

  /// In ascending revision order.
  final List<EntryRecord> entries;

  /// The last revision included, or the requested `since` when empty.
  final int revision;
  final bool hasMore;
}

/// The authenticated entry and photo endpoints. Implementations call
/// `AccountRepository.expireSession` on 401 and surface transport failures
/// so the sync engine can report [SyncPhase.offline].
abstract interface class SyncApi {
  Future<SyncPage> pull({required int since, int limit = 200});

  /// Returns the stored record after last-edit-wins resolution.
  Future<EntryRecord> putEntry(EntryRecord record);

  Future<EntryRecord> putPhoto(
    String entryId,
    MemoryPhoto photo, {
    required DateTime updatedAt,
  });

  Future<EntryRecord> deletePhoto(String entryId, {required DateTime updatedAt});

  /// Null when the entry has no photo.
  Future<MemoryPhoto?> getPhoto(String entryId);
}

enum SyncPhase { idle, syncing, offline, failed }

final class SyncStatus {
  const SyncStatus(this.phase, {this.lastSyncedAt});

  final SyncPhase phase;

  /// When a full pass last completed; null before the first.
  final DateTime? lastSyncedAt;

  @override
  bool operator ==(Object other) =>
      other is SyncStatus &&
      other.phase == phase &&
      other.lastSyncedAt == lastSyncedAt;

  @override
  int get hashCode => Object.hash(phase, lastSyncedAt);
}

/// The sync engine seam the profile sheet and app lifecycle use. A pass
/// pushes dirty entries and photo changes, then pulls until caught up. It
/// never throws for network failure; it reports it through [status].
abstract interface class CollectionSync {
  SyncStatus get status;

  /// Emits the current status immediately and after every change.
  Stream<SyncStatus> watchStatus();

  /// Runs one pass, or joins the pass already running.
  Future<void> syncNow();
}
