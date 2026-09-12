import 'package:flutter_test/flutter_test.dart';
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

void main() {
  test('builds nodes with distinct-recipe prevalence from the collection', () {
    final graph = IngredientGraph.build([
      _recipe(
        id: '90001',
        name: 'Garden Gimlet',
        ingredients: ['Gin', 'Lime Juice'],
      ),
      _recipe(
        id: '90002',
        name: 'Garden Sour',
        ingredients: ['Gin', 'Lime Juice', 'Sugar'],
      ),
      _recipe(
        id: '90003',
        name: 'Garden Bitter',
        ingredients: ['Gin'],
      ),
    ]);

    expect(graph.recipeCount, 3);
    expect(graph.totalIdentityCount, 3);
    expect(graph.nodes.first.identity, 'gin');
    expect(graph.nodes.first.prevalence, 3);
    expect(
      graph.nodes.map((node) => node.identity),
      containsAll(['lime juice', 'sugar']),
    );
    final lime = graph.node('lime juice')!;
    expect(lime.prevalence, 2);
  });

  test('identical names after normalization merge into one identity', () {
    final graph = IngredientGraph.build([
      _recipe(
        id: '90011',
        name: 'Mojito One',
        ingredients: ['Mint Leaves', 'White Rum'],
      ),
      _recipe(
        id: '90012',
        name: 'Mojito Two',
        ingredients: ['mint leaves', '  white   rum '],
      ),
      _recipe(
        id: '90013',
        name: 'Mojito Three',
        ingredients: ['Mint LEAVES', 'Dark Rums'],
      ),
    ]);

    // "Mint Leaves"/"mint leaves" merge via the alias table; "white rum"
    // spellings merge lexically; "Dark Rums" is its own alias target.
    expect(graph.nodes.map((node) => node.identity), containsAll([
      'mint leaf',
      'white rum',
      'dark rum',
    ]));
    expect(graph.node('mint leaf')!.prevalence, 3);
    expect(graph.node('white rum')!.prevalence, 2);
    expect(graph.nodes, hasLength(3));
  });

  test('a recipe contributing the same identity twice counts it once', () {
    final graph = IngredientGraph.build([
      _recipe(
        id: '90021',
        name: 'Double Lemon',
        ingredients: ['Lemon Juice', 'lemon juice', 'Gin'],
      ),
      _recipe(
        id: '90022',
        name: 'Single Lemon',
        ingredients: ['Lemon Juice'],
      ),
    ]);

    expect(graph.node('lemon juice')!.prevalence, 2);

    final gin = graph.node('gin')!;
    final edge = graph.edge('gin', 'lemon juice');
    expect(edge, isNotNull);
    // The pair co-occurs in one recipe even though the recipe lists the
    // identity twice.
    expect(edge!.weight, 1);
    expect(edge.sharedRecipeIds, ['90021']);
    expect(graph.neighborhood(gin.identity)!.connections, hasLength(1));
  });

  test('edge weight is the shared recipe count across the collection', () {
    final graph = IngredientGraph.build([
      _recipe(
        id: '90031',
        name: 'Daiquiri',
        ingredients: ['White Rum', 'Lime Juice'],
      ),
      _recipe(
        id: '90032',
        name: 'Cuba Libre',
        ingredients: ['White Rum', 'Cola'],
      ),
      _recipe(
        id: '90033',
        name: 'Rum Sour',
        ingredients: ['White Rum', 'Lime Juice', 'Sugar'],
      ),
    ]);

    final edge = graph.edge('white rum', 'lime juice')!;
    expect(edge.weight, 2);
    expect(edge.sharedRecipeIds, unorderedEquals(['90031', '90033']));
    expect(graph.edge('white rum', 'cola')!.weight, 1);
    expect(graph.edge('lime juice', 'cola'), isNull);
  });

  test('bounding keeps the top nodes by prevalence, ties alphabetical', () {
    // Prevalences: top1 = 3; tiea, tieb, lowc = 2; lowd = 1.
    final recipes = [
      _recipe(id: '90041', name: 'One', ingredients: ['Top1', 'TieB', 'TieA']),
      _recipe(id: '90042', name: 'Two', ingredients: ['Top1', 'TieB', 'TieA']),
      _recipe(id: '90043', name: 'Three', ingredients: ['Top1', 'LowC']),
      _recipe(id: '90044', name: 'Four', ingredients: ['LowC', 'LowD']),
    ];
    final graph = IngredientGraph.build(recipes, maxNodes: 3);

    // top1 (3) first, then the three-way prevalence tie broken
    // alphabetically: lowc, tiea — tieb and lowd drop.
    expect(
      graph.nodes.map((node) => node.identity).toList(),
      ['top1', 'lowc', 'tiea'],
    );
    expect(graph.node('tieb'), isNull);
    // The pre-bound identity count is exposed so presenters can disclose
    // the bound: 5 distinct identities were analyzed, 3 are kept.
    expect(graph.totalIdentityCount, 5);
    expect(graph.nodes, hasLength(3));
    // Only edges among kept nodes exist: top1–lowc and top1–tiea survive;
    // anything touching tieb/lowd is gone.
    expect(
      graph.edges.map((edge) => (edge.aIdentity, edge.bIdentity, edge.weight)),
      unorderedEquals([
        ('lowc', 'top1', 1),
        ('tiea', 'top1', 2),
      ]),
    );
  });

  test('neighborhood lists adjacent nodes and edges, strongest first', () {
    final graph = IngredientGraph.build([
      _recipe(
        id: '90051',
        name: 'A',
        ingredients: ['Center', 'Strong', 'Weak'],
      ),
      _recipe(
        id: '90052',
        name: 'B',
        ingredients: ['Center', 'Strong'],
      ),
      _recipe(id: '90053', name: 'C', ingredients: ['Center', 'Weak']),
      _recipe(id: '90054', name: 'D', ingredients: ['Center', 'Strong']),
    ]);

    final neighborhood = graph.neighborhood('center')!;
    expect(neighborhood.center.prevalence, 4);
    expect(
      neighborhood.connections.map((c) => c.node.identity).toList(),
      // strong (weight 3) before weak (weight 2); the alphabetical tie-break
      // applies within equal weights.
      ['strong', 'weak'],
    );
    expect(
      neighborhood.connections.map((c) => c.weight).toList(),
      [3, 2],
    );
    expect(graph.neighborhood('nope'), isNull);
  });

  test('sharedRecipes returns the recipes behind an edge, name-sorted', () {
    final graph = IngredientGraph.build([
      _recipe(
        id: '90061',
        name: 'Zebra Fizz',
        ingredients: ['Rye', 'Soda'],
      ),
      _recipe(
        id: '90062',
        name: 'Alpha Fizz',
        ingredients: ['Rye', 'Soda'],
      ),
    ]);

    final edge = graph.edge('rye', 'soda')!;
    final shared = graph.sharedRecipes(edge);
    expect(shared.map((recipe) => recipe.name).toList(), [
      'Alpha Fizz',
      'Zebra Fizz',
    ]);
    expect(shared.every((recipe) => recipe.ingredients.isNotEmpty), isTrue);
  });

  test('an empty collection yields an empty graph that still states zero', () {
    final graph = IngredientGraph.build(const []);
    expect(graph.isEmpty, isTrue);
    expect(graph.nodes, isEmpty);
    expect(graph.edges, isEmpty);
    expect(graph.recipeCount, 0);
    expect(graph.totalIdentityCount, 0);
    expect(graph.node('gin'), isNull);
  });

  test('a collection wider than the default bound keeps the pre-bound '
      'identity count', () {
    // 41 distinct identities, all prevalence 1 plus one shared identity:
    // the default bound keeps 40 nodes out of 42 analyzed identities.
    final recipes = [
      for (var i = 1; i <= 41; i++)
        _recipe(
          id: '9000$i'.padLeft(6, '0'),
          name: 'Wide Garden $i',
          ingredients: ['Wide Ingredient $i', 'Shared Tonic'],
        ),
    ];
    final graph = IngredientGraph.build(recipes);

    expect(graph.totalIdentityCount, 42);
    expect(graph.nodes, hasLength(IngredientGraph.defaultMaxNodes));
    expect(graph.nodes.length, lessThan(graph.totalIdentityCount));
    expect(graph.node('shared tonic'), isNotNull);
    // The alphabetically-last wide ingredients fall past the bound.
    expect(graph.node('wide ingredient 9'), isNull);
  });

  test('a single recipe produces its identities and all pair edges', () {
    final graph = IngredientGraph.build([
      _recipe(
        id: '90071',
        name: 'Trio',
        ingredients: ['Gin', 'Tonic', 'Lime'],
      ),
    ]);

    expect(graph.recipeCount, 1);
    expect(graph.nodes, hasLength(3));
    expect(graph.edges, hasLength(3));
    expect(graph.edge('gin', 'tonic')!.weight, 1);
  });

  test('recipes without ingredients contribute to the count only', () {
    final graph = IngredientGraph.build([
      _recipe(id: '90081', name: 'Empty Record', ingredients: []),
      _recipe(id: '90082', name: 'Lone', ingredients: ['Gin']),
    ]);

    expect(graph.recipeCount, 2);
    expect(graph.nodes.single.identity, 'gin');
    expect(graph.node('gin')!.prevalence, 1);
    expect(graph.edges, isEmpty);
  });

  test('the same input always produces the same bounded graph', () {
    List<Recipe> recipes() => [
      _recipe(id: '90091', name: 'One', ingredients: ['Gin', 'Tonic']),
      _recipe(id: '90092', name: 'Two', ingredients: ['Gin', 'Tonic']),
      _recipe(id: '90093', name: 'Three', ingredients: ['Gin', 'Bitters']),
      _recipe(id: '90094', name: 'Four', ingredients: ['Tonic']),
    ];

    final first = IngredientGraph.build(recipes());
    final second = IngredientGraph.build(recipes());
    expect(
      first.nodes.map((node) => (node.identity, node.prevalence)),
      second.nodes.map((node) => (node.identity, node.prevalence)),
    );
    expect(
      first.edges.map(
        (edge) => (edge.aIdentity, edge.bIdentity, edge.weight),
      ),
      second.edges.map(
        (edge) => (edge.aIdentity, edge.bIdentity, edge.weight),
      ),
    );
  });
}
