import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/design/zest_tokens.dart';
import '../domain/graph_layout.dart';
import '../domain/ingredient_graph.dart';
import '../domain/ingredient_kind.dart';
import 'constellation_scene.dart';
import 'ingredient_glyph.dart';

/// Node radius mapping; see [GraphLayout.nodeRadius], which the layout also
/// uses so discs are placed with clearance for their painted size.
double constellationNodeRadius(int prevalence, int maxPrevalence) =>
    GraphLayout.nodeRadius(prevalence, maxPrevalence);

/// The view onto the constellation world: a screen point is
/// `world * scale + origin`. Mutated by the canvas's gestures and read by
/// the painter at paint time.
final class ConstellationCamera {
  double scale = 1;
  Offset origin = Offset.zero;

  Offset toScreen(Offset world) => world * scale + origin;
  Offset toWorld(Offset screen) => (screen - origin) / scale;
}

/// Everything the painter needs for one canvas state: the graph, the live
/// scene, the emphasis implied by the current selection and search filter,
/// each node's glyph kind, and the collision-filtered label set. Prepared
/// once per state change — a selection, filter, drop, or finished zoom —
/// never per animation frame, so the float and the drag springs repaint
/// without re-laying out text or allocating Paint objects (glyph paints are
/// cached per kind in ingredient_glyph).
///
/// The canvas paints on the Night Garden field: glyph discs colored by
/// [IngredientKind], peach string lines whose opacity and width carry edge
/// weight, celery lines for the selected neighborhood, and a grapefruit
/// line and halo for the selection.
///
/// Label rule (documented contract):
/// 1. When a search filter is active, every matching node is pinned.
/// 2. When something is selected, its neighborhood nodes are pinned.
/// 3. When nothing is searched or selected, no name shows at the opening
///    view; each node's name fades in as zooming grows its on-screen radius
///    from [revealStart] to [revealFull], so the most-used ingredients
///    reveal first.
/// Labels are accepted per frame in that priority order (then prevalence),
/// skipping any whose padded rectangle would overlap an already-accepted
/// label at the current zoom — legibility beats completeness, and the
/// search field plus the info surface below the canvas always name the
/// selected things in text. Labels keep their text size at every zoom.
final class ConstellationPaintData {
  ConstellationPaintData({
    required this.graph,
    required IngredientNode? selectedNode,
    required IngredientEdge? selectedEdge,
    required String query,
    required TextStyle labelStyle,
  }) {
    final neighborhood = selectedNode == null
        ? null
        : graph.neighborhood(selectedNode.identity);
    final emphasized = <String>{
      if (selectedNode != null) selectedNode.identity,
      if (neighborhood != null)
        for (final connection in neighborhood.connections)
          connection.node.identity,
      if (selectedEdge != null) ...[
        selectedEdge.aIdentity,
        selectedEdge.bIdentity,
      ],
    };
    final trimmedQuery = query.trim().toLowerCase();
    final matching = trimmedQuery.isEmpty
        ? const <String>{}
        : {
            for (final node in graph.nodes)
              if (node.identity.contains(trimmedQuery)) node.identity,
          };

    final maxWeight = graph.edges.fold(1, (w, e) => math.max(w, e.weight));

    for (final node in graph.nodes) {
      final isSelected = selectedNode?.identity == node.identity;
      final isEmphasized = emphasized.contains(node.identity);
      final dimmed =
          (trimmedQuery.isNotEmpty && !matching.contains(node.identity)) ||
          ((selectedNode != null || selectedEdge != null) && !isEmphasized);
      nodePaints[node.identity] = _NodePaint(
        radius: constellationNodeRadius(node.prevalence, graph.maxPrevalence),
        kind: ingredientKindOf(node.identity),
        dimmed: dimmed,
        selected: isSelected,
        emphasized: isEmphasized && !isSelected,
      );
    }

    // Edges: one stroke Paint per edge, weight-based opacity and width
    // baked in.
    for (final edge in graph.edges) {
      final isSelected = selectedEdge != null && identical(edge, selectedEdge);
      final inNeighborhood =
          selectedNode != null && edge.touches(selectedNode.identity);
      final bothMatch =
          matching.contains(edge.aIdentity) &&
          matching.contains(edge.bIdentity);
      final dimmed =
          (trimmedQuery.isNotEmpty && !bothMatch) ||
          ((selectedNode != null || selectedEdge != null) &&
              !inNeighborhood &&
              !isSelected);
      final weightShare = ((edge.weight - 1) / math.max(1, maxWeight - 1))
          .clamp(0.0, 1.0);
      final baseOpacity = graph.edges.length <= 1
          ? 0.4
          : 0.14 + 0.4 * weightShare;
      final color = isSelected
          ? ZestPalette.grapefruit
          : inNeighborhood
          ? ZestPalette.celery
          : ZestPalette.peach;
      final opacity = isSelected
          ? 1.0
          : inNeighborhood
          ? 0.85
          : baseOpacity;
      final width = 1.0 + 2.5 * weightShare;
      edgePaints.add(
        _EdgePaint(
          edge: edge,
          paint: Paint()
            ..color = color.withValues(alpha: dimmed ? 0.05 : opacity)
            ..style = PaintingStyle.stroke
            ..strokeWidth = isSelected ? width + 1.5 : width
            ..strokeCap = StrokeCap.round,
        ),
      );
    }

    // Labels: text laid out once here in priority order; which ones show is
    // decided per frame by [visibleLabels].
    final pinned = <String>[
      for (final node in graph.nodes)
        if (matching.contains(node.identity)) node.identity,
      if (neighborhood != null) ...[
        neighborhood.center.identity,
        for (final connection in neighborhood.connections)
          connection.node.identity,
      ],
      if (selectedEdge != null) ...[
        selectedEdge.aIdentity,
        selectedEdge.bIdentity,
      ],
    ];
    final revealing =
        trimmedQuery.isEmpty && selectedNode == null && selectedEdge == null;
    final seen = <String>{};
    void addLabel(String identity, {required bool pinned}) {
      if (!seen.add(identity) || !nodePaints.containsKey(identity)) return;
      labels.add(
        _LabelPaint(
          identity: identity,
          pinned: pinned,
          painter: TextPainter(
            text: TextSpan(text: _display(identity), style: labelStyle),
            textDirection: TextDirection.ltr,
            maxLines: 1,
          )..layout(maxWidth: 160),
        ),
      );
    }

    for (final identity in pinned) {
      addLabel(identity, pinned: true);
    }
    if (revealing) {
      for (final node in graph.nodes) {
        addLabel(node.identity, pinned: false);
      }
    }
  }

  /// On-screen node radius, in logical pixels, at which a zoom-revealed
  /// name starts to fade in and is fully shown. The largest disc (26 px)
  /// crosses [revealStart] just past the fitted opening zoom; the smallest
  /// (10 px) is fully named before the 3× zoom limit.
  static const revealStart = 21.0;
  static const revealFull = 27.0;

  /// The labels to draw at [scale], each with its rectangle relative to the
  /// camera origin and its opacity, after priority-order collision
  /// filtering. Allocation is bounded by the 40-node view.
  List<({_LabelPaint label, Rect rect, double opacity})> visibleLabels(
    ConstellationScene scene,
    double scale, {
    double selectionScale = 1,
  }) {
    final visible = <({_LabelPaint label, Rect rect, double opacity})>[];
    for (final label in labels) {
      final nodePaint = nodePaints[label.identity]!;
      final opacity = label.pinned
          ? 1.0
          : ((nodePaint.radius * scale - revealStart) /
                    (revealFull - revealStart))
                .clamp(0.0, 1.0);
      if (opacity == 0) continue;
      final rect = _labelRect(
        scene.positionOf(label.identity) * scale,
        nodePaint,
        label.painter,
        scale,
        selectionScale,
      );
      if (visible.any((accepted) => accepted.rect.overlaps(rect))) continue;
      visible.add((label: label, rect: rect, opacity: opacity));
    }
    return visible;
  }

  static const _labelPadX = 7.0;
  static const _labelPadY = 2.0;

  final IngredientGraph graph;
  final nodePaints = <String, _NodePaint>{};
  final edgePaints = <_EdgePaint>[];
  final labels = <_LabelPaint>[];

  void dispose() {
    for (final label in labels) {
      label.painter.dispose();
    }
    labels.clear();
  }
}

/// A label pill under a node drawn at [screenCenter]: the pill keeps its
/// text size while its distance below the node follows the zoomed radius.
Rect _labelRect(
  Offset screenCenter,
  _NodePaint nodePaint,
  TextPainter painter,
  double scale,
  double selectionScale,
) {
  final radius =
      nodePaint.radius * scale * (nodePaint.selected ? selectionScale : 1);
  return Rect.fromLTWH(
    screenCenter.dx - painter.width / 2 - ConstellationPaintData._labelPadX,
    screenCenter.dy + radius + (nodePaint.selected ? 9 : 5),
    painter.width + ConstellationPaintData._labelPadX * 2,
    painter.height + ConstellationPaintData._labelPadY * 2,
  );
}

String _display(String identity) => identity.isEmpty
    ? identity
    : identity[0].toUpperCase() + identity.substring(1);

final class _NodePaint {
  const _NodePaint({
    required this.radius,
    required this.kind,
    required this.dimmed,
    required this.selected,
    required this.emphasized,
  });

  final double radius;
  final IngredientKind kind;
  final bool dimmed;
  final bool selected;
  final bool emphasized;
}

final class _EdgePaint {
  const _EdgePaint({required this.edge, required this.paint});

  final IngredientEdge edge;
  final Paint paint;
}

final class _LabelPaint {
  const _LabelPaint({
    required this.identity,
    required this.pinned,
    required this.painter,
  });

  final String identity;

  /// Shown at every zoom (search match or selection) rather than revealed
  /// by zooming in.
  final bool pinned;
  final TextPainter painter;
}

/// Paints the constellation through the [camera]. Work per frame is
/// O(nodes + edges) — at the bounded 40-node view that is at most 40
/// glyphs, 780 edge curves, and a fixed label set, with every Paint object
/// and text layout precomputed. The 60fps bar rests on that bound.
///
/// The canvas has no visible border: everything dissolves into the night
/// field over [fadeExtent] at each side, so panning and zooming read as
/// moving through open space rather than inside a box.
class ConstellationPainter extends CustomPainter {
  ConstellationPainter({
    required this.data,
    required this.scene,
    required this.camera,
    required this.selectionScale,
    super.repaint,
  });

  final ConstellationPaintData data;
  final ConstellationScene scene;
  final ConstellationCamera camera;

  /// Radius multiplier for the selected node while its pop plays; 1 at rest
  /// and always 1 under reduced motion.
  final double Function() selectionScale;

  static const fadeExtent = 32.0;

  static final _layerPaint = Paint();
  static final _labelBackdrop = Paint()..color = ZestPalette.peach;
  static final _emphasisRing = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2
    ..color = ZestPalette.peach;
  static final _selectionHalo = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3
    ..color = ZestPalette.grapefruit;

  Size? _fadeSize;
  List<Paint> _fadePaints = const [];

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    final pop = selectionScale();
    canvas.saveLayer(bounds, _layerPaint);

    canvas.save();
    canvas.translate(camera.origin.dx, camera.origin.dy);
    canvas.scale(camera.scale);
    // Edges first so nodes sit on top.
    for (final edgePaint in data.edgePaints) {
      final a = scene.positionOf(edgePaint.edge.aIdentity);
      final b = scene.positionOf(edgePaint.edge.bIdentity);
      final delta = b - a;
      final length = delta.distance;
      // A slight perpendicular bow reads as loose string without changing
      // which pair an edge connects.
      final bow = math.min(14.0, length * 0.08);
      final mid = Offset(a.dx + delta.dx / 2, a.dy + delta.dy / 2);
      final control =
          mid + Offset(-delta.dy, delta.dx) / (length <= 0 ? 1 : length) * bow;
      canvas.drawPath(
        Path()
          ..moveTo(a.dx, a.dy)
          ..quadraticBezierTo(control.dx, control.dy, b.dx, b.dy),
        edgePaint.paint,
      );
    }

    for (final entry in data.nodePaints.entries) {
      final position = scene.positionOf(entry.key);
      final nodePaint = entry.value;
      final radius = nodePaint.selected
          ? nodePaint.radius * pop
          : nodePaint.radius;
      paintIngredientGlyph(
        canvas,
        position,
        radius,
        nodePaint.kind,
        dimmed: nodePaint.dimmed,
      );
      if (nodePaint.emphasized) {
        canvas.drawCircle(position, radius + 3, _emphasisRing);
      }
      if (nodePaint.selected) {
        canvas.drawCircle(position, radius + 5, _selectionHalo);
      }
    }
    canvas.restore();

    // Labels in screen space, so text stays readable at every zoom.
    for (final visible in data.visibleLabels(
      scene,
      camera.scale,
      selectionScale: pop,
    )) {
      final rect = visible.rect.shift(camera.origin);
      final fading = visible.opacity < 1;
      if (fading) {
        canvas.saveLayer(
          rect.inflate(1),
          Paint()..color = Color.fromRGBO(0, 0, 0, visible.opacity),
        );
      }
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(rect.height / 2)),
        _labelBackdrop,
      );
      visible.label.painter.paint(
        canvas,
        Offset(
          rect.left + ConstellationPaintData._labelPadX,
          rect.top + ConstellationPaintData._labelPadY,
        ),
      );
      if (fading) canvas.restore();
    }

    for (final fade in _fadesFor(size)) {
      canvas.drawRect(bounds, fade);
    }
    canvas.restore();
  }

  /// Two alpha masks, one per axis, multiplied into the layer.
  List<Paint> _fadesFor(Size size) {
    if (_fadeSize == size) return _fadePaints;
    final bounds = Offset.zero & size;
    Paint mask(Alignment begin, Alignment end, double extent) {
      final stop = (fadeExtent / extent).clamp(0.0, 0.5);
      return Paint()
        ..blendMode = BlendMode.dstIn
        ..shader = LinearGradient(
          begin: begin,
          end: end,
          colors: const [
            Color(0x00000000),
            Color(0xFF000000),
            Color(0xFF000000),
            Color(0x00000000),
          ],
          stops: [0, stop, 1 - stop, 1],
        ).createShader(bounds);
    }

    _fadeSize = size;
    return _fadePaints = [
      mask(Alignment.centerLeft, Alignment.centerRight, size.width),
      mask(Alignment.topCenter, Alignment.bottomCenter, size.height),
    ];
  }

  @override
  bool shouldRepaint(ConstellationPainter oldDelegate) =>
      !identical(data, oldDelegate.data) ||
      !identical(scene, oldDelegate.scene) ||
      !identical(camera, oldDelegate.camera);
}
