import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zest/app/zest_app.dart';
import 'package:zest/features/catalog/data/catalog_repository.dart';
import 'package:zest/features/catalog/data/catalog_snapshot_client.dart';
import 'package:zest/features/discovery/domain/recipe.dart';

import '../../../support/catalog_fixtures.dart';
import '../../../support/catalog_wiring.dart';
import '../../../support/collection_test_overrides.dart';
import '../../../support/in_memory_session.dart';
import '../../../support/load_fonts.dart';

/// A synthetic collection shaped like a real bar: 300 invented recipes over
/// common ingredient names with a skewed prevalence, so the bounded top-40
/// view is full and densely connected — the case where the constellation
/// used to clump. Invented recipes; no provider records.
List<Recipe> syntheticGardenRecipes() {
  const pantry = [
    'gin',
    'vodka',
    'lime juice',
    'sugar syrup',
    'lemon juice',
    'ice',
    'light rum',
    'orange juice',
    'triple sec',
    'grenadine',
    'angostura bitters',
    'soda water',
    'tequila',
    'mint leaf',
    'bourbon',
    'sweet vermouth',
    'pineapple juice',
    'cranberry juice',
    'dry vermouth',
    'amaretto',
    'brandy',
    'ginger ale',
    'milk',
    'coffee liqueur',
    'honey',
    'egg white',
    'campari',
    'dark rum',
    'cream',
    'apple juice',
    'orange bitters',
    'blue curacao',
    'grapefruit juice',
    'ginger',
    'cucumber',
    'tonic water',
    'cognac',
    'champagne',
    'cherry',
    'nutmeg',
    'coconut milk',
    'scotch',
    'basil',
    'agave syrup',
  ];
  final random = math.Random(20260912);
  return [
    for (var i = 1; i <= 300; i++)
      () {
        final count = 3 + random.nextInt(4);
        final names = <String>{};
        while (names.length < count) {
          final skew = random.nextDouble() * random.nextDouble();
          names.add(pantry[(skew * pantry.length).floor()]);
        }
        return Recipe.fromJson(
          catalogRecipe(
            id: '810${i.toString().padLeft(3, '0')}',
            name: 'Synthetic Garden $i',
            ingredients: [for (final name in names) (name, '1 oz')],
          ),
        );
      }(),
  ];
}

void main() {
  setUpAll(loadZestFonts);

  for (final specimen in const [
    (name: 'home-night-garden', size: Size(412, 1560)),
    (name: 'home-night-garden-desktop', size: Size(1040, 1240)),
  ]) {
    testWidgets('${specimen.name} render', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = specimen.size;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final database = openInMemoryCatalog();
      addTearDown(database.close);
      await CatalogRepository(
        database: database,
        now: () => DateTime(2026, 9, 12, 10),
      ).applySnapshot(
        catalogSnapshotFixture(
          version: fakeCatalogVersion('visual'),
          publishedAt: DateTime.utc(2026, 9, 12, 10),
          drinks: syntheticGardenRecipes(),
        ),
      );
      final fetcher = FakeCatalogSnapshotFetcher()
        ..enqueueAvailable(const CatalogSnapshotUnchanged());
      const capture = ValueKey('home-capture');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...catalogTestOverrides(database: database, fetcher: fetcher),
            ...collectionTestOverrides(),
            ...sessionTestOverrides(),
          ],
          child: const RepaintBoundary(key: capture, child: ZestApp()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byKey(capture),
        matchesGoldenFile('goldens/${specimen.name}.png'),
      );
      final semantics = tester.ensureSemantics();
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      semantics.dispose();
    });
  }
}
