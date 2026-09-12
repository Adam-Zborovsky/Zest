import '../../discovery/domain/recipe.dart';

/// One node of the constellation: a normalized ingredient identity and its
/// prevalence — the number of distinct recipes in the analyzed collection
/// that contain it. This is collection prevalence only; it is never
/// real-world popularity and never a flavor or compatibility claim.
final class IngredientNode {
  const IngredientNode({required this.identity, required this.prevalence});

  /// The identity from `Ingredient.normalizedName`. Two source spellings that
  /// normalize identically are one node, by design.
  final String identity;

  /// Distinct recipes in the analyzed collection containing this identity.
  final int prevalence;
}

/// One co-occurrence connection: the two endpoint identities share recipes
/// in the analyzed collection. [weight] is their shared recipe count.
final class IngredientEdge {
  const IngredientEdge({
    required this.aIdentity,
    required this.bIdentity,
    required this.weight,
    required this.sharedRecipeIds,
  });

  /// Canonical endpoint order: [aIdentity] sorts before [bIdentity], so
  /// identical pairs always compare equal.
  final String aIdentity;
  final String bIdentity;

  /// Number of shared recipes; equals [sharedRecipeIds].length.
  final int weight;

  /// Recipe ids of every shared recipe, sorted ascending.
  final List<String> sharedRecipeIds;

  bool touches(String identity) =>
      identity == aIdentity || identity == bIdentity;

  String otherThan(String identity) =>
      identity == aIdentity ? bIdentity : aIdentity;
}

/// One neighbor of a center node: the adjacent node plus the edge that
/// connects them.
final class IngredientConnection {
  const IngredientConnection({required this.node, required this.edge});

  final IngredientNode node;
  final IngredientEdge edge;

  int get weight => edge.weight;
}

/// The neighborhood answer for one selected node: its connections, strongest
/// (highest weight) first, ties broken alphabetically.
final class IngredientNeighborhood {
  const IngredientNeighborhood({
    required this.center,
    required this.connections,
  });

  final IngredientNode center;
  final List<IngredientConnection> connections;
}

/// The ingredient co-occurrence graph over one analyzed recipe collection.
///
/// Nodes are normalized ingredient identities (via each ingredient's
/// `normalizedName` — never an invented identity); node prevalence is the
/// distinct recipe count within the analyzed collection. Edges connect
/// identities that appear together in at least one recipe; edge weight is
/// their shared recipe count. Counts describe exactly the recipes handed to
/// [IngredientGraph.build] — no provider-catalog completeness is implied.
///
/// The view is bounded: only the top [maxNodes] identities by prevalence are
/// kept (ties break alphabetically, so the same input always yields the same
/// bounded graph), and only edges among kept nodes exist.
final class IngredientGraph {
  IngredientGraph._({
    required this.maxNodes,
    required this.nodes,
    required this.edges,
    required this.recipeCount,
    required Map<String, Recipe> recipesById,
  }) : _recipesById = recipesById,
       _nodesByIdentity = {
         for (final node in nodes) node.identity: node,
       },
       _edgesByKey = {
         for (final edge in edges) (edge.aIdentity, edge.bIdentity): edge,
       };

  /// Default bounded view size (M5 acceptance: top 40 ingredients by
  /// prevalence, fully laid out).
  static const defaultMaxNodes = 40;

  /// The kept nodes, most prevalent first, ties broken alphabetically.
  final List<IngredientNode> nodes;

  /// The kept edges, ordered by (aIdentity, bIdentity) for determinism.
  final List<IngredientEdge> edges;

  /// Every recipe handed to [IngredientGraph.build], including any without
  /// ingredients — the "M" in "appears in N of the M recipes in the analyzed
  /// collection".
  final int recipeCount;

  /// The bounding rule actually applied by this graph.
  final int maxNodes;

  final Map<String, Recipe> _recipesById;
  final Map<String, IngredientNode> _nodesByIdentity;
  final Map<(String, String), IngredientEdge> _edgesByKey;

  /// Builds the bounded graph over the analyzed recipes. A recipe
  /// contributing the same identity twice counts that identity once for
  /// prevalence and once per pair; recipes with no ingredients contribute to
  /// [recipeCount] but produce no nodes or edges.
  factory IngredientGraph.build(
    List<Recipe> recipes, {
    int maxNodes = defaultMaxNodes,
  }) {
    final prevalence = <String, int>{};
    final pairRecipeIds = <(String, String), List<String>>{};
    for (final recipe in recipes) {
      // The same identity twice in one recipe counts once.
      final identities =
          recipe.ingredients.map((ingredient) => ingredient.normalizedName).toSet();
      for (final identity in identities) {
        prevalence[identity] = (prevalence[identity] ?? 0) + 1;
      }
      final ordered = identities.toList()..sort();
      for (var i = 0; i < ordered.length; i++) {
        for (var j = i + 1; j < ordered.length; j++) {
          pairRecipeIds
              .putIfAbsent((ordered[i], ordered[j]), () => [])
              .add(recipe.id);
        }
      }
    }

    // Bounding: top [maxNodes] by prevalence, ties broken alphabetically —
    // a deterministic, documented rule.
    final kept = (prevalence.keys.toList()
          ..sort((a, b) {
            final byPrevalence = prevalence[b]!.compareTo(prevalence[a]!);
            return byPrevalence != 0 ? byPrevalence : a.compareTo(b);
          }))
        .take(maxNodes)
        .toList(growable: false);
    final keptSet = kept.toSet();

    final nodes = [
      for (final identity in kept)
        IngredientNode(identity: identity, prevalence: prevalence[identity]!),
    ];
    final edges =
        ({
          for (final entry in pairRecipeIds.entries)
            if (keptSet.contains(entry.key.$1) && keptSet.contains(entry.key.$2))
              entry.key: IngredientEdge(
                aIdentity: entry.key.$1,
                bIdentity: entry.key.$2,
                weight: entry.value.length,
                sharedRecipeIds: List.unmodifiable(entry.value..sort()),
              ),
        }.values.toList()
          ..sort((a, b) {
            final byA = a.aIdentity.compareTo(b.aIdentity);
            return byA != 0 ? byA : a.bIdentity.compareTo(b.bIdentity);
          }));

    return IngredientGraph._(
      maxNodes: maxNodes,
      nodes: List.unmodifiable(nodes),
      edges: List.unmodifiable(edges),
      recipeCount: recipes.length,
      recipesById: {for (final recipe in recipes) recipe.id: recipe},
    );
  }

  bool get isEmpty => nodes.isEmpty;

  int get nodeCount => nodes.length;

  int get maxPrevalence => nodes.isEmpty ? 0 : nodes.first.prevalence;

  IngredientNode? node(String identity) => _nodesByIdentity[identity];

  /// The edge between two identities, in either argument order.
  IngredientEdge? edge(String a, String b) =>
      a.compareTo(b) <= 0 ? _edgesByKey[(a, b)] : _edgesByKey[(b, a)];

  IngredientNeighborhood? neighborhood(String identity) {
    final center = _nodesByIdentity[identity];
    if (center == null) return null;
    final connections = <IngredientConnection>[];
    for (final edge in edges) {
      if (!edge.touches(identity)) continue;
      final other = _nodesByIdentity[edge.otherThan(identity)];
      if (other != null) connections.add(IngredientConnection(node: other, edge: edge));
    }
    connections.sort((a, b) {
      final byWeight = b.weight.compareTo(a.weight);
      return byWeight != 0 ? byWeight : a.node.identity.compareTo(b.node.identity);
    });
    return IngredientNeighborhood(center: center, connections: connections);
  }

  /// Every shared recipe behind one edge, sorted by name then id for a
  /// stable listing order.
  List<Recipe> sharedRecipes(IngredientEdge edge) {
    final recipes = [
      for (final id in edge.sharedRecipeIds)
        if (_recipesById[id] != null) _recipesById[id]!,
    ];
    return List.unmodifiable(
      recipes..sort((a, b) {
        final byName = a.name.compareTo(b.name);
        return byName != 0 ? byName : a.id.compareTo(b.id);
      }),
    );
  }
}
