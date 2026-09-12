import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../domain/graph_layout.dart';
import '../domain/ingredient_graph.dart';

/// Node radius mapping: the radius grows with the *square root* of
/// prevalence, so node area grows roughly linearly with the distinct-recipe
/// count, bounded to 10–26 logical pixels. Documented contract — changing
/// these bounds changes the constellation's visual grammar.
double constellationNodeRadius(int prevalence, int maxPrevalence) {
  const minRadius = 10.0;
  const maxRadius = 26.0;
  final t = maxPrevalence <= 1 ? 0.55 : math.sqrt(prevalence / maxPrevalence);
  return lerpDouble(minRadius, maxRadius, t.clamp(0.0, 1.0))!;
}

/// Everything the painter needs for one canvas state: the graph, its layout,
/// the emphasis implied by the current selection and search filter, and the
/// collision-filtered label set. Prepared once per state change — never per
/// animation frame — so the settle animation repaints without reallocating
/// geometry, re-laying out text, or allocating Paint objects: every Paint
/// (edge stroke, node fill and stroke, shared label backdrop) is built here
/// with its color, alpha, and stroke width baked in.
///
/// Label rule (documented contract):
/// 1. When a search filter is active, every matching node is a candidate.
/// 2. When something is selected, its neighborhood nodes are candidates.
/// 3. Otherwise (and as filler), the top 8 nodes by prevalence are
///    candidates.
/// Candidates are accepted in that priority order, skipping any label whose
/// padded text rectangle would overlap an already-accepted label — legibility
/// beats completeness, and the search field plus the info surface below the
/// canvas always name the selected things in text.
final class ConstellationPaintData {
  ConstellationPaintData({
    required this.graph,
    required this.layout,
    required IngredientNode? selectedNode,
    required IngredientEdge? selectedEdge,
    required String query,
    required ColorScheme colors,
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

    IngredientEdge? emphasizedEdge;
    for (final edge in graph.edges) {
      if (selectedEdge != null && identical(edge, selectedEdge)) {
        emphasizedEdge = edge;
      }
    }

    final maxWeight = graph.edges.fold(1, (w, e) => math.max(w, e.weight));

    // Nodes: both Paint objects (fill and stroke) are built here, with the
    // dimmed variants baked in, so paint() never allocates.
    for (final node in graph.nodes) {
      final isSelected = selectedNode?.identity == node.identity;
      final isEmphasized = emphasized.contains(node.identity);
      final dimmed =
          (trimmedQuery.isNotEmpty && !matching.contains(node.identity)) ||
          ((selectedNode != null || selectedEdge != null) && !isEmphasized);
      final fill = isSelected ? colors.tertiaryContainer : colors.secondaryContainer;
      final stroke = isEmphasized ? colors.primary : colors.outline;
      nodePaints[node.identity] = _NodePaint(
        radius: constellationNodeRadius(node.prevalence, graph.maxPrevalence),
        fillPaint: Paint()..color = dimmed
            ? fill.withValues(alpha: 0.15)
            : fill,
        strokePaint: Paint()
          ..color = dimmed
              ? stroke.withValues(alpha: 0.15)
              : stroke
          ..style = PaintingStyle.stroke
          ..strokeWidth = isEmphasized ? 3 : 2,
      );
    }

    // Edges: one stroke Paint per edge, weight-based opacity and width
    // baked in.
    for (final edge in graph.edges) {
      final isSelected = identical(edge, emphasizedEdge);
      final inNeighborhood =
          selectedNode != null && edge.touches(selectedNode.identity);
      final bothMatch =
          matching.contains(edge.aIdentity) && matching.contains(edge.bIdentity);
      final dimmed =
          (trimmedQuery.isNotEmpty && !bothMatch) ||
          ((selectedNode != null || selectedEdge != null) &&
              !inNeighborhood &&
              !isSelected);
      final baseOpacity = graph.edges.length <= 1
          ? 0.45
          : 0.2 +
                0.5 *
                    ((edge.weight - 1) /
                        math.max(1, maxWeight - 1)).clamp(0.0, 1.0);
      final color = isSelected
          ? colors.tertiary
          : inNeighborhood
          ? colors.primary
          : colors.outline;
      final opacity = isSelected
          ? 1.0
          : inNeighborhood
          ? 0.85
          : baseOpacity;
      edgePaints.add(
        _EdgePaint(
          edge: edge,
          paint: Paint()
            ..color = dimmed
                ? color.withValues(alpha: 0.06)
                : color.withValues(alpha: opacity)
            ..style = PaintingStyle.stroke
            ..strokeWidth = isSelected
                ? 1.0 + 2.5 * (edge.weight - 1) / math.max(1, maxWeight - 1) + 1.5
                : 1.0 + 2.5 * (edge.weight - 1) / math.max(1, maxWeight - 1)
            ..strokeCap = StrokeCap.round,
        ),
      );
    }

    // One shared label backdrop Paint: every label uses the same translucent
    // surface color, so a single Paint serves the whole label set.
    labelBackdropPaint = Paint()
      ..color = colors.surface.withValues(alpha: 0.85);

    // Labels: candidates in priority order, then greedy collision filtering.
    final candidates = <String>[
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
      if (trimmedQuery.isEmpty)
        for (final node in graph.nodes.take(labelTopCount)) node.identity,
    ];
    final acceptedRects = <Rect>[];
    final seen = <String>{};
    for (final identity in candidates) {
      if (!seen.add(identity)) continue;
      final nodePaint = nodePaints[identity];
      if (nodePaint == null) continue;
      final position = layout.positionOf(identity);
      final painter = TextPainter(
        text: TextSpan(text: identity, style: labelStyle),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout(maxWidth: 160);
      final rect = Rect.fromLTWH(
        position.dx - painter.width / 2 - 4,
        position.dy + nodePaint.radius + 2,
        painter.width + 8,
        painter.height + 4,
      );
      final overlaps = acceptedRects.any((accepted) => accepted.overlaps(rect));
      if (overlaps) {
        painter.dispose();
        continue;
      }
      acceptedRects.add(rect);
      labels.add(_LabelPaint(identity: identity, painter: painter));
    }
  }

  /// How many top-prevalence nodes get labels when nothing focuses attention.
  static const labelTopCount = 8;

  final IngredientGraph graph;
  final GraphLayout layout;
  final nodePaints = <String, _NodePaint>{};
  final edgePaints = <_EdgePaint>[];
  final labels = <_LabelPaint>[];

  /// Shared by every label backdrop — identical color across the label set.
  late final Paint labelBackdropPaint;

  void dispose() {
    for (final label in labels) {
      label.painter.dispose();
    }
    labels.clear();
  }
}

final class _NodePaint {
  const _NodePaint({
    required this.radius,
    required this.fillPaint,
    required this.strokePaint,
  });

  final double radius;
  final Paint fillPaint;
  final Paint strokePaint;
}

final class _EdgePaint {
  const _EdgePaint({required this.edge, required this.paint});

  final IngredientEdge edge;
  final Paint paint;
}

final class _LabelPaint {
  const _LabelPaint({required this.identity, required this.painter});

  final String identity;
  final TextPainter painter;
}

/// Paints the constellation. Work per frame is O(nodes + edges) — at the
/// bounded 40-node view that is at most 40 circles, 780 edge curves, and a
/// fixed label set, with every Paint object and text layout precomputed in
/// [ConstellationPaintData]. The 60fps bar rests on that bound.
class ConstellationPainter extends CustomPainter {
  ConstellationPainter({
    required this.data,
    required this.progress,
    this.initialPositions,
  });

  final ConstellationPaintData data;

  /// 0 = initial scatter, 1 = settled layout. Reduced motion always renders
  /// with 1 and never creates an animation.
  final double progress;

  /// The scatter the settle animation starts from; null when rendering the
  /// settled layout directly.
  final Map<String, Offset>? initialPositions;

  Offset _positionOf(String identity) {
    final settled = data.layout.positionOf(identity);
    final initial = initialPositions?[identity];
    if (initial == null || progress >= 1) return settled;
    return Offset.lerp(initial, settled, progress)!;
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Edges first so nodes sit on top.
    for (final edgePaint in data.edgePaints) {
      final a = _positionOf(edgePaint.edge.aIdentity);
      final b = _positionOf(edgePaint.edge.bIdentity);
      final delta = b - a;
      final length = delta.distance;
      // A slight perpendicular bow gives the organic cut-paper feel without
      // changing which pair an edge connects.
      final bow = math.min(14.0, length * 0.08);
      final mid = Offset(a.dx + delta.dx / 2, a.dy + delta.dy / 2);
      final control = mid + Offset(-delta.dy, delta.dx) / (length <= 0 ? 1 : length) * bow;
      canvas.drawPath(
        Path()
          ..moveTo(a.dx, a.dy)
          ..quadraticBezierTo(control.dx, control.dy, b.dx, b.dy),
        edgePaint.paint,
      );
    }

    for (final entry in data.nodePaints.entries) {
      final position = _positionOf(entry.key);
      final nodePaint = entry.value;
      canvas.drawCircle(position, nodePaint.radius, nodePaint.fillPaint);
      canvas.drawCircle(position, nodePaint.radius, nodePaint.strokePaint);
    }

    for (final label in data.labels) {
      final position = _positionOf(label.identity);
      final nodePaint = data.nodePaints[label.identity]!;
      final anchor = Offset(
        position.dx - label.painter.width / 2,
        position.dy + nodePaint.radius + 4,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            anchor.dx - 4,
            anchor.dy - 2,
            label.painter.width + 8,
            label.painter.height + 4,
          ),
          const Radius.circular(6),
        ),
        data.labelBackdropPaint,
      );
      label.painter.paint(canvas, anchor);
    }
  }

  @override
  bool shouldRepaint(ConstellationPainter oldDelegate) =>
      progress != oldDelegate.progress ||
      !identical(data, oldDelegate.data) ||
      !identical(initialPositions, oldDelegate.initialPositions);
}
