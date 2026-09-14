import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/zest_tokens.dart';
import '../../../core/widgets/zest_button.dart';
import '../../../core/widgets/zest_card.dart';
import '../../../core/widgets/zest_states.dart';
import '../../discovery/presentation/discovery_widgets.dart';
import '../application/bar_providers.dart';
import '../domain/bar_match.dart';
import '../domain/recipe_scope.dart';

/// Sets the match scope and opens the bar screen. The single entry point
/// discovery screens use; keeps scope state ownership inside the bar feature.
void openBarMatching(BuildContext context, WidgetRef ref, RecipeScope scope) {
  ref.read(recipeScopeProvider.notifier).setScope(scope);
  context.push('/bar');
}

class BarScopeCard extends StatelessWidget {
  const BarScopeCard({super.key, required this.scope});

  final RecipeScope scope;

  @override
  Widget build(BuildContext context) => ZestCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Matching within', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: ZestSpace.sm),
        DiscoveryHeading(scope.label),
        const SizedBox(height: ZestSpace.sm),
        Text(
          '${scope.recipes.length} ${scope.recipes.length == 1 ? 'recipe' : 'recipes'}. '
          'Matches cover these results — not the full cocktail catalog.',
        ),
        const SizedBox(height: ZestSpace.md),
        ZestButton(
          key: const ValueKey('bar-change-scope'),
          label: 'Choose different results',
          kind: ZestButtonKind.quiet,
          onPressed: () => context.go('/discover'),
        ),
      ],
    ),
  );
}

String _display(String identity) => identity.isEmpty
    ? identity
    : identity[0].toUpperCase() + identity.substring(1);

class MatchResultCard extends StatelessWidget {
  const MatchResultCard({super.key, required this.match});

  final BarMatch match;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ZestCard(
      recipe: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DiscoveryHeading(match.recipe.name),
          const SizedBox(height: ZestSpace.xs),
          Text('TheCocktailDB', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: ZestSpace.md),
          _status(context, colors),
          const SizedBox(height: ZestSpace.md),
          ZestButton(
            key: ValueKey('bar-recipe-${match.recipe.id}'),
            label: 'View recipe',
            semanticLabel: 'View recipe: ${match.recipe.name}',
            kind: ZestButtonKind.secondary,
            onPressed: () =>
                context.push('/discover/recipe/${match.recipe.id}'),
          ),
        ],
      ),
    );
  }

  Widget _status(BuildContext context, ColorScheme colors) {
    final (icon, headline) = switch (match.category) {
      BarMatchCategory.ready => (
        Icons.check_circle_outline_rounded,
        'Ready now — every essential is on your shelf.',
      ),
      BarMatchCategory.substitution => (
        Icons.swap_horiz_rounded,
        'Possible with ${match.substitutions.length} '
            '${match.substitutions.length == 1 ? 'substitution' : 'substitutions'} '
            '— review the recipe before pouring.',
      ),
      BarMatchCategory.missingEssentials => (
        Icons.shopping_basket_outlined,
        'Missing ${match.missingEssentials.length} '
            '${match.missingEssentials.length == 1 ? 'essential' : 'essentials'}: '
            '${match.missingEssentials.join(', ')}.',
      ),
    };
    // Status meaning is carried by icon and text; the tint only groups it.
    final (tint, iconColor) = switch (match.category) {
      BarMatchCategory.ready => (ZestPalette.celery, colors.primary),
      BarMatchCategory.substitution => (
        ZestPalette.grapefruit.withValues(alpha: 0.4),
        colors.primary,
      ),
      BarMatchCategory.missingEssentials => (
        ZestPalette.errorSurface,
        ZestPalette.berry,
      ),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: tint,
            borderRadius: ZestShape.control,
          ),
          child: Padding(
            padding: const EdgeInsets.all(ZestSpace.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExcludeSemantics(child: Icon(icon, size: 20, color: iconColor)),
                const SizedBox(width: ZestSpace.sm),
                Expanded(child: Text(headline)),
              ],
            ),
          ),
        ),
        for (final substitution in match.substitutions) ...[
          const SizedBox(height: ZestSpace.xs),
          Padding(
            padding: const EdgeInsets.only(left: ZestSpace.md),
            child: Text(
              'Use ${_display(substitution.youHave)} instead of '
              '${substitution.recipeWants} — a reviewed suggestion.',
            ),
          ),
        ],
        if (match.optionalGarnishes.isNotEmpty) ...[
          const SizedBox(height: ZestSpace.xs),
          Padding(
            padding: const EdgeInsets.only(left: ZestSpace.md),
            child: Text(
              'Garnish not counted: ${match.optionalGarnishes.join(', ')}.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ],
    );
  }
}

class BarMatchResults extends ConsumerWidget {
  const BarMatchResults({super.key, required this.run});

  final BarMatchState run;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (run.status) {
      BarMatchStatus.idle => const SizedBox.shrink(),
      BarMatchStatus.running => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ZestLoadingState(
            label: 'Checking recipes… ${run.checked} of ${run.total}',
          ),
          const SizedBox(height: ZestSpace.lg),
          if (run.matches.isNotEmpty) _MatchGroups(matches: run.matches),
        ],
      ),
      BarMatchStatus.paused => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DiscoveryFailure(
            error: run.error!,
            onRetry: () => ref.read(barMatchProvider.notifier).resume(),
          ),
          const SizedBox(height: ZestSpace.lg),
          if (run.matches.isNotEmpty) _MatchGroups(matches: run.matches),
        ],
      ),
      BarMatchStatus.done => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(liveRegion: true, child: Text(_summary(run))),
          if (run.unavailable > 0) ...[
            const SizedBox(height: ZestSpace.xs),
            Text(
              'The source could not open ${run.unavailable} '
              '${run.unavailable == 1 ? 'recipe' : 'recipes'}, so '
              '${run.unavailable == 1 ? 'it is' : 'they are'} not counted in '
              'the groups above.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: ZestSpace.lg),
          if (run.matches.isEmpty)
            const Text('No recipes in this collection could be matched.')
          else
            _MatchGroups(matches: run.matches),
          const SizedBox(height: ZestSpace.md),
          Text(
            'Checked ${run.checked} of ${run.total} recipes in this '
            'collection — not the full cocktail catalog.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    };
  }

  String _summary(BarMatchState run) {
    int count(BarMatchCategory category) =>
        run.matches.where((match) => match.category == category).length;
    return 'Finished checking ${run.checked} of ${run.total} recipes. '
        '${count(BarMatchCategory.ready)} ready, '
        '${count(BarMatchCategory.substitution)} with a substitution, '
        '${count(BarMatchCategory.missingEssentials)} missing essentials.';
  }
}

class _MatchGroups extends StatelessWidget {
  const _MatchGroups({required this.matches});

  final List<BarMatch> matches;

  @override
  Widget build(BuildContext context) {
    final ready = matches
        .where((match) => match.category == BarMatchCategory.ready)
        .toList();
    final substitutions = matches
        .where((match) => match.category == BarMatchCategory.substitution)
        .toList();
    final missing =
        matches
            .where(
              (match) => match.category == BarMatchCategory.missingEssentials,
            )
            .toList()
          ..sort(
            (a, b) =>
                a.missingEssentials.length.compareTo(
                      b.missingEssentials.length,
                    ) !=
                    0
                ? a.missingEssentials.length.compareTo(
                    b.missingEssentials.length,
                  )
                : a.recipe.name.compareTo(b.recipe.name),
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (title, group) in [
          ('Ready to make', ready),
          ('Possible with a substitution', substitutions),
          ('Missing essentials', missing),
        ])
          if (group.isNotEmpty) ...[
            DiscoveryHeading(title),
            const SizedBox(height: ZestSpace.xs),
            Text(
              '${group.length} ${group.length == 1 ? 'recipe' : 'recipes'}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: ZestSpace.lg),
            for (final match in group) ...[
              MatchResultCard(match: match),
              const SizedBox(height: ZestSpace.lg),
            ],
          ],
      ],
    );
  }
}
