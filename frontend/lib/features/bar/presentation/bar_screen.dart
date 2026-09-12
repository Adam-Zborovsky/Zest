import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/zest_tokens.dart';
import '../../../core/widgets/zest_button.dart';
import '../../../core/widgets/zest_states.dart';
import '../../discovery/presentation/discovery_widgets.dart';
import '../application/bar_providers.dart';
import 'bar_widgets.dart';

class BarScreen extends ConsumerWidget {
  const BarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scope = ref.watch(recipeScopeProvider);
    final selection = ref.watch(barSelectionProvider);
    return DiscoveryFrame(
      back: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Your bar', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: ZestSpace.sm),
          const DiscoveryHeading('What can I make?', large: true),
          const SizedBox(height: ZestSpace.md),
          const Text(
            'Tell Zest what is on your shelf. It checks the recipes in your '
            'current results and sorts them by what is missing.',
          ),
          const SizedBox(height: ZestSpace.section),
          if (scope == null)
            ZestEmptyState(
              announce: true,
              title: 'Nothing to match yet',
              message: 'Search or browse in Discover, then choose "What can '
                  'I make" from the results.',
              actionLabel: 'Explore discovery',
              onAction: () => context.go('/discover'),
            )
          else ...[
            BarScopeCard(scope: scope),
            const SizedBox(height: ZestSpace.md),
            const IngredientSelectionCard(),
            const SizedBox(height: ZestSpace.lg),
            ZestButton(
              key: const ValueKey('bar-find-matches'),
              label: 'Find matches',
              icon: Icons.local_bar_rounded,
              onPressed: selection.isEmpty
                  ? null
                  : () => ref.read(barMatchProvider.notifier).start(),
            ),
            const SizedBox(height: ZestSpace.sm),
            Text(
              selection.isEmpty
                  ? 'Select at least one ingredient to start matching.'
                  : 'Matching covers the ${scope.recipes.length} '
                        '${scope.recipes.length == 1 ? 'recipe' : 'recipes'} '
                        'in this collection — not the full cocktail catalog.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: ZestSpace.section),
            BarMatchResults(run: ref.watch(barMatchProvider)),
          ],
        ],
      ),
    );
  }
}
