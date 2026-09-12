import 'dart:typed_data';

/// Why a picked image cannot become a memory photo.
enum PhotoRejection { empty, tooLarge, unsupportedType }

final class PhotoRejected implements Exception {
  const PhotoRejected(this.reason);

  final PhotoRejection reason;

  /// Plain-language copy for the person, naming what to do next.
  String get message => switch (reason) {
    PhotoRejection.empty => 'That photo could not be read. Try another one.',
    PhotoRejection.tooLarge =>
      'That photo is too large to keep. Try a smaller one.',
    PhotoRejection.unsupportedType =>
      'Zest can keep JPEG, PNG, or WebP photos. Try another one.',
  };

  @override
  String toString() => 'PhotoRejected(${reason.name})';
}

/// One private memory photo, already downscaled by the picker. The bytes are
/// checked by content, not by file name: only JPEG, PNG, and WebP signatures
/// are accepted, and never more than [maxBytes].
final class MemoryPhoto {
  MemoryPhoto._(this.bytes, this.mimeType);

  factory MemoryPhoto.fromBytes(Uint8List bytes) {
    if (bytes.isEmpty) throw const PhotoRejected(PhotoRejection.empty);
    if (bytes.length > maxBytes) {
      throw const PhotoRejected(PhotoRejection.tooLarge);
    }
    final mimeType = sniffImageMimeType(bytes);
    if (mimeType == null) {
      throw const PhotoRejected(PhotoRejection.unsupportedType);
    }
    return MemoryPhoto._(Uint8List.fromList(bytes), mimeType);
  }

  /// Upper bound after downscaling. The picker targets about 1600 pixels on
  /// the long edge, which lands far below this for ordinary photos.
  static const maxBytes = 4 * 1024 * 1024;

  final Uint8List bytes;

  /// `image/jpeg`, `image/png`, or `image/webp`.
  final String mimeType;
}

/// Identifies JPEG, PNG, and WebP by their file signatures; null otherwise.
String? sniffImageMimeType(Uint8List bytes) {
  bool startsWith(List<int> signature, [int offset = 0]) {
    if (bytes.length < offset + signature.length) return false;
    for (var i = 0; i < signature.length; i++) {
      if (bytes[offset + i] != signature[i]) return false;
    }
    return true;
  }

  if (startsWith(const [0xFF, 0xD8, 0xFF])) return 'image/jpeg';
  if (startsWith(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])) {
    return 'image/png';
  }
  if (startsWith(const [0x52, 0x49, 0x46, 0x46]) &&
      startsWith(const [0x57, 0x45, 0x42, 0x50], 8)) {
    return 'image/webp';
  }
  return null;
}
