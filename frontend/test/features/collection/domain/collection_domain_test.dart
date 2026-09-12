import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:zest/features/collection/domain/collection_entry.dart';
import 'package:zest/features/collection/domain/memory_photo.dart';
import 'package:zest/features/discovery/domain/recipe.dart';

import '../../../support/catalog_fixtures.dart';

void main() {
  final source = Recipe.fromJson(
    catalogRecipe(
      id: '98001',
      name: 'Testbench Tonic',
      ingredients: [('Invented syrup', '1 oz'), ('Pretend soda', null)],
    ),
  );

  group('VariationDetails', () {
    test('a draft from the source copies name, measures, and method', () {
      final draft = VariationDetails.fromSource(source);
      expect(draft.name, 'Testbench Tonic');
      expect(draft.ingredients.first.name, source.ingredients.first.name);
      expect(draft.ingredients.first.measure, '1 oz');
      expect(draft.ingredients.last.measure, '');
      expect(draft.method, source.instructions);
    });

    test('rejects a blank name and trims text', () {
      expect(
        () => VariationDetails(name: '   ', ingredients: const []),
        throwsFormatException,
      );
      final details = VariationDetails(
        name: '  Mine  ',
        ingredients: [VariationIngredient(name: ' Lime ', measure: ' 2 ')],
        notes: ' less sweet ',
      );
      expect(details.name, 'Mine');
      expect(
        details.ingredients.single,
        VariationIngredient(name: 'Lime', measure: '2'),
      );
      expect(details.notes, 'less sweet');
    });

    test('enforces length and count limits', () {
      expect(
        () => VariationDetails(
          name: 'x' * (VariationDetails.maxNameLength + 1),
          ingredients: const [],
        ),
        throwsFormatException,
      );
      expect(
        () => VariationDetails(
          name: 'Too many',
          ingredients: [
            for (var i = 0; i <= VariationDetails.maxIngredients; i++)
              VariationIngredient(name: 'Item $i'),
          ],
        ),
        throwsFormatException,
      );
    });

    test('round-trips through JSON', () {
      final details = VariationDetails(
        name: 'Mine',
        ingredients: [VariationIngredient(name: 'Lime', measure: '2 oz')],
        method: 'Shake.',
        notes: 'Less sweet.',
      );
      expect(VariationDetails.fromJson(details.toJson()), details);
    });
  });

  group('CollectionEntry', () {
    test('a variation shows its own name; a saved entry shows the source', () {
      final saved = CollectionEntry.saved(
        id: 'a',
        source: source,
        createdAt: DateTime(2026, 9, 13),
      );
      final variation = CollectionEntry.variation(
        id: 'b',
        source: source,
        details: VariationDetails(name: 'Mine', ingredients: const []),
        createdAt: DateTime(2026, 9, 13),
      );
      expect(saved.displayName, 'Testbench Tonic');
      expect(saved.isVariation, isFalse);
      expect(variation.displayName, 'Mine');
      expect(variation.sourceRecipeId, '98001');
      expect(
        () => saved.copyWith(
          variation: VariationDetails(name: 'No', ingredients: const []),
        ),
        throwsStateError,
      );
    });

    test('ids are 32 lowercase hex characters', () {
      final id = newCollectionEntryId(math.Random(1));
      expect(id, matches(RegExp(r'^[0-9a-f]{32}$')));
    });
  });

  group('MemoryPhoto', () {
    Uint8List bytes(List<int> head, [int padding = 16]) =>
        Uint8List.fromList([...head, ...List.filled(padding, 0)]);

    test('accepts JPEG, PNG, and WebP by content', () {
      expect(
        MemoryPhoto.fromBytes(bytes([0xFF, 0xD8, 0xFF])).mimeType,
        'image/jpeg',
      );
      expect(
        MemoryPhoto.fromBytes(
          bytes([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]),
        ).mimeType,
        'image/png',
      );
      expect(
        MemoryPhoto.fromBytes(
          bytes([0x52, 0x49, 0x46, 0x46, 0, 0, 0, 0, 0x57, 0x45, 0x42, 0x50]),
        ).mimeType,
        'image/webp',
      );
    });

    test('rejects empty, oversized, and unsupported images', () {
      expect(
        () => MemoryPhoto.fromBytes(Uint8List(0)),
        throwsA(
          isA<PhotoRejected>().having(
            (e) => e.reason,
            'reason',
            PhotoRejection.empty,
          ),
        ),
      );
      expect(
        () => MemoryPhoto.fromBytes(
          bytes([0xFF, 0xD8, 0xFF], MemoryPhoto.maxBytes),
        ),
        throwsA(
          isA<PhotoRejected>().having(
            (e) => e.reason,
            'reason',
            PhotoRejection.tooLarge,
          ),
        ),
      );
      expect(
        () => MemoryPhoto.fromBytes(bytes([0x47, 0x49, 0x46, 0x38])),
        throwsA(
          isA<PhotoRejected>().having(
            (e) => e.reason,
            'reason',
            PhotoRejection.unsupportedType,
          ),
        ),
      );
    });
  });
}
