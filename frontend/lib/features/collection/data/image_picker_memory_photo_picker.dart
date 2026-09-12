import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:image_picker/image_picker.dart';

import '../domain/memory_photo.dart';
import 'memory_photo_picker.dart';

/// Thrown when the platform refuses the pick itself (for example the person
/// denied camera or photo-library access, or no camera is available). The
/// contract's [PhotoRejected] is for bytes that were read but cannot be kept;
/// this is for the platform request never completing.
final class PhotoPickerUnavailable implements Exception {
  const PhotoPickerUnavailable(this.message);

  /// Plain-language copy naming what the person can do next.
  final String message;

  @override
  String toString() => 'PhotoPickerUnavailable($message)';
}

/// Matches [ImagePicker.pickImage] so tests can inject a fake without a
/// platform channel.
typedef PickImage =
    Future<XFile?> Function({
      required ImageSource source,
      double? maxWidth,
      double? maxHeight,
      int? imageQuality,
    });

/// Matches [ImagePicker.retrieveLostData] so tests can inject a scripted
/// response instead of hitting a platform channel.
typedef RetrieveLostData = Future<LostDataResponse> Function();

/// The long edge, in pixels, requested from the platform picker. The
/// contract downscales to about this size; [MemoryPhoto.maxBytes] is the
/// hard cap enforced after the bytes come back.
const _targetDimension = 1600.0;
const _targetQuality = 85;

/// [MemoryPhotoPicker] backed by `image_picker`.
///
/// `supportsCamera` is false on web: the web implementation offers camera
/// capture only through the HTML `capture` attribute on a file input, which
/// desktop browsers ignore outright (falling back to a plain file picker)
/// and mobile browsers implement inconsistently — there is no reliable,
/// documented way to guarantee a camera opens. Gallery selection is the
/// consistent option on web, so camera stays Android/iOS-only.
final class ImagePickerMemoryPhotoPicker implements MemoryPhotoPicker {
  ImagePickerMemoryPhotoPicker({
    PickImage? pickImage,
    RetrieveLostData? retrieveLostData,
    bool? isWeb,
  }) : _pickImage = pickImage ?? ImagePicker().pickImage,
       _retrieveLostData = retrieveLostData ?? ImagePicker().retrieveLostData,
       _isWeb = isWeb ?? kIsWeb;

  final PickImage _pickImage;
  final RetrieveLostData _retrieveLostData;
  final bool _isWeb;

  @override
  bool get supportsCamera => !_isWeb;

  @override
  Future<MemoryPhoto?> pick(PhotoSource source) async {
    final XFile? file;
    try {
      file = await _pickImage(
        source: switch (source) {
          PhotoSource.gallery => ImageSource.gallery,
          PhotoSource.camera => ImageSource.camera,
        },
        maxWidth: _targetDimension,
        maxHeight: _targetDimension,
        imageQuality: _targetQuality,
      );
    } on PlatformException catch (error) {
      throw _unavailable(source, error);
    }
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    return MemoryPhoto.fromBytes(bytes);
  }

  /// Recovers a photo lost when the Android host activity was destroyed
  /// mid-pick (low memory reclaiming the app while the picker or camera
  /// activity was in front). Always null on web, and null when nothing was
  /// lost. See the class doc for whether the screens track should call this.
  Future<MemoryPhoto?> recoverLostPhoto() async {
    if (_isWeb) return null;
    final LostDataResponse response;
    try {
      response = await _retrieveLostData();
    } on PlatformException catch (error) {
      throw _unavailable(null, error);
    }
    if (response.isEmpty) return null;
    final file = response.file;
    if (file == null) {
      final exception = response.exception;
      if (exception != null) throw _unavailable(null, exception);
      return null;
    }
    final bytes = await file.readAsBytes();
    return MemoryPhoto.fromBytes(bytes);
  }

  PhotoPickerUnavailable _unavailable(
    PhotoSource? source,
    PlatformException error,
  ) {
    final target = source == PhotoSource.camera
        ? 'the camera'
        : source == PhotoSource.gallery
        ? 'your photos'
        : 'that photo';
    return PhotoPickerUnavailable(
      'Zest could not reach $target. Check that photo and camera access is '
      'allowed for Zest in your device settings, then try again.',
    );
  }
}
