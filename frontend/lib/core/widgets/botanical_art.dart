import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design/zest_tokens.dart';

enum BotanicalMotif { garnish, emptyGlass, citrus }

/// Decorative cut-paper art, deliberately excluded from reading order.
class BotanicalArt extends StatelessWidget {
  const BotanicalArt({
    super.key,
    this.motif = BotanicalMotif.garnish,
    this.size = 104,
  });

  final BotanicalMotif motif;
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: RepaintBoundary(
      child: CustomPaint(
        size: Size.square(size),
        painter: _BotanicalPainter(motif),
      ),
    ),
  );
}

class _BotanicalPainter extends CustomPainter {
  const _BotanicalPainter(this.motif);
  final BotanicalMotif motif;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 112, size.height / 112);
    final ink = Paint()
      ..color = ZestPalette.leaf
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    if (motif == BotanicalMotif.emptyGlass) {
      final glass = Path()
        ..moveTo(32, 24)
        ..lineTo(39, 89)
        ..quadraticBezierTo(56, 97, 73, 89)
        ..lineTo(80, 24);
      canvas.drawPath(glass, Paint()..color = ZestPalette.fennel);
      canvas.drawPath(glass, ink);
      canvas.drawOval(const Rect.fromLTWH(32, 18, 48, 12), ink);
      canvas.drawCircle(
        const Offset(61, 80),
        4,
        Paint()..color = ZestPalette.grapefruit,
      );
      final sprig = Path()
        ..moveTo(48, 66)
        ..quadraticBezierTo(51, 51, 60, 55)
        ..quadraticBezierTo(59, 62, 48, 66);
      canvas.drawPath(sprig, Paint()..color = ZestPalette.celery);
    } else {
      final center = motif == BotanicalMotif.citrus
          ? const Offset(56, 56)
          : const Offset(38, 45);
      const radius = 28.0;
      canvas.drawCircle(
        center,
        radius,
        Paint()..color = ZestPalette.grapefruit,
      );
      final pith = Paint()
        ..color = ZestPalette.peach
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4;
      canvas.drawCircle(center, radius - 6, pith);
      for (var i = 0; i < 6; i++) {
        final angle = i * math.pi / 3;
        canvas.drawLine(
          center + Offset(math.cos(angle), math.sin(angle)) * 5,
          center + Offset(math.cos(angle), math.sin(angle)) * (radius - 7),
          pith,
        );
      }
      if (motif == BotanicalMotif.garnish) {
        final leaf = Path()
          ..moveTo(73, 68)
          ..cubicTo(61, 45, 64, 16, 79, 16)
          ..cubicTo(102, 28, 99, 53, 73, 68);
        canvas.drawPath(leaf, Paint()..color = ZestPalette.celery);
        canvas.drawPath(
          Path()
            ..moveTo(74, 62)
            ..quadraticBezierTo(84, 46, 78, 30),
          Paint()
            ..color = ZestPalette.secondaryInk
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
        final bowl = Path()
          ..moveTo(48, 62)
          ..lineTo(98, 62)
          ..quadraticBezierTo(92, 83, 73, 83)
          ..quadraticBezierTo(54, 83, 48, 62)
          ..close();
        canvas.drawPath(bowl, Paint()..color = ZestPalette.peach);
        canvas.drawPath(bowl, ink);
        canvas.drawLine(const Offset(73, 83), const Offset(73, 102), ink);
        canvas.drawLine(const Offset(59, 102), const Offset(87, 102), ink);
        canvas.drawLine(
          const Offset(56, 70),
          const Offset(90, 70),
          Paint()
            ..color = ZestPalette.grapefruit
            ..strokeWidth = 3,
        );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BotanicalPainter oldDelegate) =>
      oldDelegate.motif != motif;
}
