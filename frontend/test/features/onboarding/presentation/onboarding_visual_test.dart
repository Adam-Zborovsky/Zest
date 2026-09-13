import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/in_memory_session.dart';
import '../../../support/load_fonts.dart';
import 'onboarding_test_harness.dart';

/// Pages 1-4 of the onboarding flow at a common phone size, matching the
/// golden pattern in
/// `test/features/constellation/presentation/home_visual_test.dart`.
void main() {
  setUpAll(loadZestFonts);

  for (final page in [1, 2, 3, 4]) {
    testWidgets('onboarding-page$page render', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(412, 915);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const capture = ValueKey('onboarding-capture');
      await pumpOnboardingApp(
        tester,
        overrides: sessionTestOverrides(onboardingSeen: false, signedIn: false),
        captureKey: capture,
      );

      for (var i = 1; i < page; i++) {
        await tester.tap(find.byKey(const ValueKey('onboarding-next')));
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);

      await expectLater(
        find.byKey(capture),
        matchesGoldenFile('goldens/onboarding-page$page.png'),
      );
      final semantics = tester.ensureSemantics();
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      semantics.dispose();
    });
  }
}
