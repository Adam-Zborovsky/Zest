import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zest/app/zest_app.dart';
import 'package:zest/features/catalog/data/catalog_repository.dart';
import 'package:zest/features/discovery/domain/recipe.dart';

import '../../../support/catalog_fixtures.dart';
import '../../../support/catalog_wiring.dart';
import '../../../support/load_fonts.dart';

/// A synthetic collection shaped like a real bar: common ingredient names
/// with a skewed prevalence, so the golden shows every glyph group, label
/// collisions, and weighted lines. Invented recipes; no provider records.
List<Recipe> syntheticGardenRecipes() {
  const pantry = [
    'gin',
    'lime juice',
    'sugar syrup',
    'vodka',
    'lemon juice',
    'ice',
    'light rum',
    'mint leaf',
    'orange bitters',
    'triple sec',
    'soda water',
    'tequila',
    'grenadine',
    'orange juice',
    'sweet vermouth',
    'bourbon',
    'ginger',
    'honey',
    'campari',
    'egg white',
    'cucumber',
    'grapefruit juice',
  ];
  final random = math.Random(20260912);
  return [
    for (var i = 1; i <= 40; i++)
      () {
        final count = 3 + random.nextInt(3);
        final names = <String>{};
        while (names.length < count) {
          final skew = random.nextDouble() * random.nextDouble();
          names.add(pantry[(skew * pantry.length).floor()]);
        }
        return Recipe.fromJson(
          catalogRecipe(
            id: '8100${i.toString().padLeft(2, '0')}',
            name: 'Synthetic Garden $i',
            ingredients: [for (final name in names) (name, '1 oz')],
          ),
        );
      }(),
  ];
}

void main() {
  setUpAll(loadZestFonts);

  testWidgets('home-night-garden render', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(412, 1560);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final database = openInMemoryCatalog();
    addTearDown(database.close);
    await CatalogRepository(
      database: database,
      now: () => DateTime(2026, 9, 12, 10),
    ).upsertLetter('a', syntheticGardenRecipes());
    const capture = ValueKey('home-capture');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...catalogTestOverrides(
            database: database,
            source: FakeCatalogLetterSource(letters: {}),
          ),
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
      matchesGoldenFile('goldens/home-night-garden.png'),
    );
    final semantics = tester.ensureSemantics();
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    semantics.dispose();
  });
}
