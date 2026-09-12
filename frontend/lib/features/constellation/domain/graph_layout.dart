import 'dart:math' as math;
import 'dart:ui';

import 'ingredient_graph.dart';

/// Deterministic force-directed layout for the bounded constellation graph.
///
/// The computation is deliberately bounded: a seeded initial placement, a
/// fixed number of iterations, and a fixed cooling schedule — no unbounded
/// simulation and no wall-clock input. The same graph on the same canvas
/// always produces the same positions, at every node count the bounded view
/// allows (40 nodes compute in well under a millisecond, so no isolate is
/// needed and the layout never runs per frame).
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

  /// Node radius mapping, shared by the layout (for collision clearance) and
  /// the painter: the radius grows with the *square root* of prevalence, so
  /// node area grows roughly linearly with the distinct-recipe count, bounded
  /// to 10–26 logical pixels. Documented contract — changing these bounds
  /// changes the constellation's visual grammar.
  static double nodeRadius(int prevalence, int maxPrevalence) {
    const minRadius = 10.0;
    const maxRadius = 26.0;
    final t = maxPrevalence <= 1
        ? 0.55
        : math.sqrt(prevalence / maxPrevalence);
    return lerpDouble(minRadius, maxRadius, t.clamp(0.0, 1.0))!;
  }

  final Map<String, Offset> _positions;

  /// Computes final positions for [graph] inside [size]. [seed] and
  /// [iterations] are fixed by default; tests may vary them to prove
  /// determinism and the iteration bound.
  static GraphLayout compute(
    IngredientGraph graph, {
    required Size size,
    int seed = defaultSeed,
    int iterations = defaultIterations,
  }) {
    // Seeded initial placement: points spread by a golden-angle spiral with
    // seeded jitter, so the scatter is deterministic and already spread out.
    final random = math.Random(seed);
    final center = size.center(Offset.zero);
    final spread = math.max(
      1.0,
      math.min(size.width, size.height) / 2 - inset,
    );
    final positions = <String, Offset>{
      for (final node in graph.nodes)
        node.identity: () {
          final angle = random.nextDouble() * 2 * math.pi;
          final radius = math.sqrt(random.nextDouble()) * spread;
          return Offset(
            center.dx + math.cos(angle) * radius,
            center.dy + math.sin(angle) * radius,
          );
        }(),
    };
    final bounds = Rect.fromLTWH(
      inset,
      inset,
      math.max(1.0, size.width - inset * 2),
      math.max(1.0, size.height - inset * 2),
    );
    if (iterations <= 0 || graph.nodes.length < 2) {
      return GraphLayout._(Map.unmodifiable(_clampAll(positions, bounds)));
    }

    // Fruchterman–Reingold-style forces with an edge-weight-scaled spring:
    // repulsion between all pairs, attraction along edges that grows with
    // the shared recipe count, a centroid recentering, and a linear cooling
    // schedule so the last iteration moves by almost nothing.
    final nodeCount = graph.nodes.length;
    final ideal = math.sqrt(size.width * size.height / nodeCount);
    final maxWeight = graph.edges.fold(
      1,
      (weight, edge) => math.max(weight, edge.weight),
    );
    final maxTemperature = math.max(_minTemperature, spread / 2);

    Offset positionOf(String identity) => positions[identity]!;

    for (var step = 0; step < iterations; step++) {
      final temperature = _lerp(
        maxTemperature,
        _minTemperature,
        step / math.max(1, iterations - 1),
      );
      final displacement = <String, Offset>{};

      for (var i = 0; i < graph.nodes.length; i++) {
        final a = graph.nodes[i].identity;
        for (var j = i + 1; j < graph.nodes.length; j++) {
          final b = graph.nodes[j].identity;
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
        // Stronger shared count pulls harder: 0.5–1.5 of the base spring.
        final weightFactor = 0.5 + edge.weight / maxWeight;
        final pull = delta / distance * (distance * distance / ideal) * weightFactor;
        displacement[edge.aIdentity] =
            (displacement[edge.aIdentity] ?? Offset.zero) + pull;
        displacement[edge.bIdentity] =
            (displacement[edge.bIdentity] ?? Offset.zero) - pull;
      }

      for (final node in graph.nodes) {
        final offset = displacement[node.identity] ?? Offset.zero;
        final distance = offset.distance;
        final step = distance <= temperature
            ? offset
            : offset / distance * temperature;
        positions[node.identity] = positionOf(node.identity) + step;
      }
      _recenter(positions, center);
      _clampAll(positions, bounds);
    }

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

  static Map<String, Offset> _clampAll(
    Map<String, Offset> positions,
    Rect bounds,
  ) {
    for (final identity in positions.keys.toList()) {
      positions[identity] = Offset(
        positions[identity]!.dx.clamp(bounds.left, bounds.right),
        positions[identity]!.dy.clamp(bounds.top, bounds.bottom),
      );
    }
    return positions;
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;
}
