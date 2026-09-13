import '../../discovery/domain/recipe.dart';
import '../data/collection_repository.dart';
import '../domain/collection_entry.dart';
import '../domain/memory_photo.dart';

/// Wraps a [CollectionRepository] so every write schedules a debounced sync
/// pass, per `docs/ACCOUNTS.md` ("Sync pass" runs "after local writes
/// (debounced by 2 seconds)"). Reads pass straight through.
final class SyncTriggeringCollectionRepository implements CollectionRepository {
  SyncTriggeringCollectionRepository(this._inner, {required void Function() onWrite})
    : _onWrite = onWrite;

  final CollectionRepository _inner;
  final void Function() _onWrite;

  @override
  Stream<List<CollectionEntry>> watchEntries() => _inner.watchEntries();

  @override
  Stream<CollectionEntry?> watchEntry(String id) => _inner.watchEntry(id);

  @override
  Stream<List<CollectionEntry>> watchSavedEntriesFor(String sourceRecipeId) =>
      _inner.watchSavedEntriesFor(sourceRecipeId);

  @override
  Future<MemoryPhoto?> photo(String id) => _inner.photo(id);

  @override
  Future<CollectionEntry> saveRecipe(Recipe source) =>
      _inner.saveRecipe(source).then(_touched);

  @override
  Future<CollectionEntry> createVariation(Recipe source, VariationDetails details) =>
      _inner.createVariation(source, details).then(_touched);

  @override
  Future<CollectionEntry> updateVariation(String id, VariationDetails details) =>
      _inner.updateVariation(id, details).then(_touched);

  @override
  Future<CollectionEntry> moveToDay(String id, DateTime day) =>
      _inner.moveToDay(id, day).then(_touched);

  @override
  Future<void> delete(String id) => _inner.delete(id).then(_touchedVoid);

  @override
  Future<void> setPhoto(String id, MemoryPhoto photo) =>
      _inner.setPhoto(id, photo).then(_touchedVoid);

  @override
  Future<void> removePhoto(String id) =>
      _inner.removePhoto(id).then(_touchedVoid);

  T _touched<T>(T value) {
    _onWrite();
    return value;
  }

  void _touchedVoid(void _) => _onWrite();
}
