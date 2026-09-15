import 'dart:math' as math;
import 'dart:ui';

import 'ingredient_graph.dart';

/// Deterministic force-directed layout for the bounded constellation graph.
///
/// The computation is deliberately bounded: a seeded initial placement, a
/// fixed number of force iterations with a fixed cooling schedule, a fit to
/// the canvas, and a fixed number of collision rounds — no unbounded
/// simulation and no wall-clock input. The same graph on the same canvas
/// always produces the same positions, at every node count the bounded view
/// allows (40 nodes compute in a few milliseconds, so no isolate is needed
/// and the layout never runs per frame).
///
/// Dense collections are the normal case: the most-used cocktail ingredients
/// nearly all share recipes with each other, so a classic spring per edge
/// sums to a pull that collapses every node into the center. Springs are
/// therefore scaled down by the graph's mean degree — relationships still
/// pull related ingredients closer, but connectivity alone cannot clump the
/// graph — and the settled shape is stretched to use the whole canvas before
/// a seeded scatter loosens the shape and discs are separated by their
/// painted radius.
///
/// The layout is mode-independent: motion and reduced-motion presentation
/// both render these final positions; only the presentation decides whether
/// to arrive at them through a short settle animation.
final class GraphLayout {
  GraphLayout._(this._positions);

  /// Fixed by default so tests and rendering agree without configuration.
  static const defaultSeed = 20260912;

  /// Fixed iteration budget — the layout is never simulated indefinitely.
  static const defaultIterations = 300;

  /// Keeps node bodies and labels inside the canvas.
  static const inset = 34.0;

  static const _minTemperature = 0.5;

  /// Radians between successive spiral placements: an even, deterministic
  /// scatter with no clustering.
  static const _goldenAngle = 2.399963229728653;

  /// Extra space kept between neighboring discs beyond their radii.
  static const clearanceGap = 18.0;

  /// Seeded scatter applied after the fit, as a share of the ideal edge
  /// length: breaks the even lattice a force layout converges to so the
  /// constellation reads as loose and wild rather than gridded.
  static const _chaos = 0.42;

  /// Upper bound on collision-resolution rounds.
  static const _separationRounds = 120;

  /// Strength of the elliptical pull toward the canvas center, relative to
  /// the ideal edge length at the canvas edge.
  static const _gravity = 3.0;

  /// The fit stops this far inside the drawable bounds, leaving collision
  /// separation room to move nodes before they reach a wall — otherwise the
  /// outer ring gets pressed flat into rows along the edges.
  static const _fitMargin = 18.0;

  /// Node radius mapping, shared by the layout (for collision clearance) and
  /// the painter: the radius grows with the *square root* of prevalence, so
  /// node area grows roughly linearly with the distinct-recipe count, bounded
  /// to 10–26 logical pixels. Documented contract — changing these bounds
  /// changes the constellation's visual grammar.
  static double nodeRadius(int prevalence, int maxPrevalence) {
    const minRadius = 10.0;
    const maxRadius = 26.0;
    final t = maxPrevalence <= 1 ? 0.55 : math.sqrt(prevalence / maxPrevalence);
    return lerpDouble(minRadius, maxRadius, t.clamp(0.0, 1.0))!;
  }

  final Map<String, Offset> _positions;

  /// Computes final positions for [graph] inside [size]. [seed] and
  /// [iterations] are fixed by default; tests may vary them to prove
  /// determinism and the iteration bound. `iterations: 0` returns the seeded
  /// initial placement untouched by forces, fitting, or separation.
  static GraphLayout compute(
    IngredientGraph graph, {
    required Size size,
    int seed = defaultSeed,
    int iterations = defaultIterations,
  }) {
    final random = math.Random(seed);
    final center = size.center(Offset.zero);
    final bounds = Rect.fromLTWH(
      inset,
      inset,
      math.max(1.0, size.width - inset * 2),
      math.max(1.0, size.height - inset * 2),
    );
    final spreadX = bounds.width / 2;
    final spreadY = bounds.height / 2;
    final nodes = graph.nodes;

    // Seeded initial placement: a golden-angle spiral over an ellipse that
    // fills the canvas, most prevalent ingredients nearest the center, with
    // a little seeded angular jitter.
    final positions = <String, Offset>{
      for (var i = 0; i < nodes.length; i++)
        nodes[i].identity: () {
          final radius = math.sqrt((i + 0.5) / nodes.length);
          final angle = i * _goldenAngle + (random.nextDouble() - 0.5) * 0.6;
          return Offset(
            center.dx + math.cos(angle) * radius * spreadX,
            center.dy + math.sin(angle) * radius * spreadY,
          );
        }(),
    };
    if (iterations <= 0 || nodes.length < 2) {
      return GraphLayout._(Map.unmodifiable(_clampAll(positions, bounds)));
    }

    // Fruchterman–Reingold-style forces: repulsion between all pairs,
    // attraction along edges that grows with the shared recipe count and is
    // normalized by the mean degree, a centroid recentering, and a linear
    // cooling schedule so the last iteration moves by almost nothing.
    final ideal = math.sqrt(bounds.width * bounds.height / nodes.length);
    final maxWeight = graph.edges.fold(
      1,
      (weight, edge) => math.max(weight, edge.weight),
    );
    final meanDegree = 2 * graph.edges.length / nodes.length;
    final springScale = 2 / math.max(2.0, meanDegree);
    final maxTemperature = math.max(
      _minTemperature,
      math.max(spreadX, spreadY) / 2,
    );

    Offset positionOf(String identity) => positions[identity]!;

    for (var step = 0; step < iterations; step++) {
      final temperature = _lerp(
        maxTemperature,
        _minTemperature,
        step / math.max(1, iterations - 1),
      );
      final displacement = <String, Offset>{};

      for (var i = 0; i < nodes.length; i++) {
        final a = nodes[i].identity;
        for (var j = i + 1; j < nodes.length; j++) {
          final b = nodes[j].identity;
          final delta = positionOf(a) - positionOf(b);
          final distance = math.max(delta.distance, 0.001);
          // Direction away from each other, magnitude k²/d.
          final push = delta / distance * (ideal * ideal / distance);
          displacement[a] = (displacement[a] ?? Offset.zero) + push;
          displacement[b] = (displacement[b] ?? Offset.zero) - push;
        }
      }

      for (final edge in graph.edges) {
        final delta = positionOf(edge.bIdentity) - positionOf(edge.aIdentity);
        final distance = math.max(delta.distance, 0.001);
        // Stronger shared count pulls harder: 0.25–1.0 of the base spring,
        // divided across the average number of connections.
        final weightFactor = 0.25 + 0.75 * edge.weight / maxWeight;
        final pull =
            delta /
            distance *
            (distance * distance / ideal) *
            weightFactor *
            springScale;
        displacement[edge.aIdentity] =
            (displacement[edge.aIdentity] ?? Offset.zero) + pull;
        displacement[edge.bIdentity] =
            (displacement[edge.bIdentity] ?? Offset.zero) - pull;
      }

      // Gentle elliptical gravity: without it, repulsion pins the outer
      // ring in stiff rows along the canvas walls. The fit afterwards
      // restores the full spread.
      for (final node in nodes) {
        final fromCenter = positionOf(node.identity) - center;
        final gravity =
            Offset(fromCenter.dx / spreadX, fromCenter.dy / spreadY) *
            ideal *
            _gravity;
        displacement[node.identity] =
            (displacement[node.identity] ?? Offset.zero) - gravity;
      }

      for (final node in nodes) {
        final offset = displacement[node.identity] ?? Offset.zero;
        final distance = offset.distance;
        final move = distance <= temperature
            ? offset
            : offset / distance * temperature;
        positions[node.identity] = positionOf(node.identity) + move;
      }
      _recenter(positions, center);
      _clampAll(positions, bounds);
    }

    final fitBounds = bounds.deflate(_fitMargin);
    _fitToBounds(positions, fitBounds);
    for (final node in nodes) {
      final angle = random.nextDouble() * math.pi * 2;
      final reach = random.nextDouble() * ideal * _chaos;
      positions[node.identity] = _clampPoint(
        positionOf(node.identity) +
            Offset(math.cos(angle), math.sin(angle)) * reach,
        fitBounds,
      );
    }
    _separate(graph, positions, bounds);
    return GraphLayout._(Map.unmodifiable(positions));
  }

  /// Final position of one node. [identity] must be a node of the graph the
  /// layout was computed from.
  Offset positionOf(String identity) => _positions[identity]!;

  /// Final positions, keyed by identity.
  Map<String, Offset> get positions => _positions;

  static void _recenter(Map<String, Offset> positions, Offset center) {
    if (positions.isEmpty) return;
    var sum = Offset.zero;
    for (final position in positions.values) {
      sum += position;
    }
    final shift = center - sum / positions.length.toDouble();
    for (final identity in positions.keys.toList()) {
      positions[identity] = positions[identity]! + shift;
    }
  }

  /// Stretches the settled shape so it spans the drawable bounds on each
  /// axis; relative placement is preserved within each axis.
  static void _fitToBounds(Map<String, Offset> positions, Rect bounds) {
    var minX = double.infinity;
    var maxX = double.negativeInfinity;
    var minY = double.infinity;
    var maxY = double.negativeInfinity;
    for (final position in positions.values) {
      minX = math.min(minX, position.dx);
      maxX = math.max(maxX, position.dx);
      minY = math.min(minY, position.dy);
      maxY = math.max(maxY, position.dy);
    }
    final width = maxX - minX;
    final height = maxY - minY;
    for (final identity in positions.keys.toList()) {
      final position = positions[identity]!;
      positions[identity] = Offset(
        width < 1
            ? bounds.center.dx
            : bounds.left + (position.dx - minX) / width * bounds.width,
        height < 1
            ? bounds.center.dy
            : bounds.top + (position.dy - minY) / height * bounds.height,
      );
    }
  }

  /// Pushes overlapping discs apart until every pair clears its combined
  /// painted radius plus [clearanceGap], within a fixed number of rounds.
  /// Coincident pairs separate along a direction derived from their indices,
  /// so the result stays deterministic.
  static void _separate(
    IngredientGraph graph,
    Map<String, Offset> positions,
    Rect bounds,
  ) {
    final nodes = graph.nodes;
    final radii = [
      for (final node in nodes)
        nodeRadius(node.prevalence, graph.maxPrevalence),
    ];
    for (var round = 0; round < _separationRounds; round++) {
      var moved = false;
      for (var i = 0; i < nodes.length; i++) {
        for (var j = i + 1; j < nodes.length; j++) {
          final a = nodes[i].identity;
          final b = nodes[j].identity;
          final delta = positions[b]! - positions[a]!;
          final needed = radii[i] + radii[j] + clearanceGap;
          final distance = delta.distance;
          if (distance >= needed) continue;
          final direction = distance < 0.001
              ? Offset(math.cos(i * 1.3 + j), math.sin(i * 1.3 + j))
              : delta / distance;
          final push = direction * ((needed - distance) / 2);
          positions[a] = _clampPoint(positions[a]! - push, bounds);
          positions[b] = _clampPoint(positions[b]! + push, bounds);
          moved = true;
        }
      }
      if (!moved) break;
    }
  }

  static Offset _clampPoint(Offset point, Rect bounds) => Offset(
    point.dx.clamp(bounds.left, bounds.right),
    point.dy.clamp(bounds.top, bounds.bottom),
  );

  static Map<String, Offset> _clampAll(
    Map<String, Offset> positions,
    Rect bounds,
  ) {
    for (final identity in positions.keys.toList()) {
      positions[identity] = _clampPoint(positions[identity]!, bounds);
    }
    return positions;
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;
}
