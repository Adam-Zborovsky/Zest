import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/collection_repository.dart';
import '../data/memory_photo_picker.dart';
import '../domain/collection_entry.dart';
import '../domain/memory_photo.dart';

/// The private collection store. The storage track replaces this body with
/// the drift-backed repository; tests override it with
/// `InMemoryCollectionRepository` from `test/support`.
final collectionRepositoryProvider = Provider<CollectionRepository>(
  (ref) => throw UnimplementedError(
    'M6 integration wires the drift-backed collection repository here.',
  ),
);

/// The photo picker. The photo track replaces this body with the
/// image_picker implementation; tests override it with `FakeMemoryPhotoPicker`.
final memoryPhotoPickerProvider = Provider<MemoryPhotoPicker>(
  (ref) => throw UnimplementedError(
    'M6 integration wires the image_picker memory photo picker here.',
  ),
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
