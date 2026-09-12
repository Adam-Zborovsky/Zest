import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/zest_tokens.dart';
import '../../../core/widgets/botanical_art.dart';
import '../../../core/widgets/zest_button.dart';
import '../../../core/widgets/zest_card.dart';
import '../../../core/widgets/zest_sheet.dart';
import '../../../core/widgets/zest_states.dart';
import '../../catalog/application/catalog_providers.dart';
import '../../catalog/domain/coverage_report.dart';
import '../../catalog/domain/sync_state.dart';
import '../../discovery/application/discovery_providers.dart';
import '../../discovery/domain/recipe.dart';
import '../domain/ingredient_graph.dart';
import '../domain/ingredient_kind.dart';
import 'ingredient_glyph.dart';

/// First-letter display form for normalized identities ("mint leaf" →
/// "Mint leaf"). Identities are data; only the display capitalizes.
String displayIdentity(String identity) => identity.isEmpty
    ? identity
    : identity[0].toUpperCase() + identity.substring(1);

/// The agreed prevalence phrasing, shared by the graph, the canvas info
/// surface, and the list view so every route states counts identically.
String prevalencePhrase(IngredientNode node, IngredientGraph graph) =>
    'Appears in ${node.prevalence} of the ${graph.recipeCount} '
    '${graph.recipeCount == 1 ? 'recipe' : 'recipes'} in the analyzed '
    'collection.';

/// The identified collection label required wherever counts appear.
String coverageLine(CoverageReport report) =>
    'TheCocktailDB recipes loaded on this device '
    '(${report.lettersCompleted} of ${report.lettersTotal} letters · '
    '${report.recipeCount} ${report.recipeCount == 1 ? 'recipe' : 'recipes'}).';

/// Bottom sheet listing the recipes behind one edge, each navigating to the
/// existing recipe detail route.
Future<void> showSharedRecipesSheet(
  BuildContext context, {
  required IngredientEdge edge,
  required IngredientGraph graph,
}) {
  final recipes = graph.sharedRecipes(edge);
  return showZestSheet<void>(
    context: context,
    title:
        '${displayIdentity(edge.aIdentity)} and ${displayIdentity(edge.bIdentity)}',
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Appearing together in ${recipes.length} of the '
          '${graph.recipeCount} recipes in the analyzed collection.',
        ),
        const SizedBox(height: ZestSpace.lg),
        for (final recipe in recipes) ...[
          SharedRecipeTile(recipe: recipe),
          const SizedBox(height: ZestSpace.lg),
        ],
      ],
    ),
  );
}

class SharedRecipeTile extends StatelessWidget {
  const SharedRecipeTile({super.key, required this.recipe});

  final Recipe recipe;

  @override
  Widget build(BuildContext context) => ZestCard(
    recipe: true,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(recipe.name, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: ZestSpace.xs),
        Text('TheCocktailDB', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: ZestSpace.md),
        ZestButton(
          key: ValueKey('constellation-recipe-${recipe.id}'),
          label: 'View recipe',
          semanticLabel: 'View recipe: ${recipe.name}',
          kind: ZestButtonKind.secondary,
          onPressed: () => context.push('/discover/recipe/${recipe.id}'),
        ),
      ],
    ),
  );
}

/// The glyph key for the canvas: only the groups present in this graph, in
/// a fixed order, with the plain statement of what the colors mean.
class ConstellationLegend extends StatelessWidget {
  const ConstellationLegend({super.key, required this.graph});

  final IngredientGraph graph;

  @override
  Widget build(BuildContext context) {
    final present = {
      for (final node in graph.nodes) ingredientKindOf(node.identity),
    };
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: ZestSpace.lg,
          runSpacing: ZestSpace.sm,
          children: [
            for (final kind in IngredientKind.values)
              if (present.contains(kind))
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IngredientGlyph(kind: kind, size: 24),
                    const SizedBox(width: ZestSpace.sm),
                    Flexible(
                      child: Text(kind.label, style: textTheme.labelMedium),
                    ),
                  ],
                ),
          ],
        ),
        const SizedBox(height: ZestSpace.sm),
        Text(
          'Colors group ingredients by name, not by flavor.',
          style: textTheme.bodySmall!.copyWith(color: ZestPalette.secondaryInk),
        ),
      ],
    );
  }
}

/// The textual route to the constellation's information: every kept
/// ingredient with its prevalence phrasing and strongest connections,
/// expandable without the canvas anywhere in the loop.
class ConstellationListView extends StatefulWidget {
  const ConstellationListView({super.key, required this.graph});

  final IngredientGraph graph;

  @override
  State<ConstellationListView> createState() => _ConstellationListViewState();
}

class _ConstellationListViewState extends State<ConstellationListView> {
  String? _expandedIdentity;

  static const _visibleConnections = 6;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [for (final node in widget.graph.nodes) _row(context, node)],
    );
  }

  Widget _row(BuildContext context, IngredientNode node) {
    final expanded = _expandedIdentity == node.identity;
    final neighborhood = expanded
        ? widget.graph.neighborhood(node.identity)
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          key: ValueKey('constellation-item-${node.identity}'),
          onTap: () => setState(() {
            _expandedIdentity = expanded ? null : node.identity;
          }),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: ZestSpace.md),
            child: Row(
              children: [
                IngredientGlyph(kind: ingredientKindOf(node.identity)),
                const SizedBox(width: ZestSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayIdentity(node.identity),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: ZestSpace.xs),
                      Text(
                        prevalencePhrase(node, widget.graph),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                ExcludeSemantics(
                  child: Icon(
                    expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (expanded && neighborhood != null) ...[
          Padding(
            padding: const EdgeInsets.only(left: ZestSpace.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Strongest connections',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                if (neighborhood.connections.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: ZestSpace.sm),
                    child: Text(
                      'No other loaded ingredient shares a recipe with this '
                      'one yet.',
                    ),
                  )
                else
                  for (final connection in neighborhood.connections.take(
                    _visibleConnections,
                  ))
                    InkWell(
                      key: ValueKey(
                        'constellation-connection-'
                        '${connection.node.identity}',
                      ),
                      onTap: () => showSharedRecipesSheet(
                        context,
                        edge: connection.edge,
                        graph: widget.graph,
                      ),
                      child: Padding(
                        // Generous vertical padding keeps the tappable row
                        // at the 48-pixel minimum with its text line.
                        padding: const EdgeInsets.symmetric(
                          vertical: ZestSpace.lg,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${displayIdentity(connection.node.identity)}'
                                ' — ${connection.weight} shared '
                                '${connection.weight == 1 ? 'recipe' : 'recipes'}',
                              ),
                            ),
                            ExcludeSemantics(
                              child: Icon(
                                Icons.chevron_right_rounded,
                                size: 20,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                if (neighborhood.connections.length > _visibleConnections)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: ZestSpace.sm),
                    child: Text(
                      '+ ${neighborhood.connections.length - _visibleConnections} '
                      'more connections, strongest first.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: ZestSpace.sm),
        ],
        const Divider(),
      ],
    );
  }
}

/// Home's sync and coverage status: explains the on-device collection,
/// drives the resumable sync, and always labels counts as the loaded
/// collection — never as proof of full-catalog completeness. Once the sync
/// has finished it shrinks to one quiet identified line; the completeness
/// guidance lives one tap away in a sheet instead of repeating on the page.
class CatalogSyncCard extends ConsumerStatefulWidget {
  const CatalogSyncCard({super.key});

  @override
  ConsumerState<CatalogSyncCard> createState() => _CatalogSyncCardState();
}

class _CatalogSyncCardState extends ConsumerState<CatalogSyncCard> {
  Timer? _ticker;

  /// Absolute deadline synthesized for cooldowns that arrive without a
  /// `retryAt` (no Retry-After from the source). Built once per pause from
  /// the remaining-seconds snapshot so the countdown actually ticks between
  /// rebuilds; cleared whenever the card leaves the cooldown state.
  DateTime? _fallbackDeadline;

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  /// The cooldown state is a snapshot; the UI owns the ticking. Remaining
  /// seconds are recomputed from the absolute deadline on every build, so
  /// rebuilds never drift — mirrors the discovery cooldown card. When the
  /// state carries no deadline, one is synthesized from the remaining-
  /// seconds snapshot so the fallback path still ticks.
  int _remainingSeconds(CatalogSyncState state) {
    if (state.status != CatalogSyncStatus.pausedCooldown) return 0;
    final deadline = state.retryAt ?? _synthesizedDeadline(state);
    if (deadline == null) return math.max(0, state.secondsRemaining ?? 0);
    final now = ref.read(nowProvider)();
    return math.max(0, deadline.difference(now).inSeconds);
  }

  DateTime? _synthesizedDeadline(CatalogSyncState state) {
    final remaining = state.secondsRemaining;
    if (remaining == null) return null;
    return _fallbackDeadline ??= ref
        .read(nowProvider)()
        .add(Duration(seconds: remaining));
  }

  void _ensureTicker() {
    if (_ticker != null) return;
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      final state = ref.read(catalogSyncProvider);
      if (state.status != CatalogSyncStatus.pausedCooldown ||
          _remainingSeconds(state) <= 0) {
        timer.cancel();
        _ticker = null;
      }
      if (mounted) setState(() {});
    });
  }

  void _cancelTicker() {
    _ticker?.cancel();
    _ticker = null;
    _fallbackDeadline = null;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(catalogSyncProvider);
    if (state.status == CatalogSyncStatus.pausedCooldown) {
      _ensureTicker();
      // A deadline on the state supersedes any earlier synthesized one.
      if (state.retryAt != null) _fallbackDeadline = null;
    } else {
      _cancelTicker();
    }
    final coverage = ref.watch(catalogCoverageProvider).value;
    final letters = coverage?.lettersCompleted ?? state.lettersDone;
    final recipes = coverage?.recipeCount ?? state.recipesLoaded;
    final lettersTotal = coverage?.lettersTotal ?? 26;
    final loaded = recipes > 0;
    final report = CoverageReport(
      lettersCompleted: letters,
      lettersTotal: lettersTotal,
      recipeCount: recipes,
      lastCompletedAt: coverage?.lastCompletedAt,
    );

    return switch (state.status) {
      CatalogSyncStatus.idle => ZestCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                'Your recipe collection',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: ZestSpace.sm),
            Text(
              loaded
                  ? coverageLine(report)
                  : 'Nothing is loaded yet. Syncing browses the recipe '
                        'source one letter at a time and saves every recipe on '
                        'this device — progress survives a restart.',
            ),
            if (loaded) ...[
              const SizedBox(height: ZestSpace.sm),
              const Text(
                'Syncing continues from the letters still pending; the '
                'constellation grows with every letter.',
              ),
            ],
            const SizedBox(height: ZestSpace.lg),
            ZestButton(
              key: const ValueKey('sync-start'),
              label: loaded && letters < lettersTotal
                  ? 'Continue syncing'
                  : 'Start syncing',
              icon: Icons.download_rounded,
              onPressed: () => ref.read(catalogSyncProvider.notifier).start(),
            ),
          ],
        ),
      ),
      CatalogSyncStatus.syncing => ZestCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              liveRegion: true,
              child: Text(
                'Syncing… ${state.lettersDone} of $lettersTotal letters · '
                '${state.recipesLoaded} '
                '${state.recipesLoaded == 1 ? 'recipe' : 'recipes'}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: ZestSpace.sm),
            Text(
              state.currentLetter != null
                  ? 'Browsing letter '
                        '“${state.currentLetter!.toUpperCase()}”.'
                  : 'Finishing up.',
            ),
            const SizedBox(height: ZestSpace.sm),
            const Text(
              'Everything loaded so far is saved on this device. Stopping '
              'keeps it.',
              style: TextStyle(color: ZestPalette.secondaryInk),
            ),
            const SizedBox(height: ZestSpace.lg),
            ZestButton(
              key: const ValueKey('sync-stop'),
              label: 'Stop',
              kind: ZestButtonKind.secondary,
              onPressed: () => ref.read(catalogSyncProvider.notifier).stop(),
            ),
          ],
        ),
      ),
      CatalogSyncStatus.pausedCooldown => ZestCard(
        color: Theme.of(context).colorScheme.errorContainer,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              liveRegion: true,
              child: Text(
                'Paused for a moment',
                style: Theme.of(context).textTheme.titleLarge!.copyWith(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
            ),
            const SizedBox(height: ZestSpace.sm),
            Text(
              'The recipe source asked Zest to wait. Your progress is saved '
              'on this device.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
            const SizedBox(height: ZestSpace.lg),
            Builder(
              builder: (context) {
                final remaining = _remainingSeconds(state);
                return ZestButton(
                  key: const ValueKey('sync-resume'),
                  label: remaining > 0
                      ? 'Resume in $remaining s'
                      : 'Resume syncing',
                  icon: Icons.play_arrow_rounded,
                  onPressed: remaining > 0
                      ? null
                      : () => ref.read(catalogSyncProvider.notifier).resume(),
                );
              },
            ),
          ],
        ),
      ),
      CatalogSyncStatus.pausedError => ZestErrorState(
        title: 'The sync hit a problem',
        message:
            'The recipe source is unavailable right now. Everything '
            'loaded so far is saved on this device.',
        actionLabel: 'Resume syncing',
        onRetry: () => ref.read(catalogSyncProvider.notifier).resume(),
      ),
      CatalogSyncStatus.finished => _CollectionNote(report: report),
    };
  }
}

/// The finished collection, stated once: the identified coverage line and a
/// details button whose sheet carries the completeness guidance.
class _CollectionNote extends StatelessWidget {
  const _CollectionNote({required this.report});

  final CoverageReport report;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        const BotanicalArt(motif: BotanicalMotif.citrus, size: 44),
        const SizedBox(width: ZestSpace.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text('Collection loaded', style: textTheme.titleMedium),
              ),
              Text(
                coverageLine(report),
                style: textTheme.bodySmall!.copyWith(
                  color: ZestPalette.secondaryInk,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          key: const ValueKey('collection-details'),
          tooltip: 'About these counts',
          icon: const Icon(Icons.info_outline_rounded),
          onPressed: () => showZestSheet<void>(
            context: context,
            title: 'About these counts',
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(coverageLine(report)),
                if (report.lettersCompleted >= report.lettersTotal) ...[
                  const SizedBox(height: ZestSpace.sm),
                  const Text('Every A–Z browse has completed.'),
                ],
                const SizedBox(height: ZestSpace.sm),
                const Text(
                  CoverageReport.completenessGuidance,
                  style: TextStyle(color: ZestPalette.secondaryInk),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
