import '../domain/home_bar_item.dart';

/// Offline-first persistence for the durable home bar and shopping list.
///
/// Records are keyed by normalized ingredient identity. Implementations hide
/// tombstones from watches but retain them internally for synchronization.
abstract interface class HomeBarRepository {
  /// Current non-deleted items, ordered by display name then identity.
  Stream<List<HomeBarItem>> watchItems();

  /// Adds [displayName]'s catalog identity to the stocked bar. If it is on
  /// the shopping list it moves there in one write; a current stocked item
  /// is left untouched.
  Future<HomeBarItem> addToBar(String displayName);

  /// Adds [displayName]'s catalog identity to shopping. If it is stocked it
  /// moves there in one write; a current shopping item is left untouched.
  Future<HomeBarItem> addToShopping(String displayName);

  /// Hides an item while retaining a tombstone for sync. Missing and already
  /// deleted identities are idempotent no-ops.
  Future<void> remove(String ingredientId);
}
