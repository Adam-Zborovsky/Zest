import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/zest_tokens.dart';
import '../../../core/widgets/botanical_paper.dart';
import '../../../core/widgets/zest_card.dart';
import '../../../core/widgets/zest_states.dart';
import '../../constellation/domain/ingredient_kind.dart';
import '../../constellation/presentation/ingredient_glyph.dart';
import '../application/discovery_providers.dart';
import '../domain/instruction_steps.dart';
import '../domain/recipe.dart';
import 'discovery_widgets.dart';

class RecipeDetailScreen extends ConsumerWidget {
  const RecipeDetailScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!RegExp(r'^\d+$').hasMatch(id)) {
      return const InvalidDiscoveryLink(title: 'That recipe link is not valid');
    }
    return ref
        .watch(recipeDetailProvider(id))
        .when(
          skipLoadingOnRefresh: false,
          data: (recipe) => recipe == null
              ? DiscoveryFrame(
                  back: true,
                  child: ZestEmptyState(
                    announce: true,
                    title: 'Recipe not found',
                    message:
                        'The source has no recipe at this address. Try finding it by name.',
                    actionLabel: 'Back to discovery',
                    onAction: () => context.go('/discover'),
                  ),
                )
              : DiscoveryFrame(
                  back: true,
                  eyebrow: 'The recipe',
                  title: recipe.name,
                  child: _RecipeContent(recipe: recipe),
                ),
          loading: () => const DiscoveryFrame(
            back: true,
            child: ZestLoadingState(label: 'Opening the recipe…'),
          ),
          error: (error, stack) => DiscoveryFrame(
            back: true,
            child: DiscoveryFailure(
              error: error,
              onRetry: () => ref.invalidate(recipeDetailProvider(id)),
            ),
          ),
        );
  }
}

class _RecipeContent extends StatelessWidget {
  const _RecipeContent({required this.recipe});
  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    final steps = instructionSteps(recipe.instructions);
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RecipeImage(url: recipe.thumbnailUrl, name: recipe.name),
        const SizedBox(height: ZestSpace.lg),
        Wrap(
          spacing: ZestSpace.sm,
          runSpacing: ZestSpace.sm,
          children: [
            PaperTag(
              label: _metadata('Type', recipe.alcoholic),
              icon: Icons.local_bar_outlined,
            ),
            PaperTag(
              label: _metadata('Glass', recipe.glass),
              icon: Icons.wine_bar_outlined,
            ),
            PaperTag(
              label: _metadata('Category', recipe.category),
              icon: Icons.bookmark_border_rounded,
            ),
          ],
        ),
        const SizedBox(height: ZestSpace.xxl),
        ZestCard(
          recipe: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const DiscoveryHeading('Ingredients'),
              const SizedBox(height: ZestSpace.xs),
              Text(
                'Measures as given by the source.',
                style: textTheme.bodySmall!.copyWith(
                  color: ZestPalette.secondaryInk,
                ),
              ),
              const SizedBox(height: ZestSpace.md),
              if (recipe.ingredients.isEmpty)
                const Text(
                  'The source has not listed ingredients for this recipe.',
                ),
              for (var i = 0; i < recipe.ingredients.length; i++) ...[
                if (i > 0) const TwineDivider(),
                _IngredientRow(
                  name: recipe.ingredients[i].name,
                  measure: recipe.ingredients[i].measure.display,
                  kind: ingredientKindOf(recipe.ingredients[i].normalizedName),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: ZestSpace.xxl),
        const DiscoveryHeading('How to make it'),
        const SizedBox(height: ZestSpace.lg),
        if (steps.isEmpty)
          const Text(
            'The source has not provided instructions for this recipe.',
          ),
        for (var index = 0; index < steps.length; index++) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Retain source numbering. Otherwise number source paragraphs,
              // not sentences.
              if (!RegExp(r'^\d+[.)]\s').hasMatch(steps[index])) ...[
                _StepSeal(number: index + 1),
                const SizedBox(width: ZestSpace.md),
              ],
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(steps[index]),
                ),
              ),
            ],
          ),
          const SizedBox(height: ZestSpace.lg),
        ],
        const SizedBox(height: ZestSpace.sm),
        const TwineDivider(),
        const SizedBox(height: ZestSpace.lg),
        SourceAttribution(
          uri: recipe.attributionUrl,
          notices: [
            if (recipe.sourceUrl != null)
              'Original source: ${recipe.sourceUrl}',
            if (recipe.imageSource != null)
              'Image source: ${recipe.imageSource}',
            if (recipe.imageAttribution != null) recipe.imageAttribution!,
            if (recipe.creativeCommonsConfirmed != null)
              'Source Creative Commons confirmation: ${recipe.creativeCommonsConfirmed}',
          ],
        ),
      ],
    );
  }
}

String _metadata(String label, String? value) =>
    '$label: ${value == null || value.trim().isEmpty ? 'Not provided' : value.trim()}';

/// One source ingredient: its glyph, name, and the measure exactly as the
/// source gives it.
class _IngredientRow extends StatelessWidget {
  const _IngredientRow({
    required this.name,
    required this.measure,
    required this.kind,
  });

  final String name;
  final String? measure;
  final IngredientKind kind;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: ZestSpace.sm),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IngredientGlyph(kind: kind, size: 38),
        const SizedBox(width: ZestSpace.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: ZestSpace.xs),
              measure == null
                  ? const PaperTag(label: 'Measure not provided', dashed: true)
                  : PaperTag(label: measure!),
            ],
          ),
        ),
      ],
    ),
  );
}

/// A grapefruit paper seal for a numbered step.
class _StepSeal extends StatelessWidget {
  const _StepSeal({required this.number});

  final int number;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: ZestPalette.grapefruit,
      borderRadius: ZestShape.pill,
      border: Border.all(color: ZestPalette.leaf, width: 1.5),
    ),
    child: ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: ZestSpace.sm),
        child: Center(
          widthFactor: 1,
          heightFactor: 1,
          child: Text(
            '$number',
            semanticsLabel: 'Step $number',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
      ),
    ),
  );
}

class InvalidDiscoveryLink extends StatelessWidget {
  const InvalidDiscoveryLink({
    super.key,
    this.title = 'That search link is not valid',
  });
  final String title;

  @override
  Widget build(BuildContext context) => DiscoveryFrame(
    back: true,
    child: ZestEmptyState(
      title: title,
      message: 'Start a new search to find a recipe.',
      actionLabel: 'Back to discovery',
      onAction: () => context.go('/discover'),
    ),
  );
}
