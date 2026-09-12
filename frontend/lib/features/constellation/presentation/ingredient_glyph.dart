import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/design/zest_tokens.dart';
import '../domain/ingredient_kind.dart';

/// Cut-paper ingredient glyphs: a colored disc per [IngredientKind] with a
/// small inked mark — a tall spirit bottle, a round liqueur flask, a citrus
/// wheel, an isometric sugar cube, a mint sprig, or a tumbler with bubbles
/// for everything else. Paths live in a unit space and Paint objects are
/// cached per (kind, dimmed, surface), so painting a glyph never allocates —
/// the constellation's per-frame contract holds.
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
      canvas.drawPath(_GlyphPaths.flask, paints.markFill);
      canvas.drawRect(_GlyphPaths.flaskCork, paints.accentFill);
      canvas.drawRect(_GlyphPaths.flaskLabel, paints.accentFill);
    case IngredientKind.citrus:
      canvas.drawCircle(Offset.zero, 0.8, paints.accentFill);
      canvas.drawCircle(Offset.zero, 0.8, paints.markStroke);
      canvas.drawPath(_GlyphPaths.spokes, paints.markStroke);
    case IngredientKind.sweet:
      canvas.drawPath(_GlyphPaths.cubeLeft, paints.accentFill);
      canvas.drawPath(_GlyphPaths.cubeRight, paints.softFill);
      canvas.drawPath(_GlyphPaths.cubeOutline, paints.markStroke);
    case IngredientKind.herbal:
      canvas.drawPath(_GlyphPaths.sprigStem, paints.markStroke);
      canvas.drawPath(_GlyphPaths.sprigLeaves, paints.markFill);
    case IngredientKind.other:
      canvas.drawPath(_GlyphPaths.tumblerLiquid, paints.softFill);
      canvas.drawPath(_GlyphPaths.tumbler, paints.markStroke);
      canvas.drawCircle(const Offset(-0.14, 0.42), 0.1, paints.accentFill);
      canvas.drawCircle(const Offset(0.16, 0.12), 0.08, paints.accentFill);
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
  /// Spirits: a tall, square-shouldered bottle with a label.
  static final bottle = Path()
    ..addRRect(
      RRect.fromLTRBR(-0.42, -0.3, 0.42, 0.95, const Radius.circular(0.16)),
    )
    ..addRect(const Rect.fromLTRB(-0.16, -0.92, 0.16, -0.24));

  static const bottleLabel = Rect.fromLTRB(-0.28, 0.12, 0.28, 0.5);

  /// Liqueurs and bitters: a round-bodied flask with a long neck, cork, and
  /// label — distinct from the spirit bottle's tall silhouette.
  static final flask = Path()
    ..addOval(Rect.fromCircle(center: const Offset(0, 0.32), radius: 0.6))
    ..addRect(const Rect.fromLTRB(-0.16, -0.78, 0.16, -0.2));

  static const flaskCork = Rect.fromLTRB(-0.23, -0.98, 0.23, -0.78);
  static const flaskLabel = Rect.fromLTRB(-0.36, 0.18, 0.36, 0.5);

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

  /// Sweeteners: an isometric sugar cube with two shaded faces.
  static const _cubeTop = Offset(0, -0.8);
  static const _cubeRight = Offset(0.72, -0.4);
  static const _cubeCenter = Offset(0, 0);
  static const _cubeLeft = Offset(-0.72, -0.4);
  static const _cubeBottom = Offset(0, 0.82);
  static const _cubeBottomLeft = Offset(-0.72, 0.42);
  static const _cubeBottomRight = Offset(0.72, 0.42);

  static final cubeLeft = Path()
    ..moveTo(_cubeLeft.dx, _cubeLeft.dy)
    ..lineTo(_cubeCenter.dx, _cubeCenter.dy)
    ..lineTo(_cubeBottom.dx, _cubeBottom.dy)
    ..lineTo(_cubeBottomLeft.dx, _cubeBottomLeft.dy)
    ..close();

  static final cubeRight = Path()
    ..moveTo(_cubeRight.dx, _cubeRight.dy)
    ..lineTo(_cubeCenter.dx, _cubeCenter.dy)
    ..lineTo(_cubeBottom.dx, _cubeBottom.dy)
    ..lineTo(_cubeBottomRight.dx, _cubeBottomRight.dy)
    ..close();

  static final cubeOutline = Path()
    ..moveTo(_cubeTop.dx, _cubeTop.dy)
    ..lineTo(_cubeRight.dx, _cubeRight.dy)
    ..lineTo(_cubeBottomRight.dx, _cubeBottomRight.dy)
    ..lineTo(_cubeBottom.dx, _cubeBottom.dy)
    ..lineTo(_cubeBottomLeft.dx, _cubeBottomLeft.dy)
    ..lineTo(_cubeLeft.dx, _cubeLeft.dy)
    ..close()
    ..moveTo(_cubeLeft.dx, _cubeLeft.dy)
    ..lineTo(_cubeCenter.dx, _cubeCenter.dy)
    ..lineTo(_cubeRight.dx, _cubeRight.dy)
    ..moveTo(_cubeCenter.dx, _cubeCenter.dy)
    ..lineTo(_cubeBottom.dx, _cubeBottom.dy);

  /// Herbs and spice: a mint sprig — a stem with a top leaf and two
  /// alternating side leaves.
  static final sprigStem = Path()
    ..moveTo(0.02, 0.95)
    ..quadraticBezierTo(0.08, 0.2, 0, -0.5);

  static final sprigLeaves = Path()
    ..moveTo(0, -0.98)
    ..cubicTo(0.34, -0.78, 0.32, -0.34, 0, -0.26)
    ..cubicTo(-0.32, -0.34, -0.34, -0.78, 0, -0.98)
    ..close()
    ..moveTo(0.02, 0.02)
    ..cubicTo(-0.18, -0.36, -0.72, -0.34, -0.82, -0.08)
    ..cubicTo(-0.66, 0.24, -0.24, 0.3, 0.02, 0.02)
    ..close()
    ..moveTo(0.05, 0.44)
    ..cubicTo(0.24, 0.06, 0.76, 0.1, 0.84, 0.36)
    ..cubicTo(0.68, 0.66, 0.28, 0.72, 0.05, 0.44)
    ..close();

  /// Everything else (ice, soda, milk, egg white…): a tumbler with bubbles.
  static final tumbler = Path()
    ..moveTo(-0.56, -0.78)
    ..lineTo(-0.42, 0.86)
    ..lineTo(0.42, 0.86)
    ..lineTo(0.56, -0.78);

  static final tumblerLiquid = Path()
    ..moveTo(-0.5, -0.12)
    ..lineTo(-0.42, 0.86)
    ..lineTo(0.42, 0.86)
    ..lineTo(0.5, -0.12)
    ..close();
}

final class _GlyphPaints {
  _GlyphPaints(
    IngredientKind kind, {
    required bool dimmed,
    required bool onLight,
  }) {
    Color tone(Color color, [double alpha = 1]) =>
        color.withValues(alpha: dimmed ? alpha * 0.2 : alpha);
    final (rimColor, markColor, accentColor, softColor) = switch (kind) {
      IngredientKind.spirit => (
        ZestPalette.celery,
        ZestPalette.peach,
        ZestPalette.grapefruit,
        ZestPalette.peach,
      ),
      IngredientKind.liqueur => (
        ZestPalette.peach,
        ZestPalette.peach,
        ZestPalette.celery,
        ZestPalette.peach,
      ),
      IngredientKind.citrus => (
        ZestPalette.peach,
        ZestPalette.leaf,
        ZestPalette.peach,
        ZestPalette.peach,
      ),
      IngredientKind.sweet => (
        ZestPalette.celery,
        ZestPalette.leaf,
        ZestPalette.grapefruit,
        ZestPalette.celery,
      ),
      IngredientKind.herbal => (
        ZestPalette.peach,
        ZestPalette.leaf,
        ZestPalette.grapefruit,
        ZestPalette.celery,
      ),
      IngredientKind.other => (
        ZestPalette.celery,
        ZestPalette.celery,
        ZestPalette.peach,
        ZestPalette.celery,
      ),
    };
    final quiet = kind == IngredientKind.other;
    fill = Paint()..color = tone(_fillOf(kind));
    rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = onLight
          ? tone(ZestPalette.leaf)
          : tone(rimColor, quiet ? 0.7 : 1);
    markFill = Paint()..color = tone(markColor);
    markStroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.13
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = tone(markColor);
    accentFill = Paint()..color = tone(accentColor);
    softFill = Paint()..color = tone(softColor, quiet ? 0.35 : 1);
  }

  late final Paint fill;
  late final Paint rim;
  late final Paint markFill;
  late final Paint markStroke;
  late final Paint accentFill;
  late final Paint softFill;

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
