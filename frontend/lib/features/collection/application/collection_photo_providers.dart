import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/image_picker_memory_photo_picker.dart';
import '../data/memory_photo_picker.dart';

/// The real, `image_picker`-backed [MemoryPhotoPicker]. Integration wires
/// this into `memoryPhotoPickerProvider` from `collection_providers.dart`.
final imagePickerMemoryPhotoPickerProvider =
    Provider<ImagePickerMemoryPhotoPicker>(
      (ref) => ImagePickerMemoryPhotoPicker(),
    );
