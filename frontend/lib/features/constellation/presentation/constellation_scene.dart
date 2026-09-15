import 'dart:math' as math;
import 'dart:ui';

import '../domain/graph_layout.dart';
import '../domain/ingredient_graph.dart';

/// The live constellation: where every node is drawn right now, in world
/// coordinates (the space [GraphLayout] computed positions in).
///
/// Each node has an *anchor* — its resting place, the layout position until
/// someone drags or shoves it — plus a spring *displacement* from that
/// anchor and, when ambient motion is on, a slow deterministic float. The
/// springs carry the entrance (nodes spring in from a seeded scatter), the
/// tug on a dragged node's neighbors, and the glide of nodes shoved aside.
///
/// Work per [step] is O(nodes + dragged node's neighbors) with no
/// allocation beyond the returned flag, so it runs every frame at the
/// bounded 40-node view. A scene built with `animated: false` (reduced
/// motion) never needs [step]: drags and shoves move anchors directly and
/// no node ever floats.
final class ConstellationScene {
  ConstellationScene({
    required this.graph,
    required GraphLayout layout,
    required this.worldSize,
    required this.animated,
    this.ambient = true,
    Map<String, Offset>? entranceFrom,
  }) : _bounds = Rect.fromLTRB(
         GraphLayout.inset,
         GraphLayout.inset,
         math.max(GraphLayout.inset, worldSize.width - GraphLayout.inset),
         math.max(GraphLayout.inset, worldSize.height - GraphLayout.inset),
       ) {
    final nodes = graph.nodes;
    final count = nodes.length;
    _anchors = List.filled(count, Offset.zero);
    _displacement = List.filled(count, Offset.zero);
    _velocity = List.filled(count, Offset.zero);
    _floatWeight = List.filled(count, 1.0);
    _radii = List.filled(count, 0.0);
    _stiffness = List.filled(count, 0.0);
    _floats = List.filled(count, const _Float(0, 0, 0, 0, 0, 0));
    _neighbors = List.generate(count, (_) => <int, double>{});
    for (var i = 0; i < count; i++) {
      final identity = nodes[i].identity;
      _index[identity] = i;
      _anchors[i] = layout.positionOf(identity);
      _radii[i] = GraphLayout.nodeRadius(
        nodes[i].prevalence,
        graph.maxPrevalence,
      );
      final from = animated && entranceFrom != null
          ? entranceFrom[identity]
          : null;
      if (from != null) _displacement[i] = from - _anchors[i];
      // Varied spring rates make the entrance and every snap-back arrive
      // out of step, which reads as organic rather than mechanical.
      _stiffness[i] = lerpDouble(34, 74, _unit(identity, 1))!;
      // Heavier (larger) ingredients drift less.
      final size = graph.maxPrevalence <= 1
          ? 0.5
          : nodes[i].prevalence / graph.maxPrevalence;
      final amplitude = lerpDouble(11, 5, size)!;
      _floats[i] = _Float(
        math.pi * 2 / lerpDouble(6, 13, _unit(identity, 2))!,
        math.pi * 2 / lerpDouble(7, 15, _unit(identity, 3))!,
        _unit(identity, 4) * math.pi * 2,
        _unit(identity, 5) * math.pi * 2,
        amplitude * lerpDouble(0.7, 1.2, _unit(identity, 6))!,
        amplitude * lerpDouble(0.7, 1.2, _unit(identity, 7))!,
      );
    }
    final maxWeight = graph.edges.fold(1, (w, e) => math.max(w, e.weight));
    for (final edge in graph.edges) {
      final a = _index[edge.aIdentity]!;
      final b = _index[edge.bIdentity]!;
      final share = maxWeight <= 1 ? 1.0 : (edge.weight - 1) / (maxWeight - 1);
      _neighbors[a][b] = share;
      _neighbors[b][a] = share;
    }
  }

  final IngredientGraph graph;
  final Size worldSize;

  /// False under reduced motion: no entrance, float, tug, or glide.
  final bool animated;

  /// Whether nodes float while idle. Only meaningful when [animated].
  final bool ambient;

  /// How far a neighbor follows the dragged node, from the weakest to the
  /// strongest connection, and the most it can be pulled.
  static const _tugMin = 0.1;
  static const _tugMax = 0.38;
  static const _tugReach = 80.0;

  /// Damping ratio shared by every spring: under 1, so nodes overshoot
  /// slightly and wobble into place.
  static const _dampingRatio = 0.52;

  /// Seconds for a released node's float to fade fully back in.
  static const _floatReturn = 1.4;

  /// The integration step: long frames are subdivided so the springs stay
  /// stable, and a stalled frame never advances more than [_maxFrame].
  static const _substep = 1 / 120;
  static const _maxFrame = 0.1;

  final Rect _bounds;
  final _index = <String, int>{};
  late final List<Offset> _anchors;
  late final List<Offset> _displacement;
  late final List<Offset> _velocity;
  late final List<double> _floatWeight;
  late final List<double> _radii;
  late final List<double> _stiffness;
  late final List<_Float> _floats;
  late final List<Map<int, double>> _neighbors;

  double _time = 0;
  int? _dragged;
  Offset _grabOffset = Offset.zero;
  Offset _grabAnchor = Offset.zero;

  /// The identity currently held by a pointer, if any.
  String? get draggedIdentity =>
      _dragged == null ? null : graph.nodes[_dragged!].identity;

  /// Where [identity] is drawn now, in world coordinates.
  Offset positionOf(String identity) => _positionAt(_index[identity]!);

  Offset _positionAt(int i) {
    final position = _anchors[i] + _displacement[i];
    if (!animated || !ambient || _floatWeight[i] == 0) return position;
    return position + _floatOffset(i) * _floatWeight[i];
  }

  Offset _floatOffset(int i) {
    final f = _floats[i];
    // Two detuned sines per axis: a slow wander that never visibly repeats.
    return Offset(
      math.sin(_time * f.speedX + f.phaseX) * f.reachX +
          math.sin(_time * f.speedX * 2.31 + f.phaseY) * f.reachX * 0.3,
      math.cos(_time * f.speedY + f.phaseY) * f.reachY +
          math.sin(_time * f.speedY * 1.73 + f.phaseX) * f.reachY * 0.3,
    );
  }

  /// The node whose disc or padded hit circle contains [world], nearest
  /// first; [minHitRadius] is in world units.
  String? nodeAt(Offset world, {required double minHitRadius}) {
    int? best;
    var bestDistance = double.infinity;
    for (var i = 0; i < _anchors.length; i++) {
      final distance = (world - _positionAt(i)).distance;
      if (distance <= math.max(_radii[i], minHitRadius) &&
          distance < bestDistance) {
        best = i;
        bestDistance = distance;
      }
    }
    return best == null ? null : graph.nodes[best].identity;
  }

  /// Picks up [identity] at the world point [world]. The node freezes where
  /// it is drawn — its float is baked into the anchor — so nothing jumps.
  void grab(String identity, Offset world) {
    final i = _index[identity]!;
    final drawn = _positionAt(i);
    _anchors[i] = drawn;
    _displacement[i] = Offset.zero;
    _velocity[i] = Offset.zero;
    _floatWeight[i] = 0;
    _dragged = i;
    _grabOffset = world - drawn;
    _grabAnchor = drawn;
  }

  /// Moves the held node under the pointer at [world], shoving any disc it
  /// would overlap out of the way. Shoved nodes glide when [animated] and
  /// jump when not.
  void dragTo(Offset world) {
    final i = _dragged;
    if (i == null) return;
    _anchors[i] = _clamp(world - _grabOffset);
    for (var j = 0; j < _anchors.length; j++) {
      if (j == i) continue;
      final needed = _radii[i] + _radii[j] + GraphLayout.clearanceGap;
      final delta = _anchors[j] - _anchors[i];
      final distance = delta.distance;
      if (distance >= needed) continue;
      final direction = distance < 0.001
          ? Offset(math.cos(j * 1.3), math.sin(j * 1.3))
          : delta / distance;
      // Straight away first; when a wall clamps that short, try the sides
      // and then back past the held node.
      var moved = _clamp(_anchors[i] + direction * needed);
      for (final turn in const [math.pi / 2, -math.pi / 2, math.pi]) {
        if ((moved - _anchors[i]).distance >= needed - 0.5) break;
        final turned = Offset(
          direction.dx * math.cos(turn) - direction.dy * math.sin(turn),
          direction.dx * math.sin(turn) + direction.dy * math.cos(turn),
        );
        moved = _clamp(_anchors[i] + turned * needed);
      }
      if (animated) _displacement[j] += _anchors[j] - moved;
      _anchors[j] = moved;
    }
  }

  /// Lets go of the held node; it stays where it was dropped and its
  /// neighbors spring back to their own anchors.
  void release() => _dragged = null;

  /// Advances the springs and the float clock by [seconds]. Returns whether
  /// anything is still settling — false once every node rests exactly on
  /// its anchor (ambient float aside) and nothing is held.
  bool step(double seconds) {
    if (!animated) return false;
    var remaining = math.min(seconds, _maxFrame);
    _time += remaining;
    while (remaining > 0) {
      final h = math.min(remaining, _substep);
      _integrate(h);
      remaining -= h;
    }
    var settling = _dragged != null;
    for (var i = 0; i < _anchors.length; i++) {
      final target = _tugTarget(i);
      final restingFloat = _dragged == i || _floatWeight[i] == 1;
      if ((_displacement[i] - target).distance < 0.1 &&
          _velocity[i].distance < 1 &&
          restingFloat) {
        if (target == Offset.zero) {
          _displacement[i] = Offset.zero;
          _velocity[i] = Offset.zero;
        }
      } else {
        settling = true;
      }
    }
    return settling;
  }

  void _integrate(double h) {
    for (var i = 0; i < _anchors.length; i++) {
      final k = _stiffness[i];
      final damping = 2 * _dampingRatio * math.sqrt(k);
      final target = _tugTarget(i);
      final acceleration =
          (target - _displacement[i]) * k - _velocity[i] * damping;
      _velocity[i] += acceleration * h;
      _displacement[i] += _velocity[i] * h;
      if (_dragged != i && _floatWeight[i] < 1) {
        _floatWeight[i] = math.min(1, _floatWeight[i] + h / _floatReturn);
      }
    }
  }

  /// A neighbor of the held node is pulled along by a share of how far the
  /// held node has travelled since it was grabbed.
  Offset _tugTarget(int i) {
    final held = _dragged;
    if (held == null || held == i) return Offset.zero;
    final share = _neighbors[held][i];
    if (share == null) return Offset.zero;
    final pull =
        (_anchors[held] - _grabAnchor) * lerpDouble(_tugMin, _tugMax, share)!;
    final length = pull.distance;
    return length <= _tugReach ? pull : pull / length * _tugReach;
  }

  Offset _clamp(Offset point) => Offset(
    point.dx.clamp(_bounds.left, _bounds.right),
    point.dy.clamp(_bounds.top, _bounds.bottom),
  );

  /// A stable 0–1 value per identity and salt (FNV-1a), so every node's
  /// float and spring rate are the same on every launch.
  static double _unit(String identity, int salt) {
    var hash = 0x811c9dc5 ^ salt;
    for (final unit in identity.codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0xffffffff;
    }
    return hash / 0xffffffff;
  }
}

final class _Float {
  const _Float(
    this.speedX,
    this.speedY,
    this.phaseX,
    this.phaseY,
    this.reachX,
    this.reachY,
  );

  final double speedX;
  final double speedY;
  final double phaseX;
  final double phaseY;
  final double reachX;
  final double reachY;
}
