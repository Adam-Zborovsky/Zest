import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design/zest_tokens.dart';

/// The small prop [LimeSprite] holds. Onboarding uses [point], [pencil],
/// [bottle] and [photo]; [wave] is reserved for the login track.
enum LimeSpritePose { point, pencil, bottle, photo, wave }

/// A deterministic cut-paper lime-wedge character: a rind arc, radiating
/// pulp segments, two dot eyes, tiny leaf arms, and a small held prop that
/// names the pose. Decorative — it supports the interface rather than
/// dominating it, so it is always excluded from semantics, and it has no
/// animation of its own beyond the optional one-shot pop a caller drives
/// externally (skipped under reduced motion).
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

class _LimeSpritePainter extends CustomPainter {
  const _LimeSpritePainter(this.pose);

  final LimeSpritePose pose;

  // A pale pulp fill would match the fennel page ground exactly and read as
  // a ghost; moss/celery keep the wedge legible on both the night band and
  // the fennel page.
  static const _rind = ZestPalette.moss;
  static const _pulp = ZestPalette.celery;
  static const _pith = ZestPalette.leaf;
  static const _ink = ZestPalette.leaf;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2 + size.height * 0.08);
    canvas.scale(size.shortestSide / 100);

    final rindPaint = Paint()..color = _rind;
    final pithPaint = Paint()
      ..color = _pith.withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    final inkStroke = Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final inkFill = Paint()..color = _ink;

    // Body: a rounded wedge — a wide arc of rind on top, a flat base to
    // stand on, tapering to a soft point at the bottom.
    const bodyRadius = 34.0;
    final body = Path()
      ..moveTo(-bodyRadius, -6)
      ..arcToPoint(
        const Offset(bodyRadius, -6),
        radius: const Radius.circular(bodyRadius),
        clockwise: true,
      )
      ..quadraticBezierTo(bodyRadius * 0.7, 30, 0, 40)
      ..quadraticBezierTo(-bodyRadius * 0.7, 30, -bodyRadius, -6)
      ..close();
    canvas.drawPath(body, Paint()..color = _pulp);
    canvas.drawPath(body, rindPaint..style = PaintingStyle.stroke..strokeWidth = 7);
    canvas.drawPath(body, inkStroke);

    // Pulp segments, radiating from a low center point.
    const origin = Offset(0, 34);
    for (var i = -2; i <= 2; i++) {
      final angle = -math.pi / 2 + i * 0.32;
      final end = origin + Offset(math.cos(angle), math.sin(angle)) * 46;
      canvas.drawLine(origin, end, pithPaint);
    }

    // Eyes.
    canvas.drawCircle(const Offset(-9, -2), 3.2, inkFill);
    canvas.drawCircle(const Offset(9, -2), 3.2, inkFill);

    // Arms: thin leaf-toned lines from the body, ending in a small round
    // hand. The right arm's pose changes with [pose]; the left arm rests.
    final armPaint = Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(
      Path()
        ..moveTo(-bodyRadius + 6, 10)
        ..quadraticBezierTo(-bodyRadius - 8, 18, -bodyRadius - 4, 30),
      armPaint,
    );
    canvas.drawCircle(const Offset(-bodyRadius - 4, 30), 3.4, inkFill);

    switch (pose) {
      case LimeSpritePose.point:
        final hand = _armPath(bodyRadius, raised: true);
        canvas.drawPath(hand, armPaint);
        canvas.drawCircle(const Offset(bodyRadius + 6, -22), 3.4, inkFill);
        canvas.drawLine(
          const Offset(bodyRadius + 6, -22),
          const Offset(bodyRadius + 20, -30),
          armPaint,
        );
      case LimeSpritePose.wave:
        final hand = _armPath(bodyRadius, raised: true, bend: -0.4);
        canvas.drawPath(hand, armPaint);
        canvas.drawCircle(const Offset(bodyRadius + 4, -26), 3.6, inkFill);
      case LimeSpritePose.pencil:
        final hand = _armPath(bodyRadius, raised: false);
        canvas.drawPath(hand, armPaint);
        canvas.save();
        canvas.translate(bodyRadius + 6, 16);
        canvas.rotate(-0.7);
        canvas.drawRect(
          const Rect.fromLTWH(-2, -14, 4, 16),
          Paint()..color = ZestPalette.grapefruit,
        );
        canvas.drawPath(
          Path()
            ..moveTo(-2, -14)
            ..lineTo(0, -20)
            ..lineTo(2, -14)
            ..close(),
          inkFill,
        );
        canvas.restore();
      case LimeSpritePose.bottle:
        final hand = _armPath(bodyRadius, raised: false);
        canvas.drawPath(hand, armPaint);
        canvas.save();
        canvas.translate(bodyRadius + 10, 14);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(-6, -22, 12, 26),
            const Radius.circular(2.5),
          ),
          Paint()..color = ZestPalette.moss,
        );
        canvas.drawRect(const Rect.fromLTWH(-2.5, -28, 5, 8), Paint()..color = ZestPalette.moss);
        canvas.restore();
      case LimeSpritePose.photo:
        final hand = _armPath(bodyRadius, raised: false);
        canvas.drawPath(hand, armPaint);
        canvas.save();
        canvas.translate(bodyRadius + 10, 12);
        canvas.rotate(0.18);
        final card = Rect.fromCenter(center: Offset.zero, width: 20, height: 18);
        canvas.drawRect(card, Paint()..color = ZestPalette.peach);
        canvas.drawRect(card, inkStroke..strokeWidth = 1.4);
        canvas.drawRect(
          const Rect.fromLTWH(-7, -6, 14, 9),
          Paint()..color = ZestPalette.celery,
        );
        canvas.restore();
    }
    canvas.restore();
  }

  Path _armPath(double bodyRadius, {required bool raised, double bend = 0.3}) {
    final start = Offset(bodyRadius - 6, 10);
    final end = raised
        ? Offset(bodyRadius + 6, -22)
        : Offset(bodyRadius + 6, 16);
    final control = raised
        ? Offset(bodyRadius + 18 * bend.sign, -6)
        : Offset(bodyRadius + 14, -2);
    return Path()
      ..moveTo(start.dx, start.dy)
      ..quadraticBezierTo(control.dx, control.dy, end.dx, end.dy);
  }

  @override
  bool shouldRepaint(_LimeSpritePainter oldDelegate) => oldDelegate.pose != pose;
}
