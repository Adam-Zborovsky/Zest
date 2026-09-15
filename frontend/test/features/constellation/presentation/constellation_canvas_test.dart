import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zest/core/design/zest_tokens.dart';
import 'package:zest/features/constellation/domain/ingredient_graph.dart';
import 'package:zest/features/constellation/presentation/constellation_canvas.dart';

import '../../../support/catalog_fixtures.dart';

const _canvasKey = ValueKey('canvas');

/// A canvas inside a scrolling page, the way home hosts it.
Future<
  ({
    ConstellationCanvasState canvas,
    RenderBox box,
    ScrollController scroll,
    List<Object?> selections,
  })
>
_pumpCanvas(WidgetTester tester) async {
  final graph = IngredientGraph.build([
    ...catalogLetterRecipes('a'),
    ...catalogLetterRecipes('b'),
    ...catalogLetterRecipes('c'),
  ]);
  final scroll = ScrollController();
  addTearDown(scroll.dispose);
  final selections = <Object?>[];
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ListView(
          controller: scroll,
          children: [
            SizedBox(
              height: 500,
              child: ConstellationCanvas(
                key: _canvasKey,
                graph: graph,
                onSelectNode: (identity) {
                  if (identity != null) selections.add(identity);
                },
                onSelectEdge: (edge) {
                  if (edge != null) selections.add(edge);
                },
              ),
            ),
            const SizedBox(height: 2000),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (
    canvas: tester.state<ConstellationCanvasState>(find.byKey(_canvasKey)),
    box: tester.renderObject<RenderBox>(find.byKey(_canvasKey)),
    scroll: scroll,
    selections: selections,
  );
}

/// [magnitude] with each axis signed toward the canvas center from [from],
/// so a drag never runs into the world's walls.
Offset _towardCenter(RenderBox box, Offset from, Offset magnitude) {
  final center = box.size.center(Offset.zero);
  return Offset(
    from.dx < center.dx ? magnitude.dx : -magnitude.dx,
    from.dy < center.dy ? magnitude.dy : -magnitude.dy,
  );
}

/// A canvas point well away from every node and line of the small graph.
Offset _openSpace(RenderBox box) => box.localToGlobal(const Offset(30, 30));

/// Moves two fingers by the same [offset] in [steps], or apart by
/// [spread] each, pumping a frame between steps.
Future<void> _twoFingers(
  WidgetTester tester,
  Offset center, {
  Offset offset = Offset.zero,
  Offset spread = Offset.zero,
  int steps = 5,
}) async {
  final first = await tester.startGesture(center - const Offset(40, 0));
  final second = await tester.startGesture(center + const Offset(40, 0));
  for (var i = 0; i < steps; i++) {
    await first.moveBy(offset / steps.toDouble() - spread / steps.toDouble());
    await second.moveBy(offset / steps.toDouble() + spread / steps.toDouble());
    await tester.pump(const Duration(milliseconds: 16));
  }
  await first.up();
  await second.up();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a one-finger swipe on the canvas scrolls the page and never '
      'moves the view or a node', (tester) async {
    final (:canvas, :box, :scroll, :selections) = await _pumpCanvas(tester);
    final origin = canvas.cameraOrigin;
    final node = canvas.screenPositionOf('mint leaf');

    await tester.timedDragFrom(
      _openSpace(box),
      const Offset(0, -120),
      const Duration(milliseconds: 300),
    );
    await tester.pumpAndSettle();
    expect(scroll.offset, greaterThan(0));
    scroll.jumpTo(0);
    await tester.pump();

    await tester.timedDragFrom(
      box.localToGlobal(node),
      const Offset(0, -120),
      const Duration(milliseconds: 300),
    );
    await tester.pumpAndSettle();

    expect(scroll.offset, greaterThan(0));
    expect(canvas.cameraOrigin, origin);
    expect(canvas.screenPositionOf('mint leaf'), node);
    expect(selections, isEmpty);
  });

  testWidgets('a long press on a node picks it up to drag without scrolling '
      'the page or selecting it', (tester) async {
    final (:canvas, :box, :scroll, :selections) = await _pumpCanvas(tester);
    final start = canvas.screenPositionOf('mint leaf');
    final travel = _towardCenter(box, start, const Offset(40, 48));

    final gesture = await tester.startGesture(box.localToGlobal(start));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    for (var i = 0; i < 4; i++) {
      await gesture.moveBy(travel / 4);
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pumpAndSettle();

    final moved = canvas.screenPositionOf('mint leaf') - start;
    expect(moved.dx, closeTo(travel.dx, 1));
    expect(moved.dy, closeTo(travel.dy, 1));
    expect(scroll.offset, 0);
    expect(selections, isEmpty);
  });

  testWidgets('a tap on a node selects it', (tester) async {
    final (:canvas, :box, scroll: _, :selections) = await _pumpCanvas(tester);

    await tester.tapAt(box.localToGlobal(canvas.screenPositionOf('mint leaf')));
    await tester.pumpAndSettle();

    expect(selections, ['mint leaf']);
  });

  testWidgets('two fingers pan the view, not the page', (tester) async {
    final (:canvas, :box, :scroll, selections: _) = await _pumpCanvas(tester);
    final origin = canvas.cameraOrigin;
    final scale = canvas.cameraScale;

    await _twoFingers(
      tester,
      box.localToGlobal(box.size.center(Offset.zero)),
      offset: const Offset(50, 30),
    );

    expect(canvas.cameraOrigin.dx - origin.dx, closeTo(50, 1));
    expect(canvas.cameraOrigin.dy - origin.dy, closeTo(30, 1));
    expect(canvas.cameraScale, closeTo(scale, 0.001));
    expect(scroll.offset, 0);
  });

  testWidgets('a pinch zooms around its midpoint and a double tap on open '
      'space returns to the opening view', (tester) async {
    final (:canvas, :box, scroll: _, selections: _) = await _pumpCanvas(tester);
    final openingScale = canvas.cameraScale;
    final openingOrigin = canvas.cameraOrigin;

    await _twoFingers(
      tester,
      box.localToGlobal(box.size.center(Offset.zero)),
      spread: const Offset(40, 0),
    );

    expect(canvas.cameraScale, closeTo(openingScale * 2, 0.01));

    await tester.tapAt(_openSpace(box));
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tapAt(_openSpace(box));
    await tester.pumpAndSettle();

    expect(canvas.cameraScale, closeTo(openingScale, 0.001));
    expect((canvas.cameraOrigin - openingOrigin).distance, lessThan(0.5));
  });

  testWidgets('with a mouse, dragging open space pans the view', (
    tester,
  ) async {
    final (:canvas, :box, :scroll, selections: _) = await _pumpCanvas(tester);
    final origin = canvas.cameraOrigin;

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: _openSpace(box));
    await mouse.down(_openSpace(box));
    for (var i = 0; i < 5; i++) {
      await mouse.moveBy(const Offset(10, 6));
      await tester.pump(const Duration(milliseconds: 200));
    }
    await mouse.up();
    await tester.pumpAndSettle();
    await mouse.removePointer();

    expect(canvas.cameraOrigin.dx - origin.dx, closeTo(50, 1));
    expect(canvas.cameraOrigin.dy - origin.dy, closeTo(30, 1));
    expect(scroll.offset, 0);
  });

  testWidgets('a plain wheel scrolls the page; Ctrl+wheel zooms the canvas', (
    tester,
  ) async {
    final (:canvas, :box, :scroll, selections: _) = await _pumpCanvas(tester);
    final openingScale = canvas.cameraScale;
    final center = box.localToGlobal(box.size.center(Offset.zero));

    tester.binding.handlePointerEvent(
      PointerScrollEvent(position: center, scrollDelta: const Offset(0, 150)),
    );
    await tester.pumpAndSettle();
    expect(scroll.offset, greaterThan(0));
    expect(canvas.cameraScale, openingScale);
    scroll.jumpTo(0);
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    tester.binding.handlePointerEvent(
      PointerScrollEvent(position: center, scrollDelta: const Offset(0, -150)),
    );
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();

    expect(canvas.cameraScale, greaterThan(openingScale));
    expect(scroll.offset, 0);
  });

  testWidgets('with ambient motion on, nodes keep floating', (tester) async {
    ZestMotion.ambientMotion = true;
    addTearDown(() => ZestMotion.ambientMotion = false);
    final graph = IngredientGraph.build([
      ...catalogLetterRecipes('a'),
      ...catalogLetterRecipes('b'),
    ]);
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 400,
          height: 500,
          child: ConstellationCanvas(
            key: _canvasKey,
            graph: graph,
            onSelectNode: (_) {},
            onSelectEdge: (_) {},
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 3));
    final canvas = tester.state<ConstellationCanvasState>(
      find.byKey(_canvasKey),
    );
    final before = canvas.screenPositionOf('mint leaf');
    await tester.pump(const Duration(milliseconds: 900));

    expect(canvas.screenPositionOf('mint leaf'), isNot(before));
    expect(tester.binding.transientCallbackCount, greaterThan(0));
    // Unmount so the endless ticker ends with the test.
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('under reduced motion a long-press drag still moves the node '
      'with no ticker', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final (:canvas, :box, scroll: _, selections: _) = await _pumpCanvas(tester);
    final start = canvas.screenPositionOf('mint leaf');
    final step = _towardCenter(box, start, const Offset(30, 0));

    final gesture = await tester.startGesture(box.localToGlobal(start));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    await gesture.moveBy(step);
    await gesture.moveBy(step);
    expect(tester.binding.transientCallbackCount, 0);
    await gesture.up();
    await tester.pump();

    expect(
      canvas.screenPositionOf('mint leaf').dx - start.dx,
      closeTo(step.dx * 2, 1),
    );
    expect(tester.binding.transientCallbackCount, 0);
  });
}
