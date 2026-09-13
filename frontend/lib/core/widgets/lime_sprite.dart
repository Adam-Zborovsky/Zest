import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design/zest_tokens.dart';

/// The small prop [LimeSprite] holds. Onboarding uses [point], [pencil],
/// [bottle] and [photo]; [wave] is reserved for the login track.
enum LimeSpritePose { point, pencil, bottle, photo, wave }

/// A deterministic cut-paper lime-wedge character, redrawn from the approved
/// character sheet: a half-circle slice with the flat cut face on top and
/// the curved rind at the bottom, a moss rind with a celery pith line, a
/// celery pulp split into radiating peach segments, a dot-eyed face, tiny
/// leaf-shaped arms, and a small held prop that names the pose. Decorative —
/// it supports the interface rather than dominating it, so it is always
/// excluded from semantics, and it has no animation of its own beyond the
/// optional one-shot pop a caller drives externally (skipped under reduced
/// motion).
class LimeSprite extends StatelessWidget {
  const LimeSprite({super.key, this.pose = LimeSpritePose.point, this.size = 96});

  final LimeSpritePose pose;
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: RepaintBoundary(
      child: CustomPaint(
        size: Size.square(size),
        painter: _LimeSpritePainter(pose),
      ),
    ),
  );
}

/// A point (x, y) in the character sheet's local drawing space.
typedef _Pt = (double, double);

class _LimeSpritePainter extends CustomPainter {
  const _LimeSpritePainter(this.pose);

  final LimeSpritePose pose;

  // The reference sheet's viewBox is 124x106 (134 wide for the bottle pose,
  // whose coordinates are normalized below by shifting x by -5 so every
  // pose shares one 61-centered body). A little extra width keeps every
  // pose's outstretched prop clear of the edge.
  static const _contentWidth = 130.0;
  static const _contentHeight = 106.0;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / _contentWidth;
    canvas.save();
    canvas.translate(
      (size.width - _contentWidth * scale) / 2,
      (size.height - _contentHeight * scale) / 2,
    );
    canvas.scale(scale);

    if (pose == LimeSpritePose.wave) {
      canvas.translate(61, 60);
      canvas.rotate(-4 * math.pi / 180);
      canvas.translate(-61, -60);
    }

    // Legs: two short stick legs with rounded feet.
    _strokeWithHalo(
      canvas,
      Path()
        ..moveTo(53, 82)
        ..lineTo(51, 97)
        ..moveTo(47, 97)
        ..lineTo(55, 97)
        ..moveTo(69, 82)
        ..lineTo(71, 97)
        ..moveTo(67, 97)
        ..lineTo(75, 97),
      2.5,
    );

    // The resting/back arm sits behind the body for the point, pencil and
    // wave poses, matching the reference's paint order.
    if (pose == LimeSpritePose.point || pose == LimeSpritePose.wave) {
      _limb(canvas, _restingLeftArm, 2);
    } else if (pose == LimeSpritePose.pencil) {
      _limb(
        canvas,
        Path()
          ..moveTo(28, 50)
          ..cubicTo(20, 54, 22, 65, 30, 63)
          ..cubicTo(33, 58, 34, 52, 28, 50)
          ..close(),
        2,
      );
    }

    // Rind: a thick moss band along the curved edge.
    final rind = Path()
      ..moveTo(22, 42)
      ..lineTo(100, 42)
      ..cubicTo(100, 64.5, 82.5, 82, 61, 82)
      ..cubicTo(39.5, 82, 22, 64.5, 22, 42)
      ..close();
    canvas.drawPath(rind, Paint()..color = ZestPalette.moss);
    _strokeWithHalo(canvas, rind, 2.2);

    // A thin celery pith line just inside the rind.
    final pith = Path()
      ..moveTo(25, 42)
      ..lineTo(97, 42)
      ..cubicTo(97, 62.5, 80.8, 79, 61, 79)
      ..cubicTo(41.2, 79, 25, 62.5, 25, 42)
      ..close();
    canvas.drawPath(
      pith,
      Paint()
        ..color = ZestPalette.celery
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );

    // Pulp: the celery face.
    final pulp = Path()
      ..moveTo(28, 42)
      ..lineTo(94, 42)
      ..cubicTo(94, 60.5, 79.2, 76, 61, 76)
      ..cubicTo(42.8, 76, 28, 60.5, 28, 42)
      ..close();
    canvas.drawPath(pulp, Paint()..color = ZestPalette.celery);
    canvas.drawPath(
      pulp,
      Paint()
        ..color = ZestPalette.leaf
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeJoin = StrokeJoin.round,
    );

    // Pulp segments, radiating peach lines meeting at the center of the
    // flat edge.
    final peachLine = Paint()
      ..color = ZestPalette.peach
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    const origin = Offset(61, 42);
    for (final end in const <_Pt>[(34, 52), (42, 66), (61, 75), (80, 66), (88, 52)]) {
      canvas.drawLine(origin, Offset(end.$1, end.$2), peachLine);
    }

    // Grapefruit cheek dots.
    canvas.drawCircle(const Offset(48, 56), 3.5, Paint()..color = ZestPalette.grapefruit);
    canvas.drawCircle(const Offset(74, 56), 3.5, Paint()..color = ZestPalette.grapefruit);

    _face(canvas);
    _limbsAndProp(canvas);

    canvas.restore();
  }

  static final Path _restingLeftArm = Path()
    ..moveTo(26, 48)
    ..cubicTo(20, 48, 18, 56, 22, 62)
    ..cubicTo(26, 66, 31, 60, 29, 52)
    ..close();

  void _face(Canvas canvas) {
    final eyeInk = Paint()..color = ZestPalette.leaf;
    final lineInk = Paint()
      ..color = ZestPalette.leaf
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    switch (pose) {
      case LimeSpritePose.point:
        canvas.drawCircle(const Offset(53, 51), 2.5, eyeInk);
        canvas.drawCircle(const Offset(69, 51), 2.5, eyeInk);
        canvas.drawPath(
          Path()
            ..moveTo(58, 57)
            ..quadraticBezierTo(61, 60, 64, 57),
          lineInk,
        );
      case LimeSpritePose.pencil:
        canvas.drawCircle(const Offset(53, 51), 2.5, eyeInk);
        canvas.drawCircle(const Offset(69, 51), 2.5, eyeInk);
        canvas.drawPath(
          Path()
            ..moveTo(59, 58)
            ..quadraticBezierTo(61, 61, 63, 58),
          lineInk,
        );
      case LimeSpritePose.bottle:
        final squint = lineInk..strokeWidth = 2.5;
        canvas.drawPath(
          Path()
            ..moveTo(53, 50)
            ..quadraticBezierTo(56, 47, 59, 50),
          squint,
        );
        canvas.drawPath(
          Path()
            ..moveTo(73, 50)
            ..quadraticBezierTo(76, 47, 79, 50),
          squint,
        );
        canvas.drawPath(
          Path()
            ..moveTo(64, 57)
            ..quadraticBezierTo(66, 59, 68, 57),
          Paint()
            ..color = ZestPalette.leaf
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..strokeCap = StrokeCap.round,
        );
      case LimeSpritePose.photo:
        canvas.drawCircle(const Offset(53, 51), 2.5, eyeInk);
        canvas.drawCircle(const Offset(69, 51), 2.5, eyeInk);
        canvas.drawPath(
          Path()
            ..moveTo(58, 57)
            ..quadraticBezierTo(61, 61, 64, 57),
          lineInk,
        );
      case LimeSpritePose.wave:
        canvas.drawCircle(const Offset(53, 51), 2.5, eyeInk);
        canvas.drawCircle(const Offset(69, 51), 2.5, eyeInk);
        canvas.drawPath(
          Path()
            ..moveTo(57, 56)
            ..quadraticBezierTo(61, 62, 65, 56),
          lineInk,
        );
    }
  }

  void _limbsAndProp(Canvas canvas) {
    switch (pose) {
      case LimeSpritePose.point:
        canvas.save();
        canvas.translate(93, 30);
        _limb(
          canvas,
          Path()
            ..moveTo(0, 16)
            ..cubicTo(6, 10, 18, 2, 24, 0)
            ..cubicTo(22, 8, 16, 20, 8, 20)
            ..cubicTo(3, 20, 0, 18, 0, 16)
            ..close(),
          2,
        );
        canvas.restore();
      case LimeSpritePose.pencil:
        canvas.save();
        canvas.translate(86, 22);
        canvas.rotate(24 * math.pi / 180);
        // Pencil lead.
        canvas.drawPath(
          Path()
            ..moveTo(4, 0)
            ..lineTo(0, 9)
            ..lineTo(8, 9)
            ..close(),
          Paint()..color = ZestPalette.leaf,
        );
        // Pencil wood.
        final woodPath = Path()
          ..moveTo(0, 9)
          ..lineTo(8, 9)
          ..lineTo(8, 14)
          ..lineTo(0, 14)
          ..close();
        canvas.drawPath(woodPath, Paint()..color = ZestPalette.peach);
        canvas.drawPath(
          woodPath,
          Paint()
            ..color = ZestPalette.leaf
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..strokeJoin = StrokeJoin.round,
        );
        // Pencil body (grapefruit).
        final bodyRect = const Rect.fromLTWH(0, 14, 8, 26);
        canvas.drawRect(bodyRect, Paint()..color = ZestPalette.grapefruit);
        canvas.drawRect(
          bodyRect,
          Paint()
            ..color = ZestPalette.leaf
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
        // Eraser band.
        final eraserRect = const Rect.fromLTWH(0, 40, 8, 5);
        canvas.drawRect(eraserRect, Paint()..color = ZestPalette.moss);
        canvas.drawRect(
          eraserRect,
          Paint()
            ..color = ZestPalette.leaf
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
        canvas.restore();
        // Hand grasping the pencil, drawn on top.
        _limb(
          canvas,
          Path()
            ..moveTo(88, 52)
            ..cubicTo(94, 48, 100, 52, 98, 59)
            ..cubicTo(94, 62, 88, 58, 88, 52)
            ..close(),
          2,
        );
      case LimeSpritePose.bottle:
        canvas.save();
        canvas.translate(-5, 0);
        // Neck & cap.
        final neckRect = const Rect.fromLTWH(63, 32, 6, 5);
        canvas.drawRect(neckRect, Paint()..color = ZestPalette.moss);
        canvas.drawRect(
          neckRect,
          Paint()
            ..color = ZestPalette.leaf
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
        final capRect = const Rect.fromLTWH(64.5, 29, 3, 4);
        canvas.drawRect(capRect, Paint()..color = ZestPalette.peach);
        canvas.drawRect(
          capRect,
          Paint()
            ..color = ZestPalette.leaf
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
        // Bottle body.
        final bodyRRect = RRect.fromRectAndRadius(
          const Rect.fromLTWH(58, 37, 16, 30),
          const Radius.circular(3),
        );
        canvas.drawRRect(bodyRRect, Paint()..color = ZestPalette.moss);
        canvas.drawRRect(
          bodyRRect,
          Paint()
            ..color = ZestPalette.leaf
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
        // Peach label.
        final labelRRect = RRect.fromRectAndRadius(
          const Rect.fromLTWH(60, 44, 12, 15),
          const Radius.circular(1),
        );
        canvas.drawRRect(labelRRect, Paint()..color = ZestPalette.peach);
        canvas.drawRRect(
          labelRRect,
          Paint()
            ..color = ZestPalette.leaf
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
        canvas.drawLine(
          const Offset(62, 51),
          const Offset(70, 51),
          Paint()
            ..color = ZestPalette.peach
            ..strokeWidth = 1.5,
        );
        canvas.restore();
        // Arms hugging the bottle from both sides, in front of it.
        _limb(
          canvas,
          Path()
            ..moveTo(41, 54)
            ..cubicTo(43, 58, 51, 61, 55, 58)
            ..cubicTo(57, 55, 53, 52, 47, 50)
            ..close(),
          1.75,
        );
        _limb(
          canvas,
          Path()
            ..moveTo(81, 54)
            ..cubicTo(79, 58, 71, 61, 67, 58)
            ..cubicTo(65, 55, 69, 52, 75, 50)
            ..close(),
          1.75,
        );
      case LimeSpritePose.photo:
        _limb(
          canvas,
          Path()
            ..moveTo(24, 50)
            ..cubicTo(18, 50, 16, 58, 20, 62)
            ..cubicTo(24, 64, 28, 60, 26, 52)
            ..close(),
          1.5,
        );
        canvas.save();
        canvas.translate(80, 18);
        canvas.rotate(8 * math.pi / 180);
        final frame = RRect.fromRectAndRadius(
          const Rect.fromLTWH(0, 0, 28, 34),
          const Radius.circular(2),
        );
        canvas.drawRRect(frame, Paint()..color = ZestPalette.peach);
        canvas.drawRRect(
          frame,
          Paint()
            ..color = ZestPalette.leaf
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
        canvas.drawRect(
          const Rect.fromLTWH(3, 3, 22, 20),
          Paint()..color = ZestPalette.moss,
        );
        canvas.drawPath(
          Path()
            ..moveTo(8, 9)
            ..quadraticBezierTo(14, 15, 20, 9)
            ..close(),
          Paint()..color = ZestPalette.celery,
        );
        canvas.drawPath(
          Path()
            ..moveTo(8, 9)
            ..quadraticBezierTo(14, 15, 20, 9)
            ..close(),
          Paint()
            ..color = ZestPalette.peach
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
        final propLine = Paint()
          ..color = ZestPalette.peach
          ..strokeWidth = 1;
        canvas.drawLine(const Offset(14, 13), const Offset(14, 19), propLine);
        canvas.drawLine(const Offset(11, 19), const Offset(17, 19), propLine);
        canvas.restore();
        _limb(
          canvas,
          Path()
            ..moveTo(82, 48)
            ..cubicTo(86, 44, 92, 48, 90, 54)
            ..cubicTo(87, 58, 82, 54, 82, 48)
            ..close(),
          1.5,
        );
      case LimeSpritePose.wave:
        canvas.save();
        canvas.translate(94, 24);
        _limb(
          canvas,
          Path()
            ..moveTo(2, 20)
            ..cubicTo(6, 14, 16, 6, 22, 2)
            ..cubicTo(23, 9, 18, 18, 10, 24)
            ..cubicTo(5, 26, 2, 24, 2, 20)
            ..close(),
          1.5,
        );
        final tick = Paint()
          ..color = ZestPalette.grapefruit
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round;
        canvas.drawPath(
          Path()
            ..moveTo(20, -2)
            ..quadraticBezierTo(24, 2, 26, 8),
          tick,
        );
        canvas.drawPath(
          Path()
            ..moveTo(25, -5)
            ..quadraticBezierTo(30, 0, 32, 6),
          tick,
        );
        canvas.restore();
    }
  }

  /// Draws a leaf-shaped moss limb with a leaf-ink outline, plus a celery
  /// halo underneath so it stays legible against [ZestPalette.night].
  void _limb(Canvas canvas, Path path, double strokeWidth) {
    canvas.drawPath(path, Paint()..color = ZestPalette.moss);
    _strokeWithHalo(canvas, path, strokeWidth);
  }

  /// Strokes [path] twice: a wider celery halo, then a crisp leaf-ink line
  /// on top, so the deep-leaf outline stays distinct against the night
  /// band without changing how it reads on the fennel page.
  void _strokeWithHalo(Canvas canvas, Path path, double strokeWidth) {
    canvas.drawPath(
      path,
      Paint()
        ..color = ZestPalette.celery
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth + 1.6
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = ZestPalette.leaf
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_LimeSpritePainter oldDelegate) => oldDelegate.pose != pose;
}
