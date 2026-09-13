import 'package:zest/features/collection/application/collection_providers.dart';
import 'package:zest/features/collection/data/collection_repository.dart';
import 'package:zest/features/collection/data/memory_photo_picker.dart';

import 'in_memory_collection_repository.dart';

/// Full provider overrides for any widget test that pumps `ZestApp` or a
/// screen watching collection providers: those contract providers throw
/// until M6 integration wires the real drift repository and image_picker
/// picker, so every such test injects the in-memory test doubles instead.
///
/// Typed `List<Override>`: Riverpod 3 does not export the `Override` type
/// name, so the list is dynamic and elements are checked when spread into a
/// `ProviderScope(overrides: [...])` literal — the same pattern
/// `test/support/catalog_wiring.dart` uses.
List<dynamic> collectionTestOverrides({
  CollectionRepository? repository,
  MemoryPhotoPicker? picker,
}) => [
  collectionRepositoryProvider.overrideWithValue(
    repository ?? InMemoryCollectionRepository(),
  ),
  memoryPhotoPickerProvider.overrideWithValue(
    picker ?? FakeMemoryPhotoPicker(),
  ),
];
