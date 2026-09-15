import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zest/app/zest_app.dart';

import '../support/catalog_wiring.dart';
import '../support/in_memory_session.dart';
import '../support/load_fonts.dart';

void main() {
  setUpAll(loadZestFonts);

  testWidgets(
    'Botanical Play gallery and modal match reviewed mobile renders',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(412, 2200);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const capture = ValueKey('gallery-capture');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...sessionTestOverrides(),
            // The app-shell launch check (docs/M11.md finding #3) runs
            // unconditionally, so every ZestApp pump needs a catalog
            // repository that never touches the real on-device database.
            emptyCatalogRepositoryOverride(),
          ],
          child: const RepaintBoundary(
            key: capture,
            child: ZestApp(showGallery: true),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byKey(capture),
        matchesGoldenFile('goldens/botanical-gallery.png'),
      );

      tester.view.physicalSize = const Size(412, 915);
      await tester.pumpAndSettle();
      await expectLater(
        find.byKey(capture),
        matchesGoldenFile('goldens/botanical-mobile.png'),
      );

      final options = find.byKey(const ValueKey('open-options'));
      await tester.ensureVisible(options);
      await tester.pumpAndSettle();
      await tester.tap(options);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byKey(capture),
        matchesGoldenFile('goldens/botanical-sheet.png'),
      );
    },
  );
}
