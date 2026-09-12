import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:zest/features/collection/data/image_picker_memory_photo_picker.dart';
import 'package:zest/features/collection/data/memory_photo_picker.dart';
import 'package:zest/features/collection/domain/memory_photo.dart';

/// A valid, decodable 1x1 PNG (synthetic, not a personal photo). Mirrors
/// `test/support/in_memory_collection_repository.dart`'s onePixelPng bytes.
Uint8List _onePixelPng() => Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41,
  0x54, 0x78, 0x9C, 0x63, 0x60, 0x00, 0x02, 0x00,
  0x00, 0x05, 0x00, 0x01, 0x7A, 0x5E, 0xAB, 0x3F,
  0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44,
  0xAE, 0x42, 0x60, 0x82,
]);

/// Only a JPEG signature, no valid trailing data — enough for content
/// sniffing to recognize it as JPEG.
Uint8List _jpegSignatureBytes() =>
    Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0, 0]);

Uint8List _unsupportedBytes() =>
    Uint8List.fromList([0x00, 0x01, 0x02, 0x03, 0x04]);

void main() {
  group('ImagePickerMemoryPhotoPicker.pick', () {
    late List<
      ({
        ImageSource source,
        double? maxWidth,
        double? maxHeight,
        int? imageQuality,
      })
    >
    calls;

    setUp(() {
      calls = [];
    });

    ImagePickerMemoryPhotoPicker makePicker({
      XFile? Function()? result,
      Object? throwing,
      bool isWeb = false,
    }) {
      return ImagePickerMemoryPhotoPicker(
        isWeb: isWeb,
        pickImage:
            ({
              required ImageSource source,
              double? maxWidth,
              double? maxHeight,
              int? imageQuality,
            }) async {
              calls.add((
                source: source,
                maxWidth: maxWidth,
                maxHeight: maxHeight,
                imageQuality: imageQuality,
              ));
              if (throwing != null) throw throwing;
              return result?.call();
            },
      );
    }

    test('maps gallery to ImageSource.gallery with 1600/1600/85', () async {
      final picker = makePicker(
        result: () => XFile.fromData(_onePixelPng(), mimeType: 'image/png'),
      );

      await picker.pick(PhotoSource.gallery);

      expect(calls, hasLength(1));
      expect(calls.single.source, ImageSource.gallery);
      expect(calls.single.maxWidth, 1600);
      expect(calls.single.maxHeight, 1600);
      expect(calls.single.imageQuality, 85);
    });

    test('maps camera to ImageSource.camera with 1600/1600/85', () async {
      final picker = makePicker(
        result: () => XFile.fromData(_onePixelPng(), mimeType: 'image/png'),
      );

      await picker.pick(PhotoSource.camera);

      expect(calls, hasLength(1));
      expect(calls.single.source, ImageSource.camera);
      expect(calls.single.maxWidth, 1600);
      expect(calls.single.maxHeight, 1600);
      expect(calls.single.imageQuality, 85);
    });

    test('cancellation (null XFile) returns null', () async {
      final picker = makePicker(result: () => null);

      final result = await picker.pick(PhotoSource.gallery);

      expect(result, isNull);
    });

    test('valid PNG bytes produce a MemoryPhoto with image/png', () async {
      final picker = makePicker(
        result: () => XFile.fromData(_onePixelPng(), mimeType: 'image/png'),
      );

      final photo = await picker.pick(PhotoSource.gallery);

      expect(photo, isNotNull);
      expect(photo!.mimeType, 'image/png');
      expect(photo.bytes, _onePixelPng());
    });

    test(
      'valid JPEG-signature bytes produce a MemoryPhoto with image/jpeg',
      () async {
        final picker = makePicker(
          result: () =>
              XFile.fromData(_jpegSignatureBytes(), mimeType: 'image/jpeg'),
        );

        final photo = await picker.pick(PhotoSource.gallery);

        expect(photo, isNotNull);
        expect(photo!.mimeType, 'image/jpeg');
      },
    );

    test('empty bytes throw PhotoRejected(empty)', () async {
      final picker = makePicker(result: () => XFile.fromData(Uint8List(0)));

      await expectLater(
        picker.pick(PhotoSource.gallery),
        throwsA(
          isA<PhotoRejected>().having(
            (e) => e.reason,
            'reason',
            PhotoRejection.empty,
          ),
        ),
      );
    });

    test('oversized bytes throw PhotoRejected(tooLarge)', () async {
      final oversized = Uint8List(MemoryPhoto.maxBytes + 1);
      // Valid PNG signature so it fails on size, not type.
      oversized.setRange(0, 8, const [
        0x89,
        0x50,
        0x4E,
        0x47,
        0x0D,
        0x0A,
        0x1A,
        0x0A,
      ]);
      final picker = makePicker(result: () => XFile.fromData(oversized));

      await expectLater(
        picker.pick(PhotoSource.gallery),
        throwsA(
          isA<PhotoRejected>().having(
            (e) => e.reason,
            'reason',
            PhotoRejection.tooLarge,
          ),
        ),
      );
    });

    test(
      'unsupported-type bytes throw PhotoRejected(unsupportedType)',
      () async {
        final picker = makePicker(
          result: () => XFile.fromData(_unsupportedBytes()),
        );

        await expectLater(
          picker.pick(PhotoSource.gallery),
          throwsA(
            isA<PhotoRejected>().having(
              (e) => e.reason,
              'reason',
              PhotoRejection.unsupportedType,
            ),
          ),
        );
      },
    );

    test(
      'PlatformException from the picker becomes PhotoPickerUnavailable',
      () async {
        final picker = makePicker(
          throwing: PlatformException(code: 'camera_access_denied'),
        );

        await expectLater(
          picker.pick(PhotoSource.camera),
          throwsA(
            isA<PhotoPickerUnavailable>().having(
              (e) => e.message,
              'message',
              isNotEmpty,
            ),
          ),
        );
      },
    );

    test('supportsCamera is false when isWeb is true', () {
      final picker = makePicker(isWeb: true);
      expect(picker.supportsCamera, isFalse);
    });

    test('supportsCamera is true when isWeb is false', () {
      final picker = makePicker(isWeb: false);
      expect(picker.supportsCamera, isTrue);
    });
  });

  group('ImagePickerMemoryPhotoPicker.recoverLostPhoto', () {
    test('returns null on web without calling retrieveLostData', () async {
      var called = false;
      final picker = ImagePickerMemoryPhotoPicker(
        isWeb: true,
        pickImage:
            ({
              required ImageSource source,
              double? maxWidth,
              double? maxHeight,
              int? imageQuality,
            }) async => null,
        retrieveLostData: () async {
          called = true;
          return LostDataResponse.empty();
        },
      );

      final result = await picker.recoverLostPhoto();

      expect(result, isNull);
      expect(called, isFalse);
    });

    test('returns null on Android when nothing was lost', () async {
      final picker = ImagePickerMemoryPhotoPicker(
        isWeb: false,
        pickImage:
            ({
              required ImageSource source,
              double? maxWidth,
              double? maxHeight,
              int? imageQuality,
            }) async => null,
        retrieveLostData: () async => LostDataResponse.empty(),
      );

      final result = await picker.recoverLostPhoto();

      expect(result, isNull);
    });

    test(
      'returns a MemoryPhoto on Android when a photo was recovered',
      () async {
        final picker = ImagePickerMemoryPhotoPicker(
          isWeb: false,
          pickImage:
              ({
                required ImageSource source,
                double? maxWidth,
                double? maxHeight,
                int? imageQuality,
              }) async => null,
          retrieveLostData: () async => LostDataResponse(
            file: XFile.fromData(_onePixelPng(), mimeType: 'image/png'),
          ),
        );

        final result = await picker.recoverLostPhoto();

        expect(result, isNotNull);
        expect(result!.mimeType, 'image/png');
      },
    );

    test(
      'PlatformException from retrieveLostData becomes PhotoPickerUnavailable',
      () async {
        final picker = ImagePickerMemoryPhotoPicker(
          isWeb: false,
          pickImage:
              ({
                required ImageSource source,
                double? maxWidth,
                double? maxHeight,
                int? imageQuality,
              }) async => null,
          retrieveLostData: () async =>
              throw PlatformException(code: 'lost_data_error'),
        );

        await expectLater(
          picker.recoverLostPhoto(),
          throwsA(isA<PhotoPickerUnavailable>()),
        );
      },
    );
  });
}
