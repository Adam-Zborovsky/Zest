import 'package:flutter/material.dart';

import '../../../core/design/zest_tokens.dart';
import '../../constellation/domain/ingredient_kind.dart';
import '../../constellation/presentation/ingredient_glyph.dart';
import 'onboarding_entrance.dart';

/// A small synthetic node in the page-1 constellation demo. Names are
/// ordinary ingredient words (classified through the app's real
/// [ingredientKindOf], never invented statistics) so the glyph colors match
/// the real constellation.
class _DemoNode {
  const _DemoNode(this.name, this.dx, this.dy);

  final String name;

  /// Fraction of the canvas width/height.
  final double dx;
  final double dy;
}

const _selected = _DemoNode('Lime juice', 0.5, 0.52);
const _neighbors = [
  _DemoNode('Gin', 0.18, 0.2),
  _DemoNode('Sugar', 0.5, 0.14),
  _DemoNode('Mint', 0.82, 0.2),
  _DemoNode('Rum', 0.16, 0.66),
  _DemoNode('Bitters', 0.84, 0.6),
  _DemoNode('Ice', 0.5, 0.9),
];

/// The live constellation demo on page 1: about seven glyph nodes, one
/// selected, its neighborhood highlighted. Synthetic content only — no
/// providers, no counts.
class OnboardingConstellationDemo extends StatelessWidget {
  const OnboardingConstellationDemo({super.key, required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Example of the ingredient constellation',
    child: ExcludeSemantics(
      child: SizedBox(
        height: 220,
        child: OnboardingEntrance(
          active: active,
          duration: ZestMotion.pop,
          // The real constellation canvas passes the theme's DM Sans label
          // style into its painter; a bare TextStyle here (no fontFamily)
          // fell back to the Flutter test harness's default glyph-box font,
          // rendering labels as solid bars in goldens.
          builder: (context, t) => CustomPaint(
            painter: _ConstellationDemoPainter(
              pop: t,
              labelStyle: Theme.of(
                context,
              ).textTheme.labelSmall!.copyWith(color: ZestPalette.leaf),
            ),
            size: Size.infinite,
          ),
        ),
      ),
    ),
  );
}

class _ConstellationDemoPainter extends CustomPainter {
  const _ConstellationDemoPainter({required this.pop, required this.labelStyle});

  /// 0 → 1 one-shot entrance for the selected node only; neighbors are
  /// always drawn at rest so the surrounding graph reads immediately.
  final double pop;

  /// The theme's DM Sans label style, matching the real constellation
  /// canvas — labels need an explicit font family or they fall back to the
  /// platform default, which the golden test harness cannot render.
  final TextStyle labelStyle;

  @override
  void paint(Canvas canvas, Size size) {
    Offset at(_DemoNode node) => Offset(node.dx * size.width, node.dy * size.height);
    final center = at(_selected);

    final linePaint = Paint()
      ..color = ZestPalette.peach.withValues(alpha: 0.7)
      ..strokeWidth = 1.4;
    for (final neighbor in _neighbors) {
      canvas.drawLine(center, at(neighbor), linePaint);
    }

    for (final neighbor in _neighbors) {
      paintIngredientGlyph(
        canvas,
        at(neighbor),
        18,
        ingredientKindOf(neighbor.name),
      );
    }

    // Selected node: a grapefruit halo behind a citrus glyph, popping in.
    final scale = 0.6 + 0.4 * pop;
    final haloPaint = Paint()
      ..color = ZestPalette.grapefruit.withValues(alpha: 0.35 * pop + 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawCircle(center, 26 * scale, haloPaint);
    paintIngredientGlyph(canvas, center, 22 * scale, IngredientKind.citrus);

    _drawLabel(canvas, center, _selected.name);
    for (final neighbor in _neighbors) {
      _drawLabel(canvas, at(neighbor), neighbor.name);
    }
  }

  void _drawLabel(Canvas canvas, Offset anchor, String text) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: labelStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    final rect = Rect.fromCenter(
      center: anchor + Offset(0, 24 + painter.height / 2),
      width: painter.width + ZestSpace.sm * 2,
      height: painter.height + ZestSpace.xs,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(999)),
      Paint()..color = ZestPalette.peach,
    );
    painter.paint(canvas, rect.center - Offset(painter.width / 2, painter.height / 2));
  }

  @override
  bool shouldRepaint(_ConstellationDemoPainter oldDelegate) => oldDelegate.pop != pop;
}
