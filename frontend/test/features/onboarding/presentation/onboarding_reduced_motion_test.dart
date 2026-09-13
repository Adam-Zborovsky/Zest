import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zest/core/widgets/zest_button.dart';
import 'package:zest/features/onboarding/presentation/onboarding_bar_demo.dart';
import 'package:zest/features/onboarding/presentation/onboarding_memory_demo.dart';

import '../../../support/in_memory_session.dart';
import 'onboarding_test_harness.dart';

/// Under either reduced-motion flag, [OnboardingEntrance] never creates an
/// [AnimationController] and every demo renders its settled state on the
/// first frame — this suite proves both halves of that contract.
void main() {
  Finder buttonWithText(String label) => find.widgetWithText(ZestButton, label);

  testWidgets(
    'reduced motion renders every demo settled with no running animation',
    (tester) async {
      await pumpOnboardingApp(
        tester,
        overrides: sessionTestOverrides(onboardingSeen: false, signedIn: false),
        reducedMotion: true,
      );
      expect(tester.binding.transientCallbackCount, 0);

      // Page 2: the ready/swap/missing strips are fully in place immediately.
      await tester.tap(buttonWithText('Next'));
      await tester.pump();
      expect(tester.binding.transientCallbackCount, 0);
      for (final opacity in tester.widgetList<Opacity>(
        find.descendant(
          of: find.byType(OnboardingBarDemo),
          matching: find.byType(Opacity),
        ),
      )) {
        expect(opacity.opacity, 1.0);
      }

      // Page 3: the changed measure already reads its settled value.
      await tester.tap(buttonWithText('Next'));
      await tester.pump();
      expect(tester.binding.transientCallbackCount, 0);
      expect(find.text('30 ml'), findsOneWidget);
      expect(find.text('25 ml'), findsNothing);

      // Page 4: the memory photo tile is fully dropped in immediately.
      await tester.tap(buttonWithText('Next'));
      await tester.pump();
      expect(tester.binding.transientCallbackCount, 0);
      for (final opacity in tester.widgetList<Opacity>(
        find.descendant(
          of: find.byType(OnboardingMemoryDemo),
          matching: find.byType(Opacity),
        ),
      )) {
        expect(opacity.opacity, 1.0);
      }
    },
  );

  testWidgets('reduced motion jumps between pages instead of animating', (
    tester,
  ) async {
    await pumpOnboardingApp(
      tester,
      overrides: sessionTestOverrides(onboardingSeen: false, signedIn: false),
      reducedMotion: true,
    );

    await tester.tap(buttonWithText('Next'));
    // A single pump is enough: a jump needs no further frames to settle.
    await tester.pump();
    expect(find.text('2 of 5'), findsOneWidget);
    expect(tester.binding.transientCallbackCount, 0);
  });
}
