import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/collection_repository.dart';
import '../data/memory_photo_picker.dart';
import '../domain/collection_entry.dart';
import '../domain/memory_photo.dart';
import 'collection_photo_providers.dart';
import 'collection_storage_providers.dart';

/// The private collection store: the drift-backed repository over the
/// separate on-device `collection` database. Tests override it with
/// `InMemoryCollectionRepository` from `test/support`.
final collectionRepositoryProvider = Provider<CollectionRepository>(
  (ref) => ref.watch(driftCollectionRepositoryProvider),
);

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

final savedEntryForRecipeProvider =
    StreamProvider.family<CollectionEntry?, String>(
      (ref, sourceRecipeId) =>
          ref.watch(collectionRepositoryProvider).watchSavedFor(sourceRecipeId),
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
