import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/zest_tokens.dart';
import '../../../core/widgets/botanical_paper.dart';
import '../../../core/widgets/zest_button.dart';
import '../../../core/widgets/zest_card.dart';
import '../../bar/domain/bar_match.dart';
import '../../discovery/presentation/discovery_widgets.dart';

/// Catalog-backed match groups for the persistent shelf. This is kept apart
/// from M4's progressive network run: every recipe here is already present
/// on-device, so changing the bar updates all groups immediately.
class HomeBarMatchGroups extends StatelessWidget {
  const HomeBarMatchGroups({
    super.key,
    required this.matches,
    required this.onAddMissingEssentials,
  });

  final List<BarMatch> matches;
  final Future<void> Function(List<String> names) onAddMissingEssentials;

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
          ..sort((left, right) {
            final count = left.missingEssentials.length.compareTo(
              right.missingEssentials.length,
            );
            return count != 0
                ? count
                : left.recipe.name.compareTo(right.recipe.name);
          });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final group in [
          _MatchGroup('Ready to make', ready),
          _MatchGroup('Possible with a substitution', substitutions),
          _MatchGroup('Missing essentials', missing),
        ])
          if (group.matches.isNotEmpty) ...[
            _HomeBarMatchSection(
              group: group,
              onAddMissingEssentials: onAddMissingEssentials,
            ),
          ],
      ],
    );
  }
}

/// A catalog can hold hundreds of recipes. The count always describes the
/// whole group, while the cards reveal in small batches so a direct visit
/// does not build an unbounded column or bury the next group.
class _HomeBarMatchSection extends StatefulWidget {
  const _HomeBarMatchSection({
    required this.group,
    required this.onAddMissingEssentials,
  });

  static const pageSize = 10;

  final _MatchGroup group;
  final Future<void> Function(List<String> names) onAddMissingEssentials;

  @override
  State<_HomeBarMatchSection> createState() => _HomeBarMatchSectionState();
}

class _HomeBarMatchSectionState extends State<_HomeBarMatchSection> {
  var _visible = _HomeBarMatchSection.pageSize;

  @override
  void didUpdateWidget(_HomeBarMatchSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.group.title != widget.group.title ||
        oldWidget.group.matches.length != widget.group.matches.length) {
      _visible = _HomeBarMatchSection.pageSize;
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.group.matches.length;
    final visible = widget.group.matches.take(_visible).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DiscoveryHeading(widget.group.title),
        const SizedBox(height: ZestSpace.xs),
        Text(
          '$total ${total == 1 ? 'recipe' : 'recipes'}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: ZestSpace.lg),
        for (final match in visible) ...[
          HomeBarMatchCard(
            match: match,
            onAddMissingEssentials: widget.onAddMissingEssentials,
          ),
          const SizedBox(height: ZestSpace.lg),
        ],
        if (_visible < total) ...[
          ZestButton(
            key: ValueKey('home-bar-show-more-${widget.group.title}'),
            label:
                'Show ${(_visible + _HomeBarMatchSection.pageSize).clamp(0, total) - _visible} more',
            kind: ZestButtonKind.quiet,
            onPressed: () => setState(
              () => _visible = (_visible + _HomeBarMatchSection.pageSize).clamp(
                0,
                total,
              ),
            ),
          ),
          const SizedBox(height: ZestSpace.lg),
        ],
      ],
    );
  }
}

final class _MatchGroup {
  const _MatchGroup(this.title, this.matches);

  final String title;
  final List<BarMatch> matches;
}

class HomeBarMatchCard extends StatefulWidget {
  const HomeBarMatchCard({
    super.key,
    required this.match,
    required this.onAddMissingEssentials,
  });

  final BarMatch match;
  final Future<void> Function(List<String> names) onAddMissingEssentials;

  @override
  State<HomeBarMatchCard> createState() => _HomeBarMatchCardState();
}

class _HomeBarMatchCardState extends State<HomeBarMatchCard> {
  bool _adding = false;
  bool _added = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final match = widget.match;
    final colors = Theme.of(context).colorScheme;
    final status = switch (match.category) {
      BarMatchCategory.ready => (
        Icons.check_circle_outline_rounded,
        'Ready now — every essential is in your bar.',
        ZestPalette.celery,
        colors.primary,
      ),
      BarMatchCategory.substitution => (
        Icons.swap_horiz_rounded,
        'Possible with ${match.substitutions.length} '
            '${match.substitutions.length == 1 ? 'substitution' : 'substitutions'} '
            '— review the recipe before pouring.',
        ZestPalette.grapefruit.withValues(alpha: 0.4),
        colors.primary,
      ),
      BarMatchCategory.missingEssentials => (
        Icons.shopping_basket_outlined,
        'Missing ${match.missingEssentials.length} '
            '${match.missingEssentials.length == 1 ? 'essential' : 'essentials'}: '
            '${match.missingEssentials.join(', ')}.',
        ZestPalette.errorSurface,
        ZestPalette.berry,
      ),
    };
    return ZestCard(
      recipe: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DiscoveryHeading(match.recipe.name),
          const SizedBox(height: ZestSpace.xs),
          Text(
            'Recipe data: TheCocktailDB',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: ZestSpace.md),
          DecoratedBox(
            decoration: BoxDecoration(
              color: status.$3,
              borderRadius: ZestShape.control,
            ),
            child: Padding(
              padding: const EdgeInsets.all(ZestSpace.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExcludeSemantics(child: Icon(status.$1, color: status.$4)),
                  const SizedBox(width: ZestSpace.sm),
                  Expanded(child: Text(status.$2)),
                ],
              ),
            ),
          ),
          for (final suggestion in match.substitutions) ...[
            const SizedBox(height: ZestSpace.xs),
            Text(
              'Use ${_title(suggestion.youHave)} instead of '
              '${suggestion.recipeWants} — a reviewed suggestion.',
            ),
          ],
          if (match.optionalGarnishes.isNotEmpty) ...[
            const SizedBox(height: ZestSpace.xs),
            Text(
              'Garnish not counted: ${match.optionalGarnishes.join(', ')}.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (match.category == BarMatchCategory.missingEssentials) ...[
            const SizedBox(height: ZestSpace.md),
            ZestButton(
              key: ValueKey('home-bar-add-missing-${match.recipe.id}'),
              label: _adding
                  ? 'Adding essentials…'
                  : _added
                  ? 'Added to shopping'
                  : 'Add missing essentials to shopping',
              icon: Icons.add_shopping_cart_rounded,
              kind: ZestButtonKind.secondary,
              onPressed: _adding || _added ? null : _addMissing,
            ),
            if (_added) ...[
              const SizedBox(height: ZestSpace.sm),
              Semantics(
                liveRegion: true,
                child: const Text('Missing essentials added to shopping.'),
              ),
              ZestButton(
                label: 'View shopping',
                kind: ZestButtonKind.quiet,
                onPressed: () => context.go('/bar/shopping'),
              ),
            ],
          ],
          if (_error != null) ...[
            const SizedBox(height: ZestSpace.sm),
            Semantics(liveRegion: true, child: Text(_error!)),
          ],
          const SizedBox(height: ZestSpace.md),
          const TwineDivider(),
          const SizedBox(height: ZestSpace.md),
          ZestButton(
            key: ValueKey('home-bar-recipe-${match.recipe.id}'),
            label: 'View recipe',
            semanticLabel: 'View recipe: ${match.recipe.name}',
            kind: ZestButtonKind.quiet,
            onPressed: () =>
                context.push('/discover/recipe/${match.recipe.id}'),
          ),
        ],
      ),
    );
  }

  Future<void> _addMissing() async {
    setState(() {
      _adding = true;
      _error = null;
    });
    try {
      await widget.onAddMissingEssentials(widget.match.missingEssentials);
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

String _title(String identity) => identity.isEmpty
    ? identity
    : identity[0].toUpperCase() + identity.substring(1);
