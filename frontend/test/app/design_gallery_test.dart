import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zest/app/zest_app.dart';
import 'package:zest/core/widgets/zest_button.dart';
import 'package:zest/core/widgets/zest_states.dart';

import '../support/catalog_wiring.dart';
import '../support/in_memory_session.dart';
import '../support/load_fonts.dart';

Future<void> openGallery(
  WidgetTester tester, {
  Size size = const Size(412, 915),
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...sessionTestOverrides(),
        // The app-shell launch check (docs/M11.md finding #3) runs
        // unconditionally, so every ZestApp pump needs a catalog
        // repository that never touches the real on-device database.
        emptyCatalogRepositoryOverride(),
      ],
      child: const ZestApp(showGallery: true),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> activate(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadZestFonts);

  testWidgets('keyboard focus stays in the modal and returns to its opener', (
    tester,
  ) async {
    await openGallery(tester);
    final options = find.byKey(const ValueKey('open-options'));
    await tester.ensureVisible(options);
    await tester.pumpAndSettle();
    final opener = Focus.of(tester.element(find.text('Open recipe options')));
    opener.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    for (var i = 0; i < 8; i++) {
      final focusedContext = FocusManager.instance.primaryFocus!.context!;
      expect(
        focusedContext.findAncestorWidgetOfExactType<BottomSheet>(),
        isNotNull,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(FocusManager.instance.primaryFocus, same(opener));
  });

  testWidgets('sheet close remains reachable above a keyboard inset', (
    tester,
  ) async {
    await openGallery(tester, size: const Size(320, 640));
    await activate(tester, find.byKey(const ValueKey('open-options')));
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    final close = find.byTooltip('Close Recipe options');
    await tester.ensureVisible(close);
    await tester.pumpAndSettle();
    expect(tester.getRect(close).bottom, lessThanOrEqualTo(360));
    await tester.tap(close);
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('selected chip keeps its entire label at 3x text', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await openGallery(tester, size: const Size(320, 640));
    final reduce = find.widgetWithText(FilterChip, 'Reduce motion');
    await activate(tester, reduce);
    final paragraph = tester.renderObject<RenderParagraph>(
      find.text('Reduce motion'),
    );
    expect(paragraph.didExceedMaxLines, isFalse);
    final boxes = paragraph.getBoxesForSelection(
      const TextSelection(baseOffset: 0, extentOffset: 13),
    );
    expect(boxes, isNotEmpty);
    for (final box in boxes) {
      expect(box.right, lessThanOrEqualTo(paragraph.size.width + 0.01));
      expect(box.bottom, lessThanOrEqualTo(paragraph.size.height + 0.01));
    }
  });
  testWidgets(
    'gallery includes all shared states and temporary recipe feedback',
    (tester) async {
      await openGallery(tester);
      expect(find.text('Botanical Play · M1'), findsOneWidget);
      expect(find.byType(ZestEmptyState), findsOneWidget);
      expect(find.byType(ZestLoadingState), findsOneWidget);
      expect(find.byType(ZestErrorState), findsOneWidget);

      final save = find.byKey(const ValueKey('save-preview'));
      await activate(tester, save);
      expect(find.text('Saved in this preview only.'), findsOneWidget);
      expect(find.text('Unsave recipe'), findsOneWidget);
      await activate(tester, save);
      expect(find.text('Save recipe'), findsOneWidget);

      final herbs = find.widgetWithText(FilterChip, 'Herbs');
      expect(tester.widget<FilterChip>(herbs).selected, isFalse);
      await activate(tester, herbs);
      expect(tester.widget<FilterChip>(herbs).selected, isTrue);
      final disabled = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Saved'),
      );
      expect(disabled.onPressed, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'retry feedback is repeatable and reset restores specimen state',
    (tester) async {
      await openGallery(tester);
      final retry = find.widgetWithText(ZestButton, 'Try again');
      await activate(tester, retry);
      await activate(tester, retry);
      expect(find.text('Retry tapped 2 times. Preview only.'), findsOneWidget);
      await activate(tester, find.widgetWithText(ZestButton, 'Reset preview'));
      expect(find.text('Retry tapped 2 times. Preview only.'), findsNothing);
      expect(
        tester
            .widget<FilterChip>(find.widgetWithText(FilterChip, 'Citrus'))
            .selected,
        isTrue,
      );
    },
  );

  testWidgets('sheet actions work and Escape and explicit close dismiss it', (
    tester,
  ) async {
    await openGallery(tester);
    final options = find.byKey(const ValueKey('open-options'));
    await activate(tester, options);
    expect(find.text('Recipe options'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.widgetWithText(ZestButton, 'Save recipe'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('Saved in this preview only.'), findsOneWidget);

    await activate(tester, options);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);

    await activate(tester, options);
    await tester.tap(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.widgetWithText(ZestButton, 'View ingredients'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Sample ingredients'), findsOneWidget);
    await tester.tap(find.byTooltip('Close Sample ingredients'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('reduced-motion preview disables sheet and chip transitions', (
    tester,
  ) async {
    await openGallery(tester);
    final reduce = find.widgetWithText(FilterChip, 'Reduce motion');
    await activate(tester, reduce);
    expect(tester.widget<FilterChip>(reduce).selected, isTrue);
    expect(
      tester
          .widget<FilterChip>(reduce)
          .chipAnimationStyle!
          .selectAnimation!
          .duration,
      Duration.zero,
    );
    await activate(tester, find.byKey(const ValueKey('open-options')));
    final route = ModalRoute.of(tester.element(find.byType(BottomSheet)))!;
    expect(route.transitionDuration, Duration.zero);
    expect(route.reverseTransitionDuration, Duration.zero);
    await tester.tap(find.byTooltip('Close Recipe options'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('system motion preference cannot be disabled by the gallery', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await openGallery(tester);
    final chip = tester.widget<FilterChip>(
      find.widgetWithText(FilterChip, 'Reduce motion'),
    );
    expect(chip.selected, isTrue);
    expect(chip.onSelected, isNull);
    expect(
      find.text('Reduced motion is enabled by your device.'),
      findsOneWidget,
    );
  });

  for (final scale in [1.0, 2.0, 3.0]) {
    testWidgets('320px gallery and sheet remain usable at ${scale}x text', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await openGallery(tester, size: const Size(320, 640));
      expect(tester.takeException(), isNull);
      await activate(tester, find.byKey(const ValueKey('open-options')));
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.byTooltip('Close Recipe options'));
      await tester.tap(find.byTooltip('Close Recipe options'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
    });
  }

  testWidgets('accessible labels, contrast and Android touch targets pass', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await openGallery(tester, size: const Size(412, 3000));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      await activate(tester, find.byKey(const ValueKey('open-options')));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
    } finally {
      semantics.dispose();
    }
  });
}
