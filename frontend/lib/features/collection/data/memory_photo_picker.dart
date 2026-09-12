import '../domain/memory_photo.dart';

enum PhotoSource { gallery, camera }

/// Picks one memory photo for an entry. Permissions are requested only here,
/// at the moment the person chooses to add a photo — never earlier.
abstract interface class MemoryPhotoPicker {
  /// Whether [PhotoSource.camera] is offered on this platform.
  bool get supportsCamera;

  /// A validated photo downscaled to about 1600 pixels on the long edge, or
  /// null when the person cancels. Throws [PhotoRejected] when the picked
  /// image cannot be kept.
  Future<MemoryPhoto?> pick(PhotoSource source);
}
