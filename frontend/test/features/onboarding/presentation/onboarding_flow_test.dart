import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zest/core/widgets/zest_button.dart';
import 'package:zest/features/onboarding/data/session_stores.dart';

import '../../../support/in_memory_session.dart';
import 'onboarding_test_harness.dart';

/// A store that counts successful writes, to prove a double tap only ever
/// records onboarding as seen once.
class _CountingOnboardingStore implements OnboardingStore {
  int writes = 0;
  bool _seen = false;

  @override
  bool get hasSeenOnboarding => _seen;

  @override
  Future<void> markOnboardingSeen() async {
    writes++;
    _seen = true;
  }
}

void main() {
  Finder buttonWithText(String label) => find.widgetWithText(ZestButton, label);
  ZestButton buttonWidget(WidgetTester tester, String label) =>
      tester.widget<ZestButton>(buttonWithText(label));

  testWidgets(
    'Next and Back move through all four pages; Back is disabled on page 1',
    (tester) async {
      await pumpOnboardingApp(
        tester,
        overrides: sessionTestOverrides(onboardingSeen: false, signedIn: false),
      );

      expect(buttonWidget(tester, 'Back').onPressed, isNull);
      expect(find.text('1 of 5'), findsOneWidget);

      for (final label in ['2 of 5', '3 of 5', '4 of 5']) {
        await tester.tap(buttonWithText('Next'));
        await tester.pumpAndSettle();
        expect(find.text(label), findsOneWidget);
        expect(buttonWidget(tester, 'Back').onPressed, isNotNull);
      }
      expect(buttonWithText('Continue'), findsOneWidget);

      for (final label in ['3 of 5', '2 of 5', '1 of 5']) {
        await tester.tap(buttonWithText('Back'));
        await tester.pumpAndSettle();
        expect(find.text(label), findsOneWidget);
      }
      expect(buttonWidget(tester, 'Back').onPressed, isNull);
    },
  );

  testWidgets('swiping moves between pages', (tester) async {
    await pumpOnboardingApp(
      tester,
      overrides: sessionTestOverrides(onboardingSeen: false, signedIn: false),
    );

    expect(find.text('1 of 5'), findsOneWidget);
    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('2 of 5'), findsOneWidget);

    await tester.fling(find.byType(PageView), const Offset(400, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('1 of 5'), findsOneWidget);
  });

  testWidgets(
    'Skip from page 2 marks onboarding seen and lands on login',
    (tester) async {
      final onboarding = InMemoryOnboardingStore();
      await pumpOnboardingApp(
        tester,
        overrides: sessionTestOverrides(
          onboardingSeen: false,
          signedIn: false,
          onboarding: onboarding,
        ),
      );

      await tester.tap(buttonWithText('Next'));
      await tester.pumpAndSettle();
      expect(find.text('2 of 5'), findsOneWidget);

      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      expect(onboarding.hasSeenOnboarding, isTrue);
      expect(find.text('Login'), findsOneWidget);
    },
  );

  testWidgets(
    'Continue on page 4 marks onboarding seen and lands on login',
    (tester) async {
      final onboarding = InMemoryOnboardingStore();
      await pumpOnboardingApp(
        tester,
        overrides: sessionTestOverrides(
          onboardingSeen: false,
          signedIn: false,
          onboarding: onboarding,
        ),
      );

      for (var i = 0; i < 3; i++) {
        await tester.tap(buttonWithText('Next'));
        await tester.pumpAndSettle();
      }
      expect(buttonWithText('Continue'), findsOneWidget);

      await tester.tap(buttonWithText('Continue'));
      await tester.pumpAndSettle();

      expect(onboarding.hasSeenOnboarding, isTrue);
      expect(find.text('Login'), findsOneWidget);
    },
  );

  testWidgets(
    'a failed write shows the inline error and stays on onboarding',
    (tester) async {
      final onboarding = InMemoryOnboardingStore()..failNextWrite = true;
      await pumpOnboardingApp(
        tester,
        overrides: sessionTestOverrides(
          onboardingSeen: false,
          signedIn: false,
          onboarding: onboarding,
        ),
      );

      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      expect(
        find.text('Synthetic onboarding write failure'),
        findsOneWidget,
      );
      expect(find.text('1 of 5'), findsOneWidget);
      expect(find.text('Login'), findsNothing);

      // The page recovers: a following attempt still works.
      onboarding.failNextWrite = false;
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      expect(find.text('Login'), findsOneWidget);
    },
  );

  testWidgets('a double tap writes onboarding-seen once', (tester) async {
    final onboarding = _CountingOnboardingStore();
    await pumpOnboardingApp(
      tester,
      overrides: sessionTestOverrides(
        onboardingSeen: false,
        signedIn: false,
        onboarding: onboarding,
      ),
    );

    await tester.tap(find.text('Skip'));
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(onboarding.writes, 1);
    expect(find.text('Login'), findsOneWidget);
  });
}
