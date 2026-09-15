import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zest/features/constellation/domain/graph_layout.dart';
import 'package:zest/features/constellation/domain/ingredient_graph.dart';
import 'package:zest/features/constellation/presentation/constellation_canvas.dart';
import 'package:zest/features/constellation/presentation/constellation_painter.dart';
import 'package:zest/features/constellation/presentation/constellation_scene.dart';

import '../../../support/catalog_fixtures.dart';

void main() {
  const world = Size(700, 560);
  final graph = IngredientGraph.build([
    ...catalogLetterRecipes('a'),
    ...catalogLetterRecipes('b'),
    ...catalogLetterRecipes('c'),
  ]);
  final scene = ConstellationScene(
    graph: graph,
    layout: GraphLayout.compute(graph, size: world),
    worldSize: world,
    animated: false,
  );

  ConstellationPaintData data({String? selected, String query = ''}) {
    final paintData = ConstellationPaintData(
      graph: graph,
      selectedNode: selected == null ? null : graph.node(selected),
      selectedEdge: null,
      query: query,
      labelStyle: const TextStyle(fontSize: 11),
    );
    addTearDown(paintData.dispose);
    return paintData;
  }

  List<String> named(ConstellationPaintData paintData, double scale) => [
    for (final visible in paintData.visibleLabels(scene, scale))
      visible.label.identity,
  ];

  testWidgets('with nothing selected, no name shows at the opening zoom', (
    tester,
  ) async {
    expect(named(data(), 0.74), isEmpty);
  });

  testWidgets('zooming in reveals names, the most-used ingredient first', (
    tester,
  ) async {
    final paintData = data();
    double radius(String identity) {
      final node = graph.node(identity)!;
      return GraphLayout.nodeRadius(node.prevalence, graph.maxPrevalence);
    }

    // Just past the point where the largest disc starts revealing: only
    // discs that large are named, and still fading in.
    final scale = (ConstellationPaintData.revealStart + 2) /
        radius(graph.nodes.first.identity);
    final partway = paintData.visibleLabels(scene, scale);
    expect(partway, isNotEmpty);
    for (final visible in partway) {
      expect(
        radius(visible.label.identity) * scale,
        greaterThan(ConstellationPaintData.revealStart),
      );
      expect(visible.opacity, inExclusiveRange(0, 1));
    }

    final zoomedIn = paintData.visibleLabels(scene, ConstellationCanvas.maxZoom);
    expect(
      zoomedIn.map((visible) => visible.label.identity).toSet(),
      graph.nodes.map((node) => node.identity).toSet(),
    );
    expect(zoomedIn.every((visible) => visible.opacity == 1), isTrue);
  });

  testWidgets('a selection names its neighborhood at every zoom, and '
      'clearing it hides the names again', (tester) async {
    final neighborhood = graph.neighborhood('mint leaf')!;
    expect(
      named(data(selected: 'mint leaf'), 0.74).toSet(),
      {
        'mint leaf',
        for (final connection in neighborhood.connections)
          connection.node.identity,
      },
    );
    expect(named(data(), 0.74), isEmpty);
  });

  testWidgets('search matches are named at every zoom', (tester) async {
    expect(named(data(query: 'mint'), 0.74), ['mint leaf']);
  });
}
