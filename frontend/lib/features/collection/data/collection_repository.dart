import '../../discovery/domain/recipe.dart';
import '../domain/collection_entry.dart';
import '../domain/memory_photo.dart';

/// The private collection store: saved recipes, personal variations, and at
/// most one memory photo per entry. Everything stays on this device; nothing
/// here talks to a network, and export or backup is not part of this
/// contract.
///
/// Invariants every implementation must hold (the shared contract tests in
/// `test/support/collection_repository_contract.dart` check them):
///
/// - [saveRecipe] is idempotent per source recipe id: saving an already
///   saved recipe returns the existing entry unchanged, snapshot included.
/// - [createVariation] always creates a new entry; one source can have many
///   variations, independent of whether the source itself is saved.
/// - The stored source snapshot round-trips to an equal `Recipe.toJson`.
/// - [updateVariation] replaces only the variation details and bumps
///   `updatedAt`; it throws [StateError] for a missing id or a saved entry.
/// - [delete] removes the entry and its photo together; deleting a missing
///   id is a no-op. Deleting a saved recipe never deletes its variations.
/// - [setPhoto] replaces any existing photo and sets `hasPhoto`; it throws
///   [StateError] for a missing id. [removePhoto] clears it and is a no-op
///   when there is none.
/// - Watch streams emit the current value immediately and again after every
///   change that affects them. [watchEntries] orders by `updatedAt`
///   descending, then by id.
abstract interface class CollectionRepository {
  Stream<List<CollectionEntry>> watchEntries();

  /// The entry with [id], or null once it does not exist.
  Stream<CollectionEntry?> watchEntry(String id);

  /// The saved (not variation) entry for a source recipe id, or null.
  Stream<CollectionEntry?> watchSavedFor(String sourceRecipeId);

  Future<CollectionEntry> saveRecipe(Recipe source);

  Future<CollectionEntry> createVariation(
    Recipe source,
    VariationDetails details,
  );

  Future<CollectionEntry> updateVariation(String id, VariationDetails details);

  Future<void> delete(String id);

  Future<void> setPhoto(String id, MemoryPhoto photo);

  Future<void> removePhoto(String id);

  Future<MemoryPhoto?> photo(String id);
}
