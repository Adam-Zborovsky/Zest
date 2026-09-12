import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design/zest_tokens.dart';

/// The Night Garden field: a full-bleed leaf-green band with a quiet dot
/// texture and a torn-paper bottom edge. Everything inside reads in peach
/// ink through a scoped theme, so headings and body copy need no per-widget
/// color overrides. The texture and the edge are decorative and carry no
/// semantics.
class NightBand extends StatelessWidget {
  const NightBand({
    super.key,
    required this.child,
    this.maxWidth = ZestSpace.pageWidth,
  });

  final Widget child;
  final double maxWidth;

  /// Height reserved below the content for the torn edge.
  static const edgeDepth = 18.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final night = theme.copyWith(
      // Selected controls on the night field invert to peach paper with leaf
      // ink so they never disappear into the leaf-green ground.
      colorScheme: theme.colorScheme.copyWith(
        primary: ZestPalette.peach,
        onPrimary: ZestPalette.leaf,
      ),
      // The chip theme captured the light primary when it was built, so the
      // selected fill is overridden here as well.
      chipTheme: theme.chipTheme.copyWith(selectedColor: ZestPalette.peach),
      textTheme: theme.textTheme.apply(
        bodyColor: ZestPalette.nightInk,
        displayColor: ZestPalette.nightInk,
      ),
      iconTheme: const IconThemeData(color: ZestPalette.nightInk),
      iconButtonTheme: IconButtonThemeData(
        style: (theme.iconButtonTheme.style ?? const ButtonStyle()).copyWith(
          foregroundColor: const WidgetStatePropertyAll(ZestPalette.nightInk),
          side: WidgetStateProperty.resolveWith(
            (states) => BorderSide(
              color: states.contains(WidgetState.focused)
                  ? ZestPalette.grapefruit
                  : Colors.transparent,
              width: 2,
            ),
          ),
        ),
      ),
    );
    return ClipPath(
      clipper: const TornEdgeClipper(depth: edgeDepth),
      child: ColoredBox(
        color: ZestPalette.night,
        child: Padding(
          padding: const EdgeInsets.only(bottom: edgeDepth),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Theme(
                data: night,
                child: DefaultTextStyle.merge(
                  style: const TextStyle(color: ZestPalette.nightInk),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A quiet star-dot texture for graphic regions of the night field. Kept
/// out from behind text so rendered contrast checks measure real ink
/// against the real ground.
class NightDotField extends StatelessWidget {
  const NightDotField({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: const _DotFieldPainter(), child: child);
}

/// A torn-paper bottom edge. Tear heights come from layered sines, so the
/// same width always tears the same way — no randomness, stable goldens.
class TornEdgeClipper extends CustomClipper<Path> {
  const TornEdgeClipper({this.depth = 18});

  final double depth;

  static const _step = 22.0;

  static double _tear(int index) =>
      (0.5 + 0.28 * math.sin(index * 1.7) + 0.2 * math.sin(index * 4.3 + 1))
          .clamp(0.0, 1.0);

  @override
  Path getClip(Size size) {
    final base = math.max(0.0, size.height - depth);
    final count = math.max(2, (size.width / _step).ceil());
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0);
    for (var i = count; i >= 0; i--) {
      path.lineTo(size.width * i / count, base + depth * _tear(i));
    }
    return path..close();
  }

  @override
  bool shouldReclip(TornEdgeClipper oldClipper) => oldClipper.depth != depth;
}

class _DotFieldPainter extends CustomPainter {
  const _DotFieldPainter();

  static const _gap = 22.0;
  static final _dot = Paint()..color = ZestPalette.peach.withValues(alpha: 0.1);

  @override
  void paint(Canvas canvas, Size size) {
    for (var row = 0; row * _gap < size.height; row++) {
      final y = _gap / 2 + row * _gap;
      final start = row.isEven ? _gap / 2 : _gap;
      for (var x = start; x < size.width; x += _gap) {
        canvas.drawCircle(Offset(x, y), 0.9, _dot);
      }
    }
  }

  @override
  bool shouldRepaint(_DotFieldPainter oldDelegate) => false;
}

/// A dashed twine line: the decorative separator of the paper system.
class TwineDivider extends StatelessWidget {
  const TwineDivider({super.key, this.color});

  final Color? color;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      height: 12,
      width: double.infinity,
      child: CustomPaint(
        painter: _TwinePainter(
          color ?? ZestPalette.outline.withValues(alpha: 0.5),
        ),
      ),
    ),
  );
}

class _TwinePainter extends CustomPainter {
  _TwinePainter(Color color)
    : _paint = Paint()
        ..color = color
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round;

  final Paint _paint;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    for (var x = 0.0; x < size.width; x += 10) {
      canvas.drawLine(
        Offset(x, y),
        Offset(math.min(x + 5, size.width), y),
        _paint,
      );
    }
  }

  @override
  bool shouldRepaint(_TwinePainter oldDelegate) =>
      oldDelegate._paint.color != _paint.color;
}

/// A small inked paper tag for metadata and measures.
class PaperTag extends StatelessWidget {
  const PaperTag({
    super.key,
    required this.label,
    this.color = ZestPalette.celery,
    this.icon,
    this.dashed = false,
  });

  final String label;
  final Color color;
  final IconData? icon;

  /// A dashed-feel outline for "not provided" values: lighter ink, no fill.
  final bool dashed;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: dashed ? Colors.transparent : color,
      borderRadius: ZestShape.pill,
      border: Border.all(
        color: dashed ? ZestPalette.outline : ZestPalette.leaf,
        width: 1.2,
      ),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: ZestSpace.md,
        vertical: ZestSpace.xs,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            ExcludeSemantics(
              child: Icon(icon, size: 16, color: ZestPalette.leaf),
            ),
            const SizedBox(width: ZestSpace.xs),
          ],
          Flexible(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium!.copyWith(
                color: dashed ? ZestPalette.secondaryInk : ZestPalette.leaf,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
