import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/design/zest_tokens.dart';
import '../domain/graph_layout.dart';
import '../domain/ingredient_graph.dart';
import 'constellation_painter.dart';

/// Hit-target bounds. A node of any size answers taps within a 48-logical-
/// pixel diameter around its center ([maxHitRadius]); an edge answers within
/// [edgeHitHalfWidth] of its curve.
///
/// [edgeHitHalfWidth] is a recorded 32-pixel hit-target exception, deliberate
/// because every edge has three non-canvas equivalents at full size: the
/// info-surface button under the canvas, the list-view connection rows, and
/// the shared-recipes sheet each open the same edge without a corridor.
const maxHitRadius = 24.0;
const edgeHitHalfWidth = 16.0;

/// The interactive constellation canvas: the graph painted on a CustomPaint
/// with tap selection of nodes and edges, a settle-in animation, and a short
/// pop on the newly selected node.
///
/// Performance contract (the 60fps bar): the layout is computed once per
/// graph or canvas-size change — never per frame, and never when only the
/// selection or search filter changes. Paint data is prepared once per state
/// change; per animation frame the painter only reads precomputed geometry,
/// so the frame cost is O(nodes + edges) at the bounded 40-node view. Neither
/// animation loops: each plays once and stops. The canvas is decorative and
/// excluded from semantics; the textual route carries the accessible
/// equivalent.
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
    with TickerProviderStateMixin {
  GraphLayout? _layout;
  Map<String, Offset>? _initialPositions;
  Size? _laidOutSize;
  IngredientGraph? _laidOutGraph;
  AnimationController? _settle;
  CurvedAnimation? _curve;
  AnimationController? _pop;
  bool _everAnimated = false;
  ConstellationPaintData? _paintData;

  bool get _reducedMotion => ZestMotion.reduced(context);

  /// Disposes the settle controller together with its curved animation.
  /// The curve must be disposed before its parent controller.
  void _teardownSettle() {
    _curve?.dispose();
    _curve = null;
    _settle?.dispose();
    _settle = null;
    _initialPositions = null;
  }

  void _teardownPop() {
    _pop?.dispose();
    _pop = null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reduced motion requested mid-animation: snap to the final state and
    // stop ticking. Reduced motion never *starts* a controller (see
    // _ensureLayout and didUpdateWidget); this only ends running ones.
    if (_reducedMotion) {
      if (_settle != null) _teardownSettle();
      _teardownPop();
    }
  }

  @override
  void didUpdateWidget(ConstellationCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    final selected = widget.selectedNodeId;
    if (selected != null &&
        selected != oldWidget.selectedNodeId &&
        !_reducedMotion) {
      final pop = _pop ??= AnimationController(
        vsync: this,
        duration: ZestMotion.pop,
      );
      pop.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _teardownSettle();
    _teardownPop();
    _paintData?.dispose();
    super.dispose();
  }

  /// Computes the layout when the graph or the canvas size changed, and —
  /// in motion mode only, and only ever once per State lifetime (guarded by
  /// [_everAnimated]) — plays the short settle from the seeded scatter to
  /// the final positions. Selection and filter changes never reach this.
  void _ensureLayout(Size size) {
    if (identical(_laidOutGraph, widget.graph) && _laidOutSize == size) return;
    _laidOutGraph = widget.graph;
    _laidOutSize = size;
    _layout = GraphLayout.compute(widget.graph, size: size);
    _teardownSettle();
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
        setState(_teardownSettle);
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

  /// The selected node's radius multiplier: a single soft swell that returns
  /// exactly to 1 when the pop completes.
  double get _selectionScale {
    final pop = _pop;
    if (_reducedMotion || pop == null || !pop.isAnimating) return 1;
    final t = Curves.easeOut.transform(pop.value);
    return 1 + 0.22 * math.sin(math.pi * t);
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
      final distance = (local - layout.positionOf(node.identity)).distance;
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
          labelStyle: Theme.of(
            context,
          ).textTheme.labelSmall!.copyWith(color: ZestPalette.leaf),
        );
        // Each prepared paint data owns laid-out TextPainters; dispose the
        // previous set when a new one replaces it, or selection, search, and
        // graph changes would leak up to a label set per rebuild.
        _paintData?.dispose();
        _paintData = paintData;

        ConstellationPainter painter() {
          final progress = _progress;
          return ConstellationPainter(
            data: paintData,
            progress: progress,
            initialPositions: progress < 1 ? _initialPositions : null,
            selectionScale: _selectionScale,
          );
        }

        final animations = <Listenable>[
          if (_settle != null) _settle!,
          if (_pop != null) _pop!,
        ];
        // RepaintBoundary keeps the animations and selection repaints inside
        // this layer instead of the whole page.
        final Widget canvas = animations.isEmpty
            ? ExcludeSemantics(
                child: RepaintBoundary(
                  child: CustomPaint(size: size, painter: painter()),
                ),
              )
            : AnimatedBuilder(
                animation: Listenable.merge(animations),
                builder: (context, _) => ExcludeSemantics(
                  child: RepaintBoundary(
                    child: CustomPaint(size: size, painter: painter()),
                  ),
                ),
              );
        // The gesture layer is decorative too: without this, the detector
        // would surface an unlabeled tap target to screen readers. The list
        // view is the accessible route to every node and edge.
        return ExcludeSemantics(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: _handleTapUp,
            child: canvas,
          ),
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
