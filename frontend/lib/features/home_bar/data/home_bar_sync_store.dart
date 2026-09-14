import '../domain/home_bar_item.dart';
import '../sync/home_bar_sync_contract.dart';

/// A home-bar row plus the local-only dirty flag used by sync.
final class LocalHomeBarRecord {
  const LocalHomeBarRecord({required this.item, required this.dirty});

  final HomeBarItem item;
  final bool dirty;

  HomeBarRecord toRecord() => HomeBarRecord(
    ingredientId: item.ingredientId,
    displayName: item.displayName,
    location: item.location,
    updatedAt: item.updatedAt,
    deleted: item.deleted,
    revision: item.revision,
  );
}

/// Internal local-store seam for [HomeBarSyncEngine].
abstract interface class HomeBarSyncStore {
  Future<List<LocalHomeBarRecord>> dirtyRecords();
  Future<LocalHomeBarRecord?> localRecord(String ingredientId);

  /// Clears a pushed row only if it still matches the snapshot that was sent.
  /// This compare-and-apply must be atomic with the write.
  Future<bool> applyPushResultIfUnchanged({
    required HomeBarRecord sent,
    required HomeBarRecord returned,
  });

  /// Applies a pull atomically unless a same-time or newer dirty local edit
  /// has priority. Clean rows accept the server's revision-ordered result.
  Future<bool> applyPulledRecordIfAllowed(HomeBarRecord record);
  Future<void> restamp(String ingredientId, DateTime updatedAt);

  Future<String?> ownerUserId();
  Future<void> setOwnerUserId(String? userId);
  Future<int> lastRevision();
  Future<void> setLastRevision(int revision);

  /// Removes all home-bar cache rows and resets only the home-bar cursor.
  /// The owner remains until the sync engine assigns the newly signed-in user.
  Future<void> wipe();
}
