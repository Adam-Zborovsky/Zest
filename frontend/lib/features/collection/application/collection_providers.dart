import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../collection/sync/sync_providers.dart';
import '../data/collection_repository.dart';
import '../data/memory_photo_picker.dart';
import '../domain/collection_entry.dart';
import '../domain/memory_photo.dart';
import 'collection_photo_providers.dart';
import 'collection_storage_providers.dart';
import 'sync_triggering_collection_repository.dart';

/// The private collection store: the drift-backed repository over the
/// separate on-device `collection` database, wrapped so every write
/// schedules a debounced sync pass. Tests override it with
/// `InMemoryCollectionRepository` from `test/support`.
final collectionRepositoryProvider = Provider<CollectionRepository>((ref) {
  final inner = ref.watch(driftCollectionRepositoryProvider);
  return SyncTriggeringCollectionRepository(
    inner,
    onWrite: () => ref.read(collectionSyncProvider).scheduleAfterLocalWrite(),
  );
});

/// The photo picker: `image_picker` on web and Android. Tests override it
/// with `FakeMemoryPhotoPicker` from `test/support`.
final memoryPhotoPickerProvider = Provider<MemoryPhotoPicker>(
  (ref) => ref.watch(imagePickerMemoryPhotoPickerProvider),
);

final collectionEntriesProvider = StreamProvider<List<CollectionEntry>>(
  (ref) => ref.watch(collectionRepositoryProvider).watchEntries(),
  retry: (retryCount, error) => null,
);

final collectionEntryProvider = StreamProvider.family<CollectionEntry?, String>(
  (ref, id) => ref.watch(collectionRepositoryProvider).watchEntry(id),
  retry: (retryCount, error) => null,
);

/// Every saved entry of one source recipe, newest day first.
final savedEntriesForRecipeProvider =
    StreamProvider.family<List<CollectionEntry>, String>(
      (ref, sourceRecipeId) => ref
          .watch(collectionRepositoryProvider)
          .watchSavedEntriesFor(sourceRecipeId),
      retry: (retryCount, error) => null,
    );

/// Photo bytes for one entry. Rebuilds whenever that entry changes, so
/// adding, replacing, or removing a photo refreshes every view of it.
final memoryPhotoProvider = FutureProvider.family<MemoryPhoto?, String>((
  ref,
  id,
) async {
  final entry = await ref.watch(collectionEntryProvider(id).future);
  if (entry == null || !entry.hasPhoto) return null;
  return ref.watch(collectionRepositoryProvider).photo(id);
}, retry: (retryCount, error) => null);
