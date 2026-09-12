import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/design/zest_tokens.dart';
import '../domain/graph_layout.dart';
import '../domain/ingredient_graph.dart';
import 'constellation_painter.dart';

/// Hit-target bounds. A node of any size answers taps within a 48-logical-
/// pixel diameter around its center ([maxHitRadius]); an edge answers within
/// [edgeHitHalfWidth] of its curve. Edges also open from the selection info
/// surface and the list view, so the corridor is a bonus affordance rather
/// than the only route.
const maxHitRadius = 24.0;
const edgeHitHalfWidth = 16.0;

/// The interactive constellation canvas: the graph painted on a CustomPaint
/// with tap selection of nodes and edges and a settle-in animation.
///
/// Performance contract (the 60fps bar): the layout is computed once per
/// graph or canvas-size change — never per frame, and never when only the
/// selection or search filter changes. Paint data is prepared once per state
/// change; per animation frame the painter only reads precomputed geometry,
/// so the frame cost is O(nodes + edges) at the bounded 40-node view. The
/// canvas is decorative and excluded from semantics; the textual route
/// carries the accessible equivalent.
class ConstellationCanvas extends StatefulWidget {
  const ConstellationCanvas({
    super.key,
    required this.graph,
    required this.onSelectNode,
    required this.onSelectEdge,
    this.selectedNodeId,
    this.selectedEdge,
    this.query = '',
  });

  final IngredientGraph graph;
  final String? selectedNodeId;
  final IngredientEdge? selectedEdge;
  final ValueChanged<String?> onSelectNode;
  final ValueChanged<IngredientEdge?> onSelectEdge;
  final String query;

  @override
  State<ConstellationCanvas> createState() => _ConstellationCanvasState();
}

class _ConstellationCanvasState extends State<ConstellationCanvas>
    with SingleTickerProviderStateMixin {
  GraphLayout? _layout;
  Map<String, Offset>? _initialPositions;
  Size? _laidOutSize;
  IngredientGraph? _laidOutGraph;
  AnimationController? _settle;
  CurvedAnimation? _curve;
  bool _everAnimated = false;

  bool get _reducedMotion => ZestMotion.reduced(context);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reduced motion requested mid-settle: snap to the final layout and stop
    // ticking. Reduced motion never *starts* a controller (see
    // _ensureLayout); this only ends one that was already running.
    if (_reducedMotion && _settle != null) {
      final settle = _settle!;
      _settle = null;
      _curve = null;
      _initialPositions = null;
      settle.dispose();
    }
  }

  @override
  void dispose() {
    _settle?.dispose();
    super.dispose();
  }

  /// Computes the layout when the graph or the canvas size changed, and —
  /// in motion mode only, and only ever once per layout — plays the short
  /// settle from the seeded scatter to the final positions. Selection and
  /// filter changes never reach this.
  void _ensureLayout(Size size) {
    if (identical(_laidOutGraph, widget.graph) && _laidOutSize == size) return;
    _laidOutGraph = widget.graph;
    _laidOutSize = size;
    _layout = GraphLayout.compute(widget.graph, size: size);
    _curve = null;
    _settle?.dispose();
    _settle = null;
    _initialPositions = null;
    if (widget.graph.nodes.length < 2) return;
    if (_reducedMotion || _everAnimated) return;
    _everAnimated = true;
    // Reduced motion creates no controller at all; see _progress.
    final scatter = _Scatter.scatter(widget.graph, size);
    _initialPositions = scatter;
    final controller = AnimationController(
      vsync: this,
      duration: ZestMotion.duration(context, ZestMotion.enter),
    );
    controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _curve = null;
          _settle?.dispose();
          _settle = null;
          _initialPositions = null;
        });
      }
    });
    _settle = controller;
    _curve = CurvedAnimation(parent: controller, curve: ZestMotion.easeOut);
    controller.forward();
  }

  /// The painter progress: 1 (settled) whenever reduced motion is active or
  /// no settle animation exists — reduced motion never creates an
  /// AnimationController, so nothing can tick.
  double get _progress {
    final curve = _curve;
    if (_reducedMotion || curve == null || _initialPositions == null) return 1;
    return curve.value;
  }

  void _handleTapUp(TapUpDetails details) {
    final layout = _layout;
    if (layout == null) return;
    final local = details.localPosition;

    // Nodes first: generous radius so even the smallest node offers a
    // 48-pixel effective target.
    String? bestNode;
    var bestDistance = double.infinity;
    for (final node in widget.graph.nodes) {
      final paintRadius = constellationNodeRadius(
        node.prevalence,
        widget.graph.maxPrevalence,
      );
      final distance =
          (local - layout.positionOf(node.identity)).distance;
      if (distance <= math.max(paintRadius, maxHitRadius) &&
          distance < bestDistance) {
        bestDistance = distance;
        bestNode = node.identity;
      }
    }
    if (bestNode != null) {
      widget.onSelectEdge(null);
      widget.onSelectNode(bestNode);
      return;
    }

    for (final edge in widget.graph.edges) {
      final a = layout.positionOf(edge.aIdentity);
      final b = layout.positionOf(edge.bIdentity);
      if (_distanceToSegment(local, a, b) <= edgeHitHalfWidth) {
        widget.onSelectNode(null);
        widget.onSelectEdge(edge);
        return;
      }
    }

    // Empty canvas: clear whatever is selected.
    widget.onSelectNode(null);
    widget.onSelectEdge(null);
  }

  static double _distanceToSegment(Offset point, Offset a, Offset b) {
    final ab = b - a;
    final lengthSquared = ab.distanceSquared;
    if (lengthSquared == 0) return (point - a).distance;
    final ap = point - a;
    var t = (ap.dx * ab.dx + ap.dy * ab.dy) / lengthSquared;
    t = t.clamp(0.0, 1.0);
    return (point - (a + ab * t)).distance;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        _ensureLayout(size);
        final layout = _layout;
        if (layout == null || size.isEmpty) {
          return const SizedBox.expand();
        }
        final paintData = ConstellationPaintData(
          graph: widget.graph,
          layout: layout,
          selectedNode: widget.selectedNodeId == null
              ? null
              : widget.graph.node(widget.selectedNodeId!),
          selectedEdge: widget.selectedEdge,
          query: widget.query,
          colors: Theme.of(context).colorScheme,
          labelStyle: Theme.of(context).textTheme.bodySmall!,
        );
        final progress = _progress;
        final initial = progress < 1 ? _initialPositions : null;
        final painter = ConstellationPainter(
          data: paintData,
          progress: progress,
          initialPositions: initial,
        );
        Widget canvas = ExcludeSemantics(
          // RepaintBoundary keeps the settle animation and any selection
          // repaints inside this layer instead of the whole page.
          child: RepaintBoundary(
            child: CustomPaint(size: size, painter: painter),
          ),
        );
        final settle = _settle;
        if (settle != null) {
          canvas = AnimatedBuilder(
            animation: settle,
            builder: (context, _) {
              // Rebuild only the painter wrapper as the settle progresses;
              // the paint data above is captured and shared across ticks.
              return ExcludeSemantics(
                child: RepaintBoundary(
                  child: CustomPaint(
                    size: size,
                    painter: ConstellationPainter(
                      data: paintData,
                      progress: _curve?.value ?? 1,
                      initialPositions: _initialPositions,
                    ),
                  ),
                ),
              );
            },
          );
        }
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: _handleTapUp,
          child: canvas,
        );
      },
    );
  }
}

/// The seeded initial scatter the settle animation starts from, derived from
/// the same deterministic layout (iterations: 0 = the clamped seeded
/// spiral), pulled toward the center. The whole motion path — scatter,
/// settle, final — is deterministic.
class _Scatter {
  static Map<String, Offset> scatter(IngredientGraph graph, Size size) {
    final layout = GraphLayout.compute(graph, size: size, iterations: 0);
    final center = size.center(Offset.zero);
    return {
      for (final entry in layout.positions.entries)
        entry.key: Offset.lerp(center, entry.value, 0.35)!,
    };
  }
}
