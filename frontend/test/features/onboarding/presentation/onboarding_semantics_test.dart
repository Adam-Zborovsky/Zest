import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/in_memory_session.dart';
import 'onboarding_test_harness.dart';

bool _isOrHasAncestorKey(BuildContext context, Key key) {
  if (context.widget.key == key) return true;
  var found = false;
  context.visitAncestorElements((element) {
    if (element.widget.key == key) {
      found = true;
      return false;
    }
    return true;
  });
  return found;
}

void main() {
  testWidgets('each page announces its number and heading', (tester) async {
    final announcements = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockDecodedMessageHandler<Object?>(SystemChannels.accessibility, (
          message,
        ) async {
          if (message is Map && message['type'] == 'announce') {
            final data = message['data'];
            if (data is Map && data['message'] is String) {
              announcements.add(data['message'] as String);
            }
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockDecodedMessageHandler<Object?>(
            SystemChannels.accessibility,
            null,
          ),
    );

    await pumpOnboardingApp(
      tester,
      overrides: sessionTestOverrides(onboardingSeen: false, signedIn: false),
    );
    expect(
      announcements,
      contains('Page 1 of 5. Explore what goes together'),
    );

    await tester.tap(find.byKey(const ValueKey('onboarding-next')));
    await tester.pumpAndSettle();
    expect(announcements, contains('Page 2 of 5. See what you can make'));
  });

  testWidgets('page headings are marked as semantic headers', (tester) async {
    await pumpOnboardingApp(
      tester,
      overrides: sessionTestOverrides(onboardingSeen: false, signedIn: false),
    );
    final semantics = tester.ensureSemantics();
    final data = tester.getSemantics(
      find.text('Explore what goes together'),
    );
    expect(data.flagsCollection.isHeader, isTrue);
    semantics.dispose();
  });

  testWidgets('each demo exposes exactly one summary label', (tester) async {
    await pumpOnboardingApp(
      tester,
      overrides: sessionTestOverrides(onboardingSeen: false, signedIn: false),
    );
    final semantics = tester.ensureSemantics();
    expect(
      find.bySemanticsLabel('Example of the ingredient constellation'),
      findsOneWidget,
    );
    // The constellation canvas paints ingredient names, but they carry no
    // semantics of their own: only the one summary label is exposed.
    expect(find.bySemanticsLabel('Lime juice'), findsNothing);
    semantics.dispose();
  });

  testWidgets('focus order is Skip, then Back, then Next', (tester) async {
    await pumpOnboardingApp(
      tester,
      overrides: sessionTestOverrides(onboardingSeen: false, signedIn: false),
    );
    // Back is disabled (and so unreachable) on page 1; move to page 2 first
    // so all three controls are traversable.
    await tester.tap(find.byKey(const ValueKey('onboarding-next')));
    await tester.pumpAndSettle();

    const targets = {
      'onboarding-skip': 'Skip',
      'onboarding-back': 'Back',
      'onboarding-next': 'Next',
    };
    final seen = <String>[];
    for (var i = 0; i < 30 && seen.length < targets.length; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final context = FocusManager.instance.primaryFocus?.context;
      if (context == null) continue;
      for (final entry in targets.entries) {
        if (seen.contains(entry.value)) continue;
        if (_isOrHasAncestorKey(context, ValueKey(entry.key))) {
          seen.add(entry.value);
        }
      }
    }
    expect(seen, ['Skip', 'Back', 'Next']);
  });
}
