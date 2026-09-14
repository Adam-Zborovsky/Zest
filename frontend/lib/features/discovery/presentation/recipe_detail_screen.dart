import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/zest_tokens.dart';
import '../../../core/widgets/botanical_paper.dart';
import '../../../core/widgets/zest_button.dart';
import '../../../core/widgets/zest_card.dart';
import '../../../core/widgets/zest_chip.dart';
import '../../../core/widgets/zest_inline_error.dart';
import '../../../core/widgets/zest_states.dart';
import '../../collection/application/collection_providers.dart';
import '../../home_bar/application/home_bar_providers.dart';
import '../../home_bar/domain/home_bar_item.dart';
import '../../bar/domain/ingredient_classification.dart';
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
        const SizedBox(height: ZestSpace.xl),
        _CollectionActions(recipe: recipe),
        const SizedBox(height: ZestSpace.lg),
        _RecipeShoppingAction(recipe: recipe),
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

/// Adds only ingredients the person does not currently stock. Garnishes and
/// reviewed substitutions stay out of this action: the recipe remains the
/// source record, and choosing a substitution is always explicit.
class _RecipeShoppingAction extends ConsumerStatefulWidget {
  const _RecipeShoppingAction({required this.recipe});

  final Recipe recipe;

  @override
  ConsumerState<_RecipeShoppingAction> createState() =>
      _RecipeShoppingActionState();
}

class _RecipeShoppingActionState extends ConsumerState<_RecipeShoppingAction> {
  bool _adding = false;
  bool _added = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(homeBarItemsProvider);
    if (items.isLoading) {
      return const ZestLoadingState(label: 'Checking your home bar…');
    }
    if (items.hasError) {
      return ZestErrorState(
        title: 'Your home bar is out of reach',
        message:
            'Zest could not check which ingredients are already stocked. Try again before adding this recipe to shopping.',
        onRetry: () => ref.invalidate(homeBarItemsProvider),
      );
    }
    final records = items.requireValue;
    final stocked = {
      for (final item in records)
        if (item.location == HomeBarLocation.stocked && !item.deleted)
          item.ingredientId,
    };
    final missing = <String>[];
    final seen = <String>{};
    for (final ingredient in widget.recipe.ingredients) {
      if (!seen.add(ingredient.normalizedName) ||
          stocked.contains(ingredient.normalizedName) ||
          isOptionalGarnish(ingredient.normalizedName)) {
        continue;
      }
      missing.add(ingredient.name);
    }
    if (missing.isEmpty) return const SizedBox.shrink();

    return ZestCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const DiscoveryHeading('Missing essentials'),
          const SizedBox(height: ZestSpace.sm),
          Text(
            '${missing.join(', ')}. Optional garnishes are not added automatically.',
          ),
          const SizedBox(height: ZestSpace.md),
          ZestButton(
            key: ValueKey('recipe-add-missing-${widget.recipe.id}'),
            label: _adding
                ? 'Adding essentials…'
                : _added
                ? 'Added to shopping'
                : 'Add missing essentials to shopping',
            icon: Icons.add_shopping_cart_rounded,
            kind: ZestButtonKind.secondary,
            onPressed: _adding || _added ? null : () => _add(missing),
          ),
          if (_added) ...[
            const SizedBox(height: ZestSpace.sm),
            Semantics(
              liveRegion: true,
              child: Text('Missing essentials added to shopping.'),
            ),
            ZestButton(
              label: 'View shopping',
              kind: ZestButtonKind.quiet,
              onPressed: () => context.go('/bar/shopping'),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: ZestSpace.sm),
            Semantics(liveRegion: true, child: Text(_error!)),
          ],
        ],
      ),
    );
  }

  Future<void> _add(List<String> missing) async {
    setState(() {
      _adding = true;
      _error = null;
    });
    try {
      final repository = ref.read(homeBarRepositoryProvider);
      for (final name in missing) {
        await repository.addToShopping(name);
      }
      if (mounted) setState(() => _added = true);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Unable to update shopping. Try again.');
      }
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }
}

String _metadata(String label, String? value) =>
    '$label: ${value == null || value.trim().isEmpty ? 'Not provided' : value.trim()}';

/// "Save to today" and "make a variation" actions. Every save is a new
/// entry on today's date in the drink calendar, so one cocktail can be saved
/// on many days; the days it was saved are listed here and each opens its
/// entry, where the date can be changed or the entry removed.
class _CollectionActions extends ConsumerStatefulWidget {
  const _CollectionActions({required this.recipe});
  final Recipe recipe;

  @override
  ConsumerState<_CollectionActions> createState() => _CollectionActionsState();
}

class _CollectionActionsState extends ConsumerState<_CollectionActions> {
  static const _visibleSaves = 6;

  bool _busy = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final recipe = widget.recipe;
    final saves =
        ref.watch(savedEntriesForRecipeProvider(recipe.id)).value ?? const [];
    final localizations = MaterialLocalizations.of(context);
    return ZestCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const DiscoveryHeading('Your collection'),
          const SizedBox(height: ZestSpace.md),
          Text(
            saves.isEmpty
                ? 'Save this drink to today in your calendar. You can change '
                      'the day later.'
                : saves.length == 1
                ? 'Saved to your calendar once.'
                : 'Saved to your calendar ${saves.length} times.',
          ),
          const SizedBox(height: ZestSpace.md),
          ZestButton(
            key: const ValueKey('recipe-save'),
            label: 'Save to today',
            icon: Icons.event_available_outlined,
            kind: ZestButtonKind.secondary,
            onPressed: _busy ? null : _save,
          ),
          if (saves.isNotEmpty) ...[
            const SizedBox(height: ZestSpace.md),
            Wrap(
              spacing: ZestSpace.sm,
              runSpacing: ZestSpace.sm,
              children: [
                for (final entry in saves.take(_visibleSaves))
                  ZestChip(
                    key: ValueKey('recipe-saved-${entry.id}'),
                    label: localizations.formatShortMonthDay(entry.day),
                    selected: false,
                    onSelected: (_) => context.push('/collection/${entry.id}'),
                  ),
              ],
            ),
            if (saves.length > _visibleSaves) ...[
              const SizedBox(height: ZestSpace.sm),
              Text(
                '+ ${saves.length - _visibleSaves} more in your calendar.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
          if (_error != null) ...[
            const SizedBox(height: ZestSpace.md),
            ZestInlineError(_error!),
          ],
          const SizedBox(height: ZestSpace.lg),
          const TwineDivider(),
          const SizedBox(height: ZestSpace.lg),
          ZestButton(
            key: const ValueKey('recipe-make-variation'),
            label: 'Make a variation',
            icon: Icons.edit_note_rounded,
            onPressed: () =>
                context.push('/discover/recipe/${recipe.id}/variation'),
          ),
        ],
      ),
    );
  }

  /// A failure is stated inline with what to do, never dropped: a save that
  /// silently fails would look like a success.
  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(collectionRepositoryProvider).saveRecipe(widget.recipe);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Zest could not save this recipe on this device. Try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

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
