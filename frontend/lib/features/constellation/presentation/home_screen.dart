import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/zest_tokens.dart';
import '../../../core/widgets/zest_button.dart';
import '../../../core/widgets/zest_card.dart';
import '../../../core/widgets/zest_chip.dart';
import '../../../core/widgets/zest_states.dart';
import '../../catalog/application/catalog_providers.dart';
import '../../discovery/presentation/discovery_widgets.dart';
import '../application/constellation_providers.dart';
import '../domain/ingredient_graph.dart';
import 'constellation_canvas.dart';
import 'constellation_widgets.dart';

/// Home: the constellation leads. The graph canvas is the playful, spatial
/// exploration; the list view, the sync/coverage card, and the discovery and
/// bar routes carry the same information and the core tasks without the
/// graph. Content follows the 800-pixel page width rule via [DiscoveryFrame].
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  static const _canvasHeight = 420.0;

  bool _listView = false;
  String? _selectedNodeId;
  IngredientEdge? _selectedEdge;
  IngredientGraph? _selectionGraph;
  late final TextEditingController _search;

  @override
  void initState() {
    super.initState();
    _search = TextEditingController()..addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Selections belong to one graph instance; when the sync invalidates the
  /// graph and a new one arrives, the stale selection cannot outlive it.
  /// Runs inside build, before the values are read — no setState needed.
  void _syncSelection(IngredientGraph graph) {
    if (identical(_selectionGraph, graph)) return;
    _selectionGraph = graph;
    _selectedNodeId = null;
    _selectedEdge = null;
  }

  @override
  Widget build(BuildContext context) {
    // Arms the one-place freshness wiring: sync state changes invalidate the
    // stored coverage and the graph (see catalogFreshnessProvider).
    ref.watch(catalogFreshnessProvider);
    final graphAsync = ref.watch(constellationGraphProvider);
    final coverage = ref.watch(catalogCoverageProvider).value;
    final coverageLabel = coverage == null
        ? 'Counts describe the recipes loaded on this device — not the full '
              'provider catalog.'
        : '${coverageLine(coverage)} Counts describe the loaded collection — '
              'not the full provider catalog.';

    return DiscoveryFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Home', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: ZestSpace.sm),
          const DiscoveryHeading('The Ingredient Constellation', large: true),
          const SizedBox(height: ZestSpace.md),
          const Text(
            'Every ingredient in the loaded collection gets a place. '
            'Ingredients that appear together in recipes pull close — '
            'follow the lines from one bottle to the next.',
          ),
          const SizedBox(height: ZestSpace.section),
          Wrap(
            spacing: ZestSpace.sm,
            runSpacing: ZestSpace.sm,
            children: [
              ZestChip(
                key: const ValueKey('home-view-graph'),
                label: 'Graph',
                selected: !_listView,
                onSelected: (_) => setState(() => _listView = false),
              ),
              ZestChip(
                key: const ValueKey('home-view-list'),
                label: 'List',
                selected: _listView,
                onSelected: (_) => setState(() => _listView = true),
              ),
            ],
          ),
          const SizedBox(height: ZestSpace.xs),
          const Text(
            'The graph is decorative — the list view carries the same '
            'information.',
            style: TextStyle(color: ZestPalette.secondaryInk),
          ),
          const SizedBox(height: ZestSpace.section),
          graphAsync.when(
            skipLoadingOnRefresh: false,
            data: (graph) {
              _syncSelection(graph);
              return _listView
                  ? _listContentView(context, graph, coverageLabel)
                  : _graphView(context, graph, coverageLabel);
            },
            loading: () =>
                const ZestLoadingState(label: 'Laying out the constellation…'),
            error: (error, stack) => ZestErrorState(
              title: 'The constellation could not load',
              message:
                  'The loaded recipes could not be read from this device. '
                  'Try again.',
              onRetry: () => ref.invalidate(constellationGraphProvider),
            ),
          ),
          const SizedBox(height: ZestSpace.section),
          const CatalogSyncCard(key: ValueKey('home-sync-card')),
          const SizedBox(height: ZestSpace.section),
          Wrap(
            spacing: ZestSpace.md,
            runSpacing: ZestSpace.sm,
            children: [
              ZestButton(
                key: const ValueKey('home-discover'),
                label: 'Find recipes',
                icon: Icons.search_rounded,
                kind: ZestButtonKind.secondary,
                expand: false,
                onPressed: () => context.go('/discover'),
              ),
              ZestButton(
                key: const ValueKey('home-bar'),
                label: 'What can I make?',
                icon: Icons.local_bar_rounded,
                kind: ZestButtonKind.secondary,
                expand: false,
                onPressed: () => context.go('/bar'),
              ),
            ],
          ),
          const SizedBox(height: ZestSpace.md),
          const Text(
            'Recipe data and imagery: TheCocktailDB',
            style: TextStyle(color: ZestPalette.secondaryInk),
          ),
        ],
      ),
    );
  }

  Widget _graphView(
    BuildContext context,
    IngredientGraph graph,
    String coverageLabel,
  ) {
    if (graph.isEmpty) {
      return ZestEmptyState(
        announce: true,
        title: 'The constellation is waiting',
        message: 'Ingredients appear here once recipes are loaded on this '
            'device. Start the sync and watch it grow.',
        actionLabel: 'Start syncing',
        onAction: () => ref.read(catalogSyncProvider.notifier).start(),
      );
    }
    final query = _search.text.trim().toLowerCase();
    final matches = query.isEmpty
        ? graph.nodes.length
        : graph.nodes.where((node) => node.identity.contains(query)).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          label: 'Find an ingredient',
          child: TextFormField(
            key: const ValueKey('constellation-search'),
            controller: _search,
            textCapitalization: TextCapitalization.none,
            decoration: InputDecoration(
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface,
              border: const OutlineInputBorder(
                borderRadius: ZestShape.control,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: ZestShape.control,
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.primary,
                  width: 2,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: ZestSpace.sm),
        Semantics(
          liveRegion: true,
          child: Text(
            'Showing $matches of ${graph.nodes.length} ingredients.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        const SizedBox(height: ZestSpace.sm),
        ZestCard(
          child: SizedBox(
            height: _canvasHeight,
            child: ConstellationCanvas(
              key: const ValueKey('constellation-canvas'),
              graph: graph,
              selectedNodeId: _selectedNodeId,
              selectedEdge: _selectedEdge,
              query: _search.text,
              onSelectNode: (identity) => setState(() {
                _selectedNodeId = identity;
                _selectedEdge = null;
              }),
              onSelectEdge: (edge) {
                setState(() {
                  _selectedEdge = edge;
                  _selectedNodeId = null;
                });
                if (edge != null) {
                  showSharedRecipesSheet(context, edge: edge, graph: graph);
                }
              },
            ),
          ),
        ),
        const SizedBox(height: ZestSpace.md),
        _selectionInfo(context, graph),
        const SizedBox(height: ZestSpace.md),
        Text(
          'Sizes show how many loaded recipes use each ingredient; lines '
          'show ingredients that appear together. $coverageLabel',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _listContentView(
    BuildContext context,
    IngredientGraph graph,
    String coverageLabel,
  ) {
    if (graph.isEmpty) {
      return const Text(
        'No ingredients are loaded yet. Start the sync below and this list '
        'fills in as recipes arrive.',
      );
    }
    return ZestCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(coverageLabel, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: ZestSpace.xs),
          ConstellationListView(graph: graph),
        ],
      ),
    );
  }

  Widget _selectionInfo(BuildContext context, IngredientGraph graph) {
    if (_selectedNodeId != null) {
      final node = graph.node(_selectedNodeId!)!;
      final neighborhood = graph.neighborhood(node.identity)!;
      return ZestCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                displayIdentity(node.identity),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            const SizedBox(height: ZestSpace.sm),
            Text(prevalencePhrase(node, graph)),
            const SizedBox(height: ZestSpace.sm),
            if (neighborhood.connections.isEmpty)
              const Text(
                'No other loaded ingredient shares a recipe with this one '
                'yet.',
              )
            else
              Wrap(
                spacing: ZestSpace.sm,
                runSpacing: ZestSpace.sm,
                children: [
                  for (final connection in neighborhood.connections)
                    ZestChip(
                      key: ValueKey(
                        'constellation-link-${connection.node.identity}',
                      ),
                      label: '${displayIdentity(connection.node.identity)} · '
                          '${connection.weight} shared',
                      selected: false,
                      onSelected: (_) => setState(() {
                        _selectedNodeId = connection.node.identity;
                        _selectedEdge = null;
                      }),
                    ),
                ],
              ),
            const SizedBox(height: ZestSpace.lg),
            ZestButton(
              key: const ValueKey('constellation-clear'),
              label: 'Clear selection',
              kind: ZestButtonKind.quiet,
              onPressed: () => setState(() {
                _selectedNodeId = null;
                _selectedEdge = null;
              }),
            ),
          ],
        ),
      );
    }
    if (_selectedEdge != null) {
      final edge = _selectedEdge!;
      return ZestCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                '${displayIdentity(edge.aIdentity)} and '
                '${displayIdentity(edge.bIdentity)}',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            const SizedBox(height: ZestSpace.sm),
            Text(
              'They appear together in ${edge.weight} '
              '${edge.weight == 1 ? 'recipe' : 'recipes'} of the '
              '${graph.recipeCount} in the analyzed collection.',
            ),
            const SizedBox(height: ZestSpace.lg),
            ZestButton(
              key: const ValueKey('constellation-show-shared'),
              label: 'Show the ${edge.weight} '
                  '${edge.weight == 1 ? 'recipe' : 'recipes'}',
              icon: Icons.receipt_long_rounded,
              kind: ZestButtonKind.secondary,
              onPressed: () =>
                  showSharedRecipesSheet(context, edge: edge, graph: graph),
            ),
            const SizedBox(height: ZestSpace.sm),
            ZestButton(
              key: const ValueKey('constellation-clear'),
              label: 'Clear selection',
              kind: ZestButtonKind.quiet,
              onPressed: () => setState(() {
                _selectedNodeId = null;
                _selectedEdge = null;
              }),
            ),
          ],
        ),
      );
    }
    return const Text(
      'Tap an ingredient to see where it leads, or tap a line between two '
      'to see the recipes they share.',
      style: TextStyle(color: ZestPalette.secondaryInk),
    );
  }
}
