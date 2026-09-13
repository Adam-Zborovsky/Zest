import '../../discovery/domain/recipe.dart';
import '../domain/collection_entry.dart';
import '../domain/memory_photo.dart';

/// The private collection store: a calendar of saved drinks and personal
/// variations, each with at most one memory photo. Everything stays on this
/// device; nothing here talks to a network, and export or backup is not part
/// of this contract.
///
/// Invariants every implementation must hold (the shared contract tests in
/// `test/support/collection_repository_contract.dart` check them):
///
/// - [saveRecipe] always creates a new saved entry dated to today, the local
///   calendar day of `now`. The same recipe may be saved on any number of
///   days, and any number of times on one day.
/// - [createVariation] always creates a new entry dated to today; one source
///   can have many variations, independent of whether it is saved.
/// - The stored source snapshot round-trips to an equal `Recipe.toJson`.
/// - [updateVariation] replaces only the variation details and bumps
///   `updatedAt`; it throws [StateError] for a missing id or a saved entry.
/// - [moveToDay] changes only the entry's day, normalized to a calendar day,
///   and bumps `updatedAt`; it throws [StateError] for a missing id.
/// - [delete] removes the entry and its photo together; deleting a missing
///   id is a no-op. Deleting one entry never deletes another entry, including
///   other saves or variations of the same recipe.
/// - [setPhoto] replaces any existing photo and sets `hasPhoto`; it throws
///   [StateError] for a missing id. [removePhoto] clears it and is a no-op
///   when there is none.
/// - Watch streams emit the current value immediately and again after every
///   change that affects them. [watchEntries] and [watchSavedEntriesFor]
///   order by day descending, then `updatedAt` descending, then id.
abstract interface class CollectionRepository {
  Stream<List<CollectionEntry>> watchEntries();

  /// The entry with [id], or null once it does not exist.
  Stream<CollectionEntry?> watchEntry(String id);

  /// Every saved (not variation) entry of one source recipe.
  Stream<List<CollectionEntry>> watchSavedEntriesFor(String sourceRecipeId);

  Future<CollectionEntry> saveRecipe(Recipe source);

  Future<CollectionEntry> createVariation(
    Recipe source,
    VariationDetails details,
  );

  Future<CollectionEntry> updateVariation(String id, VariationDetails details);

  Future<CollectionEntry> moveToDay(String id, DateTime day);

  Future<void> delete(String id);

  Future<void> setPhoto(String id, MemoryPhoto photo);

  Future<void> removePhoto(String id);

  Future<MemoryPhoto?> photo(String id);
}
