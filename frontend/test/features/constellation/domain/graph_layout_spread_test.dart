import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zest/features/constellation/domain/graph_layout.dart';
import 'package:zest/features/constellation/domain/ingredient_graph.dart';
import 'package:zest/features/discovery/domain/recipe.dart';

import '../../../support/catalog_fixtures.dart';

/// A synthetic collection shaped like a real cocktail catalog: ~620 invented
/// recipes of 3–6 ingredients drawn from a skewed pantry, so the top 40
/// identities co-occur almost pairwise — the dense case that collapsed the
/// original layout into a central clump. No provider content.
IngredientGraph denseBarGraph() {
  final pantry = [for (var i = 0; i < 48; i++) 'pantry item $i'];
  final random = math.Random(7);
  final recipes = <Recipe>[];
  for (var i = 0; i < 620; i++) {
    final count = 3 + random.nextInt(4);
    final names = <String>{};
    while (names.length < count) {
      final skew = random.nextDouble() * random.nextDouble();
      names.add(pantry[(skew * pantry.length).floor()]);
    }
    recipes.add(
      Recipe.fromJson(
        catalogRecipe(
          id: '${700000 + i}',
          name: 'Dense Specimen $i',
          ingredients: [for (final name in names) (name, '1 oz')],
        ),
      ),
    );
  }
  return IngredientGraph.build(recipes);
}

void main() {
  final graph = denseBarGraph();

  test('the dense specimen is the bounded, heavily connected case', () {
    expect(graph.nodes, hasLength(IngredientGraph.defaultMaxNodes));
    // More than half of all possible pairs are connected.
    final pairs = graph.nodes.length * (graph.nodes.length - 1) / 2;
    expect(graph.edges.length, greaterThan(pairs / 2));
  });

  // The world sizes the home canvas lays out in: the viewport enlarged by
  // ConstellationCanvas.worldScale on a desktop page and on a phone.
  for (final size in const [Size(1026, 750), Size(502, 558)]) {
    group('on a ${size.width.toInt()}×${size.height.toInt()} canvas', () {
      final layout = GraphLayout.compute(graph, size: size);
      final inner = Size(
        size.width - GraphLayout.inset * 2,
        size.height - GraphLayout.inset * 2,
      );

      test('a dense collection spreads across the canvas instead of '
          'collapsing to the center', () {
        final xs = layout.positions.values.map((p) => p.dx);
        final ys = layout.positions.values.map((p) => p.dy);
        final spanX = xs.reduce(math.max) - xs.reduce(math.min);
        final spanY = ys.reduce(math.max) - ys.reduce(math.min);
        expect(spanX, greaterThanOrEqualTo(inner.width * 0.7));
        expect(spanY, greaterThanOrEqualTo(inner.height * 0.7));
      });

      test('nodes are not pinned in rows along the canvas walls', () {
        final bounds = Rect.fromLTWH(
          GraphLayout.inset,
          GraphLayout.inset,
          inner.width,
          inner.height,
        );
        final onWall = layout.positions.values.where(
          (p) =>
              (p.dx - bounds.left).abs() < 1 ||
              (p.dx - bounds.right).abs() < 1 ||
              (p.dy - bounds.top).abs() < 1 ||
              (p.dy - bounds.bottom).abs() < 1,
        );
        // Filling the canvas puts the extreme nodes on the walls; anything
        // beyond a handful means the outer ring is pressed flat.
        expect(onWall.length, lessThanOrEqualTo(8));
      });

      test('node discs never overlap', () {
        final nodes = graph.nodes;
        for (var i = 0; i < nodes.length; i++) {
          for (var j = i + 1; j < nodes.length; j++) {
            final a = nodes[i];
            final b = nodes[j];
            final distance =
                (layout.positionOf(a.identity) - layout.positionOf(b.identity))
                    .distance;
            final clearance =
                GraphLayout.nodeRadius(a.prevalence, graph.maxPrevalence) +
                GraphLayout.nodeRadius(b.prevalence, graph.maxPrevalence);
            expect(
              distance,
              greaterThanOrEqualTo(clearance),
              reason: '${a.identity} and ${b.identity} overlap',
            );
          }
        }
      });
    });
  }
}
