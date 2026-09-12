import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/zest_tokens.dart';
import '../../../core/widgets/zest_card.dart';
import '../../../core/widgets/zest_states.dart';
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
    return DiscoveryFrame(
      back: true,
      child: ref
          .watch(recipeDetailProvider(id))
          .when(
            skipLoadingOnRefresh: false,
            data: (recipe) => recipe == null
                ? ZestEmptyState(
                    announce: true,
                    title: 'Recipe not found',
                    message:
                        'The source has no recipe at this address. Try finding it by name.',
                    actionLabel: 'Back to discovery',
                    onAction: () => context.go('/discover'),
                  )
                : _RecipeContent(recipe: recipe),
            loading: () => const ZestLoadingState(label: 'Opening the recipe…'),
            error: (error, stack) => DiscoveryFailure(
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('THE RECIPE', style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: ZestSpace.sm),
        DiscoveryHeading(recipe.name, large: true),
        const SizedBox(height: ZestSpace.lg),
        RecipeImage(url: recipe.thumbnailUrl, name: recipe.name),
        const SizedBox(height: ZestSpace.xl),
        ZestCard(
          color: Theme.of(context).colorScheme.secondaryContainer,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Metadata(label: 'Type', value: recipe.alcoholic),
              const SizedBox(height: ZestSpace.sm),
              _Metadata(label: 'Glass', value: recipe.glass),
              const SizedBox(height: ZestSpace.sm),
              _Metadata(label: 'Category', value: recipe.category),
            ],
          ),
        ),
        const SizedBox(height: ZestSpace.section),
        ZestCard(
          recipe: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const DiscoveryHeading('Ingredients'),
              const SizedBox(height: ZestSpace.xs),
              const Text('Measures as given by the source.'),
              const SizedBox(height: ZestSpace.lg),
              if (recipe.ingredients.isEmpty)
                const Text(
                  'The source has not listed ingredients for this recipe.',
                ),
              for (final ingredient in recipe.ingredients) ...[
                Text(
                  ingredient.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  ingredient.measure.display ?? 'Measure not provided',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: ZestSpace.lg),
              ],
            ],
          ),
        ),
        const SizedBox(height: ZestSpace.section),
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
              // Retain source numbering. Otherwise number source paragraphs, not sentences.
              if (!RegExp(r'^\d+[.)]\s').hasMatch(steps[index])) ...[
                Text(
                  '${index + 1}.',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(width: ZestSpace.md),
              ],
              Expanded(child: Text(steps[index])),
            ],
          ),
          const SizedBox(height: ZestSpace.lg),
        ],
        const SizedBox(height: ZestSpace.lg),
        const Divider(),
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

class _Metadata extends StatelessWidget {
  const _Metadata({required this.label, required this.value});
  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) => Text(
    '$label: ${value == null || value!.trim().isEmpty ? 'Not provided' : value!.trim()}',
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
