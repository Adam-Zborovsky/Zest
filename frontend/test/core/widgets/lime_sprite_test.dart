import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zest/core/design/zest_tokens.dart';
import 'package:zest/core/widgets/lime_sprite.dart';

import '../../support/load_fonts.dart';

/// A golden sheet of every [LimeSprite] pose, for visual comparison against
/// the approved character sheet (`lime-sheet.png`): all five poses at 96px
/// on the fennel page ground and on the night band, plus the wave pose at
/// 64px to prove the wedge still reads at micro size.
void main() {
  setUpAll(loadZestFonts);

  testWidgets('lime sprite sheet render', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(760, 420);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const capture = ValueKey('lime-sprite-sheet-capture');
    const poses = LimeSpritePose.values;

    Widget swatch(Color background, double size, List<LimeSpritePose> shown) => Container(
      color: background,
      padding: const EdgeInsets.all(12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final pose in shown)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: LimeSprite(pose: pose, size: size),
            ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: ZestPalette.fennel,
          body: Center(
            child: RepaintBoundary(
              key: capture,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  swatch(ZestPalette.fennel, 96, poses),
                  swatch(ZestPalette.night, 96, poses),
                  swatch(ZestPalette.fennel, 64, const [LimeSpritePose.wave]),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await expectLater(
      find.byKey(capture),
      matchesGoldenFile('goldens/lime-sprite-sheet.png'),
    );
  });
}
