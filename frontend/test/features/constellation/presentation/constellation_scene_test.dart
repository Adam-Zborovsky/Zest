import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zest/features/constellation/domain/graph_layout.dart';
import 'package:zest/features/constellation/domain/ingredient_graph.dart';
import 'package:zest/features/constellation/presentation/constellation_scene.dart';

import '../../../support/catalog_fixtures.dart';

const _world = Size(700, 560);

IngredientGraph _graph() => IngredientGraph.build([
  ...catalogLetterRecipes('a'),
  ...catalogLetterRecipes('b'),
  ...catalogLetterRecipes('c'),
]);

ConstellationScene _scene(
  IngredientGraph graph,
  GraphLayout layout, {
  bool animated = true,
  bool ambient = false,
  Map<String, Offset>? entranceFrom,
}) => ConstellationScene(
  graph: graph,
  layout: layout,
  worldSize: _world,
  animated: animated,
  ambient: ambient,
  entranceFrom: entranceFrom,
);

/// Steps at 60 fps until the scene reports rest, failing past [limit].
void _settle(ConstellationScene scene, {double limit = 10}) {
  var elapsed = 0.0;
  while (scene.step(1 / 60)) {
    elapsed += 1 / 60;
    if (elapsed > limit) fail('The scene never came to rest.');
  }
}

void main() {
  final graph = _graph();
  final layout = GraphLayout.compute(graph, size: _world);
  final mint = 'mint leaf';
  final neighbor = graph.neighborhood(mint)!.connections.first.node.identity;

  test('the entrance springs every node from the scatter onto its exact '
      'layout position, then rests', () {
    final scene = _scene(
      graph,
      layout,
      entranceFrom: {
        for (final node in graph.nodes)
          node.identity: _world.center(Offset.zero),
      },
    );
    expect(scene.positionOf(mint), isNot(layout.positionOf(mint)));

    _settle(scene);

    for (final node in graph.nodes) {
      expect(
        scene.positionOf(node.identity),
        layout.positionOf(node.identity),
      );
    }
    expect(scene.step(1 / 60), isFalse);
  });

  test('a dragged node follows the pointer, tugs its neighbors, and stays '
      'where it is dropped while they spring home', () {
    final scene = _scene(graph, layout);
    final start = layout.positionOf(mint);
    // Toward the middle of the world, so no wall clamps the move.
    final center = _world.center(Offset.zero);
    final travel = Offset(
      start.dx < center.dx ? 60 : -60,
      start.dy < center.dy ? 40 : -40,
    );

    scene.grab(mint, start);
    scene.dragTo(start + travel);
    for (var i = 0; i < 30; i++) {
      expect(scene.step(1 / 60), isTrue, reason: 'holding keeps it live');
    }

    expect(scene.positionOf(mint), start + travel);
    final pulled =
        scene.positionOf(neighbor) - layout.positionOf(neighbor);
    expect(pulled.distance, greaterThan(1));
    // Pulled the same way the held node went.
    expect(pulled.dx * travel.dx + pulled.dy * travel.dy, greaterThan(0));

    scene.release();
    _settle(scene);

    expect(scene.positionOf(mint), start + travel);
    expect(scene.positionOf(neighbor), layout.positionOf(neighbor));
  });

  test('dragging onto another disc shoves it clear instead of overlapping',
      () {
    final scene = _scene(graph, layout);
    final target = layout.positionOf(neighbor);
    scene.grab(mint, layout.positionOf(mint));
    scene.dragTo(target);
    scene.release();
    _settle(scene);

    final nodes = {for (final node in graph.nodes) node.identity: node};
    final needed =
        GraphLayout.nodeRadius(nodes[mint]!.prevalence, graph.maxPrevalence) +
        GraphLayout.nodeRadius(
          nodes[neighbor]!.prevalence,
          graph.maxPrevalence,
        );
    expect(
      (scene.positionOf(mint) - scene.positionOf(neighbor)).distance,
      greaterThanOrEqualTo(needed),
    );
  });

  test('without animation (reduced motion) nothing ticks and drags and '
      'shoves apply immediately', () {
    final scene = _scene(
      graph,
      layout,
      animated: false,
      ambient: true,
      entranceFrom: {for (final node in graph.nodes) node.identity: Offset.zero},
    );
    for (final node in graph.nodes) {
      expect(scene.positionOf(node.identity), layout.positionOf(node.identity));
    }

    scene.grab(mint, layout.positionOf(mint));
    scene.dragTo(layout.positionOf(neighbor));
    expect(scene.step(1 / 60), isFalse);
    expect(scene.positionOf(mint), layout.positionOf(neighbor));
    expect(
      scene.positionOf(neighbor),
      isNot(layout.positionOf(neighbor)),
    );
  });

  test('the ambient float is gentle, never rests, and is the same on every '
      'run', () {
    final first = _scene(graph, layout, ambient: true);
    final second = _scene(graph, layout, ambient: true);
    for (var i = 0; i < 90; i++) {
      expect(first.step(1 / 60), isFalse);
      second.step(1 / 60);
    }
    var drifted = false;
    for (final node in graph.nodes) {
      final drift =
          first.positionOf(node.identity) - layout.positionOf(node.identity);
      expect(drift.distance, lessThan(20));
      if (drift.distance > 0.5) drifted = true;
      expect(first.positionOf(node.identity), second.positionOf(node.identity));
    }
    expect(drifted, isTrue);
  });

  test('hit testing finds the nearest node within the padded radius', () {
    final scene = _scene(graph, layout);
    final position = layout.positionOf(mint);
    expect(scene.nodeAt(position, minHitRadius: 24), mint);
    expect(
      scene.nodeAt(const Offset(-500, -500), minHitRadius: 24),
      isNull,
    );
  });
}
