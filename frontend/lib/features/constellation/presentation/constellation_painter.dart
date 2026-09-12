import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/design/zest_tokens.dart';
import '../domain/graph_layout.dart';
import '../domain/ingredient_graph.dart';
import '../domain/ingredient_kind.dart';
import 'ingredient_glyph.dart';

/// Node radius mapping; see [GraphLayout.nodeRadius], which the layout also
/// uses so discs are placed with clearance for their painted size.
double constellationNodeRadius(int prevalence, int maxPrevalence) =>
    GraphLayout.nodeRadius(prevalence, maxPrevalence);

/// Everything the painter needs for one canvas state: the graph, its layout,
/// the emphasis implied by the current selection and search filter, each
/// node's glyph kind, and the collision-filtered label set. Prepared once
/// per state change — never per animation frame — so the settle and
/// selection animations repaint without re-laying out text or allocating
/// Paint objects (glyph paints are cached per kind in ingredient_glyph).
///
/// The canvas paints on the Night Garden field: glyph discs colored by
/// [IngredientKind], peach string lines whose opacity and width carry edge
/// weight, celery lines for the selected neighborhood, and a grapefruit
/// line and halo for the selection.
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
        text: TextSpan(text: _display(identity), style: labelStyle),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout(maxWidth: 160);
      final rect = Rect.fromLTWH(
        position.dx - painter.width / 2 - _labelPadX,
        position.dy + nodePaint.labelOffset,
        painter.width + _labelPadX * 2,
        painter.height + _labelPadY * 2,
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

  static const _labelPadX = 7.0;
  static const _labelPadY = 2.0;

  final IngredientGraph graph;
  final GraphLayout layout;
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

  /// Labels sit below the disc and clear the selection halo.
  double get labelOffset => radius + (selected ? 9 : 5);
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
/// bounded 40-node view that is at most 40 glyphs, 780 edge curves, and a
/// fixed label set, with every Paint object and text layout precomputed. The
/// 60fps bar rests on that bound.
class ConstellationPainter extends CustomPainter {
  ConstellationPainter({
    required this.data,
    required this.progress,
    this.initialPositions,
    this.selectionScale = 1,
  });

  final ConstellationPaintData data;

  /// 0 = initial scatter, 1 = settled layout. Reduced motion always renders
  /// with 1 and never creates an animation.
  final double progress;

  /// The scatter the settle animation starts from; null when rendering the
  /// settled layout directly.
  final Map<String, Offset>? initialPositions;

  /// Radius multiplier for the selected node while its pop plays; 1 at rest
  /// and always 1 under reduced motion.
  final double selectionScale;

  static final _labelBackdrop = Paint()..color = ZestPalette.peach;
  static final _emphasisRing = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2
    ..color = ZestPalette.peach;
  static final _selectionHalo = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3
    ..color = ZestPalette.grapefruit;

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
      final position = _positionOf(entry.key);
      final nodePaint = entry.value;
      final radius = nodePaint.selected
          ? nodePaint.radius * selectionScale
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

    for (final label in data.labels) {
      final position = _positionOf(label.identity);
      final nodePaint = data.nodePaints[label.identity]!;
      final rect = Rect.fromLTWH(
        position.dx -
            label.painter.width / 2 -
            ConstellationPaintData._labelPadX,
        position.dy + nodePaint.labelOffset,
        label.painter.width + ConstellationPaintData._labelPadX * 2,
        label.painter.height + ConstellationPaintData._labelPadY * 2,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(rect.height / 2)),
        _labelBackdrop,
      );
      label.painter.paint(
        canvas,
        Offset(
          rect.left + ConstellationPaintData._labelPadX,
          rect.top + ConstellationPaintData._labelPadY,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(ConstellationPainter oldDelegate) =>
      progress != oldDelegate.progress ||
      selectionScale != oldDelegate.selectionScale ||
      !identical(data, oldDelegate.data) ||
      !identical(initialPositions, oldDelegate.initialPositions);
}
