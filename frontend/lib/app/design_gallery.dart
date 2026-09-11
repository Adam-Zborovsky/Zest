import 'package:flutter/material.dart';

import '../core/design/zest_tokens.dart';
import '../core/widgets/botanical_art.dart';
import '../core/widgets/zest_button.dart';
import '../core/widgets/zest_card.dart';
import '../core/widgets/zest_chip.dart';
import '../core/widgets/zest_sheet.dart';
import '../core/widgets/zest_states.dart';

/// Temporary M1 gallery. Specimen state is discarded on restart.
class DesignGallery extends StatefulWidget {
  const DesignGallery({
    super.key,
    required this.reducedMotion,
    required this.systemReducedMotion,
    required this.onReducedMotionChanged,
  });
  final bool reducedMotion;
  final bool systemReducedMotion;
  final ValueChanged<bool> onReducedMotionChanged;

  @override
  State<DesignGallery> createState() => _DesignGalleryState();
}

class _DesignGalleryState extends State<DesignGallery> {
  final _ingredients = <String>{'Citrus'};
  bool _saved = false;
  int _retries = 0;

  void _toggleSave() => setState(() => _saved = !_saved);

  void _showIngredients() => showZestSheet<void>(
    context: context,
    title: 'Sample ingredients',
    child: const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Citrus, herbs and sparkling water.'),
        SizedBox(height: ZestSpace.sm),
        Text('Illustrative ingredients only. This is not a tested recipe.'),
      ],
    ),
  );

  Future<void> _showOptions() async {
    final action = await showZestSheet<String>(
      context: context,
      title: 'Recipe options',
      child: Column(
        children: [
          ZestButton(
            label: _saved ? 'Unsave recipe' : 'Save recipe',
            icon: Icons.bookmark_border_rounded,
            kind: ZestButtonKind.secondary,
            onPressed: () => Navigator.of(context).pop('save'),
          ),
          const SizedBox(height: ZestSpace.md),
          ZestButton(
            label: 'View ingredients',
            icon: Icons.info_outline_rounded,
            kind: ZestButtonKind.quiet,
            onPressed: () => Navigator.of(context).pop('ingredients'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (action == 'save') _toggleSave();
    if (action == 'ingredients') _showIngredients();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondary = theme.colorScheme.onSurfaceVariant;
    final caption = theme.textTheme.bodySmall!.copyWith(color: secondary);
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          key: const ValueKey('gallery-scroll'),
          padding: const EdgeInsets.symmetric(
            horizontal: ZestSpace.page,
            vertical: ZestSpace.xl,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: ZestSpace.contentWidth,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: ZestSpace.lg,
                    runSpacing: ZestSpace.sm,
                    children: [
                      Text('Zest', style: theme.textTheme.headlineMedium),
                      Text('Botanical Play · M1', style: caption),
                    ],
                  ),
                  const SizedBox(height: ZestSpace.lg),
                  const Divider(),
                  const SizedBox(height: ZestSpace.page),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final stacked =
                          constraints.maxWidth < 330 ||
                          MediaQuery.textScalerOf(context).scale(16) > 24;
                      final title = Semantics(
                        header: true,
                        child: Text(
                          'A little character.\nEvery pour.',
                          style: theme.textTheme.displayMedium,
                        ),
                      );
                      return stacked
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                title,
                                const SizedBox(height: ZestSpace.sm),
                                const BotanicalArt(size: 88),
                              ],
                            )
                          : Row(
                              children: [
                                Expanded(child: title),
                                const SizedBox(width: ZestSpace.sm),
                                const BotanicalArt(size: 104),
                              ],
                            );
                    },
                  ),
                  const SizedBox(height: ZestSpace.section),
                  ZestCard(
                    recipe: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Sample recipe',
                                    style: theme.textTheme.labelMedium!
                                        .copyWith(color: secondary),
                                  ),
                                  const SizedBox(height: ZestSpace.xs),
                                  Semantics(
                                    header: true,
                                    child: Text(
                                      'Citrus Study',
                                      style: theme.textTheme.headlineMedium,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: ZestSpace.sm),
                            const BotanicalArt(size: 72),
                          ],
                        ),
                        const SizedBox(height: ZestSpace.lg),
                        Text(
                          'An invented recipe for this design preview.',
                          style: TextStyle(color: secondary),
                        ),
                        const SizedBox(height: ZestSpace.lg),
                        Text(
                          'Ingredients',
                          style: theme.textTheme.labelMedium!.copyWith(
                            color: secondary,
                          ),
                        ),
                        const SizedBox(height: ZestSpace.xs),
                        Wrap(
                          spacing: ZestSpace.sm,
                          runSpacing: ZestSpace.xs,
                          children: [
                            for (final ingredient in [
                              'Citrus',
                              'Herbs',
                              'Sparkling',
                            ])
                              ZestChip(
                                label: ingredient,
                                selected: _ingredients.contains(ingredient),
                                onSelected: (selected) => setState(() {
                                  selected
                                      ? _ingredients.add(ingredient)
                                      : _ingredients.remove(ingredient);
                                }),
                              ),
                          ],
                        ),
                        const SizedBox(height: ZestSpace.lg),
                        ZestButton(
                          key: const ValueKey('save-preview'),
                          label: _saved ? 'Unsave recipe' : 'Save recipe',
                          onPressed: _toggleSave,
                          icon: _saved
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_border_rounded,
                        ),
                        const SizedBox(height: ZestSpace.md),
                        ZestButton(
                          label: 'View ingredients',
                          onPressed: _showIngredients,
                          icon: Icons.info_outline_rounded,
                          kind: ZestButtonKind.secondary,
                        ),
                        const SizedBox(height: ZestSpace.md),
                        const ZestButton(
                          label: 'Saved',
                          onPressed: null,
                          icon: Icons.check_rounded,
                        ),
                        const SizedBox(height: ZestSpace.md),
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            _saved
                                ? 'Saved in this preview only.'
                                : 'Changes here are temporary. No recipes are stored.',
                            style: caption,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: ZestSpace.section),
                  ZestEmptyState(
                    title: 'Nothing saved yet',
                    message: 'Save a recipe to find it here.',
                    actionLabel: 'Explore recipes',
                    onAction: () => showZestSheet<void>(
                      context: context,
                      title: 'Discovery preview',
                      child: const Text(
                        'Recipe discovery arrives in a later milestone. This gallery demonstrates the empty state.',
                      ),
                    ),
                  ),
                  const SizedBox(height: ZestSpace.section),
                  const ZestLoadingState(),
                  const SizedBox(height: ZestSpace.section),
                  ZestErrorState(
                    title: 'Recipes couldn’t load',
                    message: 'Check your connection and try again.',
                    onRetry: () => setState(() => _retries++),
                  ),
                  if (_retries > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: ZestSpace.sm),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          'Retry tapped $_retries ${_retries == 1 ? 'time' : 'times'}. Preview only.',
                          style: caption,
                        ),
                      ),
                    ),
                  const SizedBox(height: ZestSpace.section),
                  ZestCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Semantics(
                          header: true,
                          child: Text(
                            'Bottom sheet',
                            style: theme.textTheme.titleLarge,
                          ),
                        ),
                        const SizedBox(height: ZestSpace.sm),
                        Text(
                          'A little room for the next step.',
                          style: TextStyle(color: secondary),
                        ),
                        const SizedBox(height: ZestSpace.lg),
                        ZestButton(
                          key: const ValueKey('open-options'),
                          label: 'Open recipe options',
                          onPressed: _showOptions,
                          kind: ZestButtonKind.secondary,
                          icon: Icons.tune_rounded,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: ZestSpace.section),
                  const Divider(),
                  const SizedBox(height: ZestSpace.page),
                  Semantics(
                    header: true,
                    child: Text(
                      'The botanical palette',
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  const SizedBox(height: ZestSpace.lg),
                  Wrap(
                    spacing: ZestSpace.md,
                    runSpacing: ZestSpace.md,
                    children: [
                      for (final swatch in const [
                        ('Fennel', ZestPalette.fennel),
                        ('Leaf', ZestPalette.leaf),
                        ('Celery', ZestPalette.celery),
                        ('Grapefruit', ZestPalette.grapefruit),
                        ('Peach', ZestPalette.peach),
                        ('Berry', ZestPalette.berry),
                      ])
                        _PaletteSwatch(label: swatch.$1, color: swatch.$2),
                    ],
                  ),
                  const SizedBox(height: ZestSpace.lg),
                  Text('Fraunces headings · DM Sans body', style: caption),
                  const SizedBox(height: ZestSpace.section),
                  Semantics(
                    header: true,
                    child: Text(
                      'Preview controls',
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  const SizedBox(height: ZestSpace.sm),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: ZestChip(
                      label: 'Reduce motion',
                      selected: widget.reducedMotion,
                      onSelected: widget.systemReducedMotion
                          ? null
                          : widget.onReducedMotionChanged,
                    ),
                  ),
                  Text(
                    widget.systemReducedMotion
                        ? 'Reduced motion is enabled by your device.'
                        : 'Compare immediate feedback with the standard transitions.',
                    style: caption,
                  ),
                  const SizedBox(height: ZestSpace.md),
                  ZestButton(
                    label: 'Reset preview',
                    kind: ZestButtonKind.quiet,
                    onPressed: () => setState(() {
                      _saved = false;
                      _ingredients
                        ..clear()
                        ..add('Citrus');
                      _retries = 0;
                    }),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PaletteSwatch extends StatelessWidget {
  const _PaletteSwatch({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 128,
    child: ZestCard(
      padding: const EdgeInsets.all(ZestSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: Container(
              height: 24,
              decoration: BoxDecoration(
                color: color,
                borderRadius: ZestShape.control,
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
            ),
          ),
          const SizedBox(height: ZestSpace.sm),
          Text(label, style: Theme.of(context).textTheme.labelMedium),
        ],
      ),
    ),
  );
}
