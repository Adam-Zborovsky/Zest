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
import '../../catalog/application/catalog_update_controller.dart';
import '../../catalog/domain/catalog_update_state.dart';
import '../../catalog/domain/coverage_report.dart';
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

/// The identified collection label required wherever counts appear:
/// "TheCocktailDB catalog, N recipes, updated <date>." Never claims
/// provider completeness — it just names what is on this device.
String coverageLine(BuildContext context, CoverageReport report) {
  final recipes =
      '${report.recipeCount} ${report.recipeCount == 1 ? 'recipe' : 'recipes'}';
  final publishedAt = report.publishedAt;
  if (publishedAt == null) return 'TheCocktailDB catalog, $recipes.';
  final date = MaterialLocalizations.of(
    context,
  ).formatMediumDate(publishedAt.toLocal());
  return 'TheCocktailDB catalog, $recipes, updated $date.';
}

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
                    // Large enough that the mark draws, so the key shows
                    // the same icon the canvas uses, not just a color.
                    IngredientGlyph(kind: kind, size: 32),
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


/// Home's shared-catalog status: shows automatic-download progress on a
/// first launch, a branded retry on failure with no catalog yet, and
/// otherwise a quiet identified coverage line — "TheCocktailDB catalog, N
/// recipes, updated <date>." Background checks, applies, and staged updates
/// are silent here; they surface through `showZestNotice` instead
/// (`docs/M11.md` "Update behavior").
class CatalogStatusCard extends ConsumerWidget {
  const CatalogStatusCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coverageAsync = ref.watch(catalogCoverageProvider);
    final updateState = ref.watch(catalogUpdateControllerProvider);
    final coverage = coverageAsync.value;
    final hasSnapshot = coverage?.hasSnapshot ?? false;

    if (!hasSnapshot && updateState.status == CatalogUpdateStatus.downloading) {
      return ZestCard(
        child: Row(
          children: [
            const BotanicalArt(motif: BotanicalMotif.citrus, size: 44),
            const SizedBox(width: ZestSpace.md),
            Expanded(
              child: Semantics(
                header: true,
                liveRegion: true,
                child: Text(
                  'Downloading the recipe catalog…',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (!hasSnapshot && updateState.status == CatalogUpdateStatus.failed) {
      return ZestErrorState(
        key: const ValueKey('catalog-download-failed'),
        title: "Couldn't download the catalog",
        message: _failureMessage(updateState.failure),
        actionLabel: 'Retry',
        onRetry: () =>
            ref.read(catalogUpdateControllerProvider.notifier).checkNow(),
      );
    }

    if (!hasSnapshot && coverageAsync.isLoading) {
      return const ZestLoadingState(label: 'Opening your recipe catalog…');
    }

    if (coverageAsync.hasError) {
      return ZestErrorState(
        title: 'The catalog could not open',
        message: 'The local recipe catalog could not be read. Try again.',
        onRetry: () => ref.invalidate(catalogCoverageProvider),
      );
    }

    if (!hasSnapshot || coverage == null) {
      // A safe fallback for the rare case nothing has downloaded and no
      // download is currently running (e.g. the very first frame, before
      // `checkOnLaunch` completes its first async gap).
      return ZestCard(
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
            const Text('Nothing is loaded yet.'),
            const SizedBox(height: ZestSpace.lg),
            ZestButton(
              key: const ValueKey('catalog-download'),
              label: 'Download catalog',
              icon: Icons.download_rounded,
              onPressed: () =>
                  ref.read(catalogUpdateControllerProvider.notifier).checkNow(),
            ),
          ],
        ),
      );
    }

    return _CatalogCollectionNote(report: coverage);
  }

  String _failureMessage(CatalogUpdateFailureKind? kind) => switch (kind) {
    CatalogUpdateFailureKind.offline =>
      "You're offline. Connect and try again.",
    CatalogUpdateFailureKind.timeout =>
      'The recipe source took too long to answer. Try again.',
    CatalogUpdateFailureKind.unavailable =>
      'The recipe source is unavailable right now. Try again shortly.',
    CatalogUpdateFailureKind.rateLimited =>
      'The recipe source asked Zest to wait. Try again shortly.',
    _ => 'The recipe source could not be reached. Try again.',
  };
}

/// The resting collection state: the identified coverage line and a details
/// button whose sheet names the source and states it is not a completeness
/// claim.
class _CatalogCollectionNote extends StatelessWidget {
  const _CatalogCollectionNote({required this.report});

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
                child: Text('Your recipe catalog', style: textTheme.titleMedium),
              ),
              Text(
                coverageLine(context, report),
                style: textTheme.bodySmall!.copyWith(
                  color: ZestPalette.secondaryInk,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          key: const ValueKey('collection-details'),
          tooltip: 'About this catalog',
          icon: const Icon(Icons.info_outline_rounded),
          onPressed: () => showZestSheet<void>(
            context: context,
            title: 'About this catalog',
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(coverageLine(context, report)),
                const SizedBox(height: ZestSpace.sm),
                const Text(
                  'This is TheCocktailDB catalog as last downloaded to this '
                  'device — not necessarily every drink the provider has '
                  'ever published.',
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
