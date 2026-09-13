import 'package:zest/features/collection/data/collection_repository.dart';
import 'package:zest/features/collection/domain/collection_entry.dart';
import 'package:zest/features/collection/domain/memory_photo.dart';
import 'package:zest/features/discovery/domain/recipe.dart';

/// Wraps a working [CollectionRepository] and fails chosen writes on demand,
/// so screen tests can prove every storage failure is stated to the person
/// instead of being dropped. Reads always pass through.
final class FailingCollectionRepository implements CollectionRepository {
  FailingCollectionRepository(this.inner);

  final CollectionRepository inner;

  bool failSave = false;
  bool failVariation = false;
  bool failDelete = false;
  bool failSetPhoto = false;
  bool failRemovePhoto = false;

  Never _fail() => throw StateError('Simulated storage failure.');

  @override
  Stream<List<CollectionEntry>> watchEntries() => inner.watchEntries();

  @override
  Stream<CollectionEntry?> watchEntry(String id) => inner.watchEntry(id);

  @override
  Stream<CollectionEntry?> watchSavedFor(String sourceRecipeId) =>
      inner.watchSavedFor(sourceRecipeId);

  @override
  Future<CollectionEntry> saveRecipe(Recipe source) async =>
      failSave ? _fail() : inner.saveRecipe(source);

  @override
  Future<CollectionEntry> createVariation(
    Recipe source,
    VariationDetails details,
  ) async => failVariation ? _fail() : inner.createVariation(source, details);

  @override
  Future<CollectionEntry> updateVariation(
    String id,
    VariationDetails details,
  ) async => failVariation ? _fail() : inner.updateVariation(id, details);

  @override
  Future<void> delete(String id) async =>
      failDelete ? _fail() : inner.delete(id);

  @override
  Future<void> setPhoto(String id, MemoryPhoto photo) async =>
      failSetPhoto ? _fail() : inner.setPhoto(id, photo);

  @override
  Future<void> removePhoto(String id) async =>
      failRemovePhoto ? _fail() : inner.removePhoto(id);

  @override
  Future<MemoryPhoto?> photo(String id) => inner.photo(id);
}
