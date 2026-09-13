import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/in_memory_session.dart';
import 'onboarding_test_harness.dart';

void _expectNoOverflow(WidgetTester tester) {
  expect(tester.takeException(), isNull);
  for (final paragraph in tester.renderObjectList<RenderParagraph>(
    find.byType(RichText),
  )) {
    expect(paragraph.didExceedMaxLines, isFalse);
  }
}

void main() {
  testWidgets('all four pages fit at 320 logical px with 2x text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpOnboardingApp(
      tester,
      overrides: sessionTestOverrides(onboardingSeen: false, signedIn: false),
      textScaler: const TextScaler.linear(2.0),
    );
    _expectNoOverflow(tester);

    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byKey(const ValueKey('onboarding-next')));
      await tester.pumpAndSettle();
      _expectNoOverflow(tester);
    }
  });
}
