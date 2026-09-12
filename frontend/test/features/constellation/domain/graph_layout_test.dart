import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zest/features/constellation/domain/graph_layout.dart';
import 'package:zest/features/constellation/domain/ingredient_graph.dart';
import 'package:zest/features/discovery/domain/recipe.dart';

import '../../../support/catalog_fixtures.dart';

/// Synthetic recipes shaped like provider records — no provider content.
Recipe _recipe({
  required String id,
  required String name,
  required List<String> ingredients,
}) => Recipe.fromJson(
  catalogRecipe(
    id: id,
    name: name,
    ingredients: [
      for (final ingredient in ingredients) (ingredient, '1 oz'),
    ],
  ),
);

/// A synthetic 40-identity collection in the fixture style — the bounded
/// view's default size. No provider content.
IngredientGraph _graphWithNodes(int count) {
  final recipes = <Recipe>[];
  for (var i = 0; i < count; i++) {
    recipes.add(
      _recipe(
        id: '${9000 + i}',
        name: 'Layout Specimen $i',
        ingredients: [
          'Anchor Spirit',
          'Specimen ${String.fromCharCode(97 + i % 26)}${i ~/ 26}',
          if (i.isEven) 'Shared Mixer',
        ],
      ),
    );
  }
  return IngredientGraph.build(recipes);
}

void main() {
  const size = Size(700, 420);

  test('the same graph, canvas, and seed always produce identical positions',
      () {
    final graph = _graphWithNodes(40);
    final first = GraphLayout.compute(graph, size: size);
    final second = GraphLayout.compute(graph, size: size);

    expect(first.positions.keys, second.positions.keys);
    for (final identity in first.positions.keys) {
      expect(first.positionOf(identity), second.positionOf(identity));
    }
  });

  test('positions stay inside the canvas inset bounds', () {
    final graph = _graphWithNodes(40);
    final layout = GraphLayout.compute(graph, size: size);

    for (final position in layout.positions.values) {
      expect(position.dx, greaterThanOrEqualTo(GraphLayout.inset));
      expect(position.dx, lessThanOrEqualTo(size.width - GraphLayout.inset));
      expect(position.dy, greaterThanOrEqualTo(GraphLayout.inset));
      expect(position.dy, lessThanOrEqualTo(size.height - GraphLayout.inset));
    }
  });

  test('iterations: 0 returns the deterministic initial placement', () {
    final graph = _graphWithNodes(12);
    final first = GraphLayout.compute(graph, size: size, iterations: 0);
    final second = GraphLayout.compute(graph, size: size, iterations: 0);

    expect(first.positions.keys, second.positions.keys);
    for (final identity in first.positions.keys) {
      expect(first.positionOf(identity), second.positionOf(identity));
    }
    // The settled layout differs from the raw placement — the iteration
    // bound is doing real work, not a no-op pass.
    final settled = GraphLayout.compute(graph, size: size);
    var moved = 0;
    for (final identity in first.positions.keys) {
      if (first.positionOf(identity) != settled.positionOf(identity)) moved++;
    }
    expect(moved, greaterThan(0));
  });

  test('a single-node graph settles immediately without simulation', () {
    final graph = IngredientGraph.build([
      _recipe(id: '90001', name: 'Solo', ingredients: ['Only One']),
    ]);
    expect(graph.nodes, hasLength(1));
    final layout = GraphLayout.compute(graph, size: size);
    expect(layout.positions, hasLength(1));
    expect(layout.positions.values.single, isNotNull);
  });

  test('a 40-node layout — the bounded view default — computes directly', () {
    final graph = _graphWithNodes(40);
    expect(graph.nodes, hasLength(40));
    // No isolates, no wall-clock input: the call returns synchronously with
    // positions for every node.
    final layout = GraphLayout.compute(graph, size: size);
    expect(layout.positions, hasLength(40));
    expect(
      layout.positions.keys.toSet(),
      graph.nodes.map((node) => node.identity).toSet(),
    );
  });

  test('edge-connected graphs compute on the full default view', () {
    // Recipes across many letters share the fixture identities, so the
    // graph carries both nodes and edges.
    final graph = IngredientGraph.build([
      for (final letter in 'abcdefg'.split(''))
        catalogLetterRecipes(letter).single,
    ]);
    expect(graph.nodes, isNotEmpty);
    expect(graph.edges, isNotEmpty);

    final layout = GraphLayout.compute(graph, size: size);
    for (final identity in graph.nodes.map((node) => node.identity)) {
      expect(layout.positions.containsKey(identity), isTrue);
    }
  });
}
