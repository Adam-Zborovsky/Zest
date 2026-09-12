import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/zest_tokens.dart';
import '../../../core/widgets/botanical_art.dart';
import '../../../core/widgets/botanical_paper.dart';
import '../../../core/widgets/zest_action_tile.dart';
import '../../../core/widgets/zest_button.dart';
import '../../../core/widgets/zest_card.dart';
import '../../../core/widgets/zest_chip.dart';
import '../../../core/widgets/zest_states.dart';
import '../../catalog/application/catalog_providers.dart';
import '../../discovery/presentation/discovery_widgets.dart';
import '../application/constellation_providers.dart';
import '../domain/ingredient_graph.dart';
import '../domain/ingredient_kind.dart';
import 'constellation_canvas.dart';
import 'constellation_widgets.dart';
import 'ingredient_glyph.dart';

/// The honest count line for the bounded graph: the denominator is always
/// the collection's total distinct-ingredient count, and when the top-N
/// bound is applied it is disclosed rather than hidden behind an
/// already-bounded total.
String constellationCountLine(
  IngredientGraph graph, {
  required bool filtering,
  required int matches,
}) {
  final kept = graph.nodes.length;
  final total = graph.totalIdentityCount;
  if (total <= kept) {
    return 'Showing $matches of $total ingredients.';
  }
  return filtering
      ? 'Showing $matches ${matches == 1 ? 'match' : 'matches'} among the '
            'top $kept of $total ingredients.'
      : 'Showing the top $kept of $total ingredients by prevalence.';
}

/// Home: the Night Garden. The constellation fills the night field under the
/// page heading, unboxed and edge to edge within the page width; the paper
/// page below carries search, the legend, the selection details, the two
/// core actions, and the collection status. The list view, the sync card,
/// and the discovery and bar routes carry the same information and the core
/// tasks without the graph.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  static const _canvasHeight = 400.0;

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

  void _clearSelection() => setState(() {
    _selectedNodeId = null;
    _selectedEdge = null;
  });

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

    // A refresh shows the loading state rather than a stale graph.
    final settled = !graphAsync.isLoading;
    final failed = settled && graphAsync.hasError;
    final graph = settled && graphAsync.hasValue && !failed
        ? graphAsync.requireValue
        : null;
    if (graph != null) _syncSelection(graph);
    final showGraph = graph != null && !graph.isEmpty;

    return DiscoveryFrame(
      eyebrow: 'The Ingredient Constellation',
      title: 'Follow the ',
      titleAccent: 'lines.',
      intro:
          'The most-used ingredients in the loaded collection get a place. '
          'Ingredients that appear together in recipes pull close.',
      band: showGraph ? _band(graph) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (failed)
            ZestErrorState(
              title: 'The constellation could not load',
              message:
                  'The loaded recipes could not be read from this device. '
                  'Try again.',
              onRetry: () => ref.invalidate(constellationGraphProvider),
            )
          else if (graph == null)
            const ZestLoadingState(label: 'Laying out the constellation…')
          else if (graph.isEmpty)
            ZestEmptyState(
              announce: true,
              title: 'The constellation is waiting',
              message:
                  'Ingredients appear here once recipes are loaded on this '
                  'device. Start the sync and watch it grow.',
              actionLabel: 'Start syncing',
              onAction: () => ref.read(catalogSyncProvider.notifier).start(),
            )
          else if (_listView)
            _listContentView(context, graph, coverageLabel)
          else
            _graphDetails(context, graph),
          const SizedBox(height: ZestSpace.xxl),
          const _ActionTiles(),
          const SizedBox(height: ZestSpace.xxl),
          const CatalogSyncCard(key: ValueKey('home-sync-card')),
          const SizedBox(height: ZestSpace.xl),
          Text(
            'Recipe data and imagery: TheCocktailDB',
            style: Theme.of(
              context,
            ).textTheme.bodySmall!.copyWith(color: ZestPalette.secondaryInk),
          ),
        ],
      ),
    );
  }

  /// Night-field content: the view switch and, in graph view, the canvas.
  Widget _band(IngredientGraph graph) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
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
      if (!_listView) ...[
        const SizedBox(height: ZestSpace.md),
        NightDotField(
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
      ],
    ],
  );

  Widget _graphDetails(BuildContext context, IngredientGraph graph) {
    final query = _search.text.trim().toLowerCase();
    final matches = query.isEmpty
        ? graph.nodes.length
        : graph.nodes.where((node) => node.identity.contains(query)).length;
    final countLine = constellationCountLine(
      graph,
      filtering: query.isNotEmpty,
      matches: matches,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          label: 'Find an ingredient',
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: ZestShape.control,
              boxShadow: ZestShadow.hard(ZestPalette.leaf),
            ),
            child: TextFormField(
              key: const ValueKey('constellation-search'),
              controller: _search,
              textCapitalization: TextCapitalization.none,
              decoration: const InputDecoration(
                hintText: 'Find an ingredient',
                hintMaxLines: 3,
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ),
        ),
        const SizedBox(height: ZestSpace.md),
        Semantics(
          liveRegion: true,
          child: Text(countLine, style: Theme.of(context).textTheme.bodySmall),
        ),
        const SizedBox(height: ZestSpace.lg),
        ConstellationLegend(graph: graph),
        const SizedBox(height: ZestSpace.xl),
        _selectionInfo(context, graph),
        const SizedBox(height: ZestSpace.md),
        Text(
          'Sizes show how many loaded recipes use each ingredient; lines '
          'show ingredients that appear together.',
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
    return ZestCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(coverageLabel, style: Theme.of(context).textTheme.bodySmall),
          if (graph.totalIdentityCount > graph.nodes.length) ...[
            const SizedBox(height: ZestSpace.xs),
            Text(
              'Showing the top ${graph.nodes.length} of '
              '${graph.totalIdentityCount} ingredients by prevalence.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
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
            Row(
              children: [
                IngredientGlyph(
                  kind: ingredientKindOf(node.identity),
                  size: 44,
                ),
                const SizedBox(width: ZestSpace.md),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      displayIdentity(node.identity),
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: ZestSpace.sm),
            Text(prevalencePhrase(node, graph)),
            const SizedBox(height: ZestSpace.md),
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
                      label:
                          '${displayIdentity(connection.node.identity)} · '
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
              onPressed: _clearSelection,
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
              label:
                  'Show the ${edge.weight} '
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
              onPressed: _clearSelection,
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

/// The two core tasks as cut-paper tiles. They sit side by side when there
/// is room and stack at narrow widths or large text.
class _ActionTiles extends StatelessWidget {
  const _ActionTiles();

  @override
  Widget build(BuildContext context) {
    final find = ZestActionTile(
      key: const ValueKey('home-discover'),
      title: 'Find recipes',
      caption: 'By name, ingredient, or letter',
      motif: BotanicalMotif.emptyGlass,
      onPressed: () => context.go('/discover'),
    );
    final bar = ZestActionTile(
      key: const ValueKey('home-bar'),
      title: 'What can I make?',
      caption: 'Match your shelf to search results',
      motif: BotanicalMotif.garnish,
      tone: ZestTileTone.night,
      onPressed: () => context.go('/bar'),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked =
            constraints.maxWidth < 340 ||
            MediaQuery.textScalerOf(context).scale(16) > 20;
        if (stacked) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              find,
              const SizedBox(height: ZestSpace.lg),
              bar,
            ],
          );
        }
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: find),
              const SizedBox(width: ZestSpace.lg),
              Expanded(child: bar),
            ],
          ),
        );
      },
    );
  }
}
