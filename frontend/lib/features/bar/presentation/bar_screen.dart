import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/zest_tokens.dart';
import '../../../core/widgets/zest_button.dart';
import '../../../core/widgets/zest_card.dart';
import '../../discovery/presentation/discovery_widgets.dart';
import '../../home_bar/application/home_bar_providers.dart';
import '../application/bar_providers.dart';
import 'bar_widgets.dart';
import '../../home_bar/presentation/home_bar_screen.dart';

class BarScreen extends ConsumerWidget {
  const BarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scope = ref.watch(recipeScopeProvider);
    // A direct visit is the durable, catalog-backed home bar. Discovery
    // continues to own its explicit result scope for the current session;
    // it must never quietly widen that scope to the local catalog.
    if (scope == null) return const HomeBarScreen();
    final stocked = ref.watch(stockedIngredientIdsProvider);
    final selection = stocked.value ?? const <String>{};
    final running = ref.watch(
      barMatchProvider.select((run) => run.status == BarMatchStatus.running),
    );
    return DiscoveryFrame(
      back: true,
      eyebrow: 'Your bar',
      title: 'What can I make?',
      intro:
          'Tell Zest what is on your shelf. It checks the recipes in your '
          'current results and sorts them by what is missing.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...[
            BarScopeCard(scope: scope),
            const SizedBox(height: ZestSpace.lg),
            _ScopedInventoryCard(
              stocked: selection.length,
              loading: stocked.isLoading,
              onManage: () {
                ref.read(recipeScopeProvider.notifier).clear();
                context.go('/bar');
              },
            ),
            const SizedBox(height: ZestSpace.xl),
            ZestButton(
              key: const ValueKey('bar-find-matches'),
              label: 'Find matches',
              icon: Icons.local_bar_rounded,
              onPressed: selection.isEmpty || running
                  ? null
                  : () => ref.read(barMatchProvider.notifier).start(),
            ),
            const SizedBox(height: ZestSpace.md),
            Text(
              running
                  ? 'Checking recipes now — matches appear below as they land.'
                  : stocked.isLoading
                  ? 'Opening your stocked ingredients…'
                  : selection.isEmpty
                  ? 'Add ingredients to My bar to start matching.'
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

class _ScopedInventoryCard extends StatelessWidget {
  const _ScopedInventoryCard({
    required this.stocked,
    required this.loading,
    required this.onManage,
  });

  final int stocked;
  final bool loading;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) => ZestCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const DiscoveryHeading('Ingredients from My bar'),
        const SizedBox(height: ZestSpace.sm),
        Text(
          loading
              ? 'Opening your stocked ingredients…'
              : stocked == 0
              ? 'Your bar is empty. Add catalog ingredients to match these discovery results.'
              : '$stocked ${stocked == 1 ? 'ingredient is' : 'ingredients are'} stocked and used for this match.',
        ),
        const SizedBox(height: ZestSpace.md),
        ZestButton(
          key: const ValueKey('bar-manage-inventory'),
          label: 'Manage my bar',
          icon: Icons.shelves,
          kind: ZestButtonKind.secondary,
          onPressed: onManage,
        ),
      ],
    ),
  );
}
