import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/design/zest_tokens.dart';
import '../domain/ingredient_kind.dart';

/// Cut-paper ingredient glyphs: a colored disc per [IngredientKind] with a
/// small inked mark (bottle, dropper, citrus wheel, sugar cubes, leaf, or a
/// quiet ring). Paths live in a unit space and Paint objects are cached per
/// (kind, dimmed, surface), so painting a glyph never allocates — the
/// constellation's per-frame contract holds.
void paintIngredientGlyph(
  Canvas canvas,
  Offset center,
  double radius,
  IngredientKind kind, {
  bool dimmed = false,
  bool onLight = false,
}) {
  final paints = _GlyphPaints.of(kind, dimmed: dimmed, onLight: onLight);
  canvas.drawCircle(center, radius, paints.fill);
  canvas.drawCircle(center, radius, paints.rim);
  // Very small discs read better as plain color than as a crowded mark.
  if (radius < 12) return;
  canvas.save();
  canvas.translate(center.dx, center.dy);
  canvas.scale(radius * 0.6);
  switch (kind) {
    case IngredientKind.spirit:
      canvas.drawPath(_GlyphPaths.bottle, paints.markFill);
      canvas.drawRect(_GlyphPaths.bottleLabel, paints.accentFill);
    case IngredientKind.liqueur:
      canvas.drawCircle(const Offset(0, -0.58), 0.3, paints.markFill);
      canvas.drawPath(_GlyphPaths.dropper, paints.markFill);
      canvas.drawCircle(const Offset(0, 0.2), 0.1, paints.accentFill);
    case IngredientKind.citrus:
      canvas.drawCircle(Offset.zero, 0.8, paints.accentFill);
      canvas.drawCircle(Offset.zero, 0.8, paints.markStroke);
      canvas.drawPath(_GlyphPaths.spokes, paints.markStroke);
    case IngredientKind.sweet:
      canvas.drawRRect(_GlyphPaths.cubeBack, paints.accentFill);
      canvas.drawRRect(_GlyphPaths.cubeBack, paints.markStroke);
      canvas.drawRRect(_GlyphPaths.cubeFront, paints.markStroke);
    case IngredientKind.herbal:
      canvas.drawPath(_GlyphPaths.leaf, paints.markFill);
      canvas.drawPath(_GlyphPaths.midrib, paints.accentStroke);
    case IngredientKind.other:
      canvas.drawCircle(Offset.zero, 0.3, paints.markStroke);
  }
  canvas.restore();
}

/// The swatch color for a kind, shared by the canvas discs and the legend.
Color ingredientKindFill(IngredientKind kind) => _fillOf(kind);

Color _fillOf(IngredientKind kind) => switch (kind) {
  IngredientKind.spirit => ZestPalette.moss,
  IngredientKind.liqueur => ZestPalette.berry,
  IngredientKind.citrus => ZestPalette.grapefruit,
  IngredientKind.sweet => ZestPalette.peach,
  IngredientKind.herbal => ZestPalette.celery,
  IngredientKind.other => ZestPalette.night,
};

abstract final class _GlyphPaths {
  static final bottle = Path()
    ..addRRect(
      RRect.fromLTRBR(-0.42, -0.3, 0.42, 0.95, const Radius.circular(0.16)),
    )
    ..addRect(const Rect.fromLTRB(-0.16, -0.92, 0.16, -0.24));

  static const bottleLabel = Rect.fromLTRB(-0.28, 0.12, 0.28, 0.5);

  static final dropper = Path()
    ..addRRect(
      RRect.fromLTRBR(-0.13, -0.36, 0.13, 0.6, const Radius.circular(0.06)),
    )
    ..moveTo(-0.13, 0.58)
    ..lineTo(0, 0.95)
    ..lineTo(0.13, 0.58)
    ..close();

  static final spokes = () {
    final path = Path();
    for (var i = 0; i < 6; i++) {
      final angle = i * math.pi / 3;
      final direction = Offset(math.cos(angle), math.sin(angle));
      final from = direction * 0.14;
      final to = direction * 0.66;
      path
        ..moveTo(from.dx, from.dy)
        ..lineTo(to.dx, to.dy);
    }
    return path;
  }();

  static final cubeBack = RRect.fromLTRBR(
    -0.76,
    -0.66,
    0.08,
    0.16,
    const Radius.circular(0.1),
  );

  static final cubeFront = RRect.fromLTRBR(
    -0.14,
    -0.1,
    0.72,
    0.7,
    const Radius.circular(0.1),
  );

  static final leaf = Path()
    ..moveTo(-0.72, 0.7)
    ..cubicTo(-0.78, -0.35, 0.05, -0.88, 0.78, -0.74)
    ..cubicTo(0.74, 0.05, 0.12, 0.76, -0.72, 0.7)
    ..close();

  static final midrib = Path()
    ..moveTo(-0.5, 0.5)
    ..quadraticBezierTo(0.05, 0.02, 0.55, -0.52);
}

final class _GlyphPaints {
  _GlyphPaints(
    IngredientKind kind, {
    required bool dimmed,
    required bool onLight,
  }) {
    Color tone(Color color, [double alpha = 1]) =>
        color.withValues(alpha: dimmed ? alpha * 0.2 : alpha);
    final (rimColor, markColor, accentColor) = switch (kind) {
      IngredientKind.spirit => (
        ZestPalette.celery,
        ZestPalette.peach,
        ZestPalette.grapefruit,
      ),
      IngredientKind.liqueur => (
        ZestPalette.peach,
        ZestPalette.peach,
        ZestPalette.celery,
      ),
      IngredientKind.citrus => (
        ZestPalette.peach,
        ZestPalette.leaf,
        ZestPalette.peach,
      ),
      IngredientKind.sweet => (
        ZestPalette.celery,
        ZestPalette.leaf,
        ZestPalette.grapefruit,
      ),
      IngredientKind.herbal => (
        ZestPalette.peach,
        ZestPalette.leaf,
        ZestPalette.celery,
      ),
      IngredientKind.other => (
        ZestPalette.celery,
        ZestPalette.celery,
        ZestPalette.celery,
      ),
    };
    fill = Paint()..color = tone(_fillOf(kind));
    rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = onLight
          ? tone(ZestPalette.leaf)
          : tone(rimColor, kind == IngredientKind.other ? 0.7 : 1);
    markFill = Paint()..color = tone(markColor);
    markStroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.13
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = tone(markColor);
    accentFill = Paint()..color = tone(accentColor);
    accentStroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.12
      ..strokeCap = StrokeCap.round
      ..color = tone(accentColor);
  }

  late final Paint fill;
  late final Paint rim;
  late final Paint markFill;
  late final Paint markStroke;
  late final Paint accentFill;
  late final Paint accentStroke;

  static final _cache = <(IngredientKind, bool, bool), _GlyphPaints>{};

  static _GlyphPaints of(
    IngredientKind kind, {
    required bool dimmed,
    required bool onLight,
  }) => _cache.putIfAbsent((
    kind,
    dimmed,
    onLight,
  ), () => _GlyphPaints(kind, dimmed: dimmed, onLight: onLight));
}

/// A standalone glyph for light surfaces: ingredient rows and the legend.
/// Decorative — the ingredient name beside it carries the meaning.
class IngredientGlyph extends StatelessWidget {
  const IngredientGlyph({
    super.key,
    required this.kind,
    this.size = 32,
    this.onLight = true,
  });

  final IngredientKind kind;
  final double size;
  final bool onLight;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(
      size: Size.square(size),
      painter: _IngredientGlyphPainter(kind, onLight: onLight),
    ),
  );
}

class _IngredientGlyphPainter extends CustomPainter {
  const _IngredientGlyphPainter(this.kind, {required this.onLight});

  final IngredientKind kind;
  final bool onLight;

  @override
  void paint(Canvas canvas, Size size) => paintIngredientGlyph(
    canvas,
    size.center(Offset.zero),
    size.shortestSide / 2 - 1.5,
    kind,
    onLight: onLight,
  );

  @override
  bool shouldRepaint(_IngredientGlyphPainter oldDelegate) =>
      oldDelegate.kind != kind || oldDelegate.onLight != onLight;
}
