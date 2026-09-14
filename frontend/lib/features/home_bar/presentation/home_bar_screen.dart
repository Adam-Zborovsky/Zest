import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/zest_tokens.dart';
import '../../../core/widgets/botanical_paper.dart';
import '../../../core/widgets/zest_button.dart';
import '../../../core/widgets/zest_card.dart';
import '../../../core/widgets/zest_sheet.dart';
import '../../../core/widgets/zest_states.dart';
import '../../bar/domain/bar_match.dart';
import '../../discovery/domain/recipe.dart';
import '../../discovery/presentation/discovery_widgets.dart';
import '../application/home_bar_providers.dart';
import '../domain/home_bar_item.dart';
import 'home_bar_match_widgets.dart';

/// The durable home-bar routes. Navigation is route-backed rather than a
/// gesture-only tab so browser history, Back, and deep links remain useful.
class HomeBarScreen extends ConsumerWidget {
  const HomeBarScreen({super.key, this.shopping = false});

  final bool shopping;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(homeBarItemsProvider);
    final recipes = ref.watch(homeBarCatalogRecipesProvider);
    final coverage = ref.watch(homeBarCatalogCoverageProvider);
    return DiscoveryFrame(
      back: true,
      eyebrow: shopping ? 'Shopping' : 'My bar',
      title: shopping ? 'A short list for later' : 'Your botanical shelf',
      intro: shopping
          ? 'Keep the essentials you want to pick up. Adding one to your bar removes it from this list.'
          : 'Add what you have. Zest checks the recipes loaded on this device and keeps optional garnishes out of the count.',
      child: items.when(
        loading: () => const ZestLoadingState(label: 'Opening your home bar…'),
        error: (error, stack) => ZestErrorState(
          title: 'Your home bar is out of reach',
          message: 'The local list could not open. Try again.',
          onRetry: () => ref.invalidate(homeBarItemsProvider),
        ),
        data: (records) => recipes.when(
          loading: () =>
              const ZestLoadingState(label: 'Reading your recipe catalog…'),
          error: (error, stack) => ZestErrorState(
            title: 'Your recipe catalog is out of reach',
            message: 'The locally loaded recipes could not open. Try again.',
            onRetry: () => ref.invalidate(homeBarCatalogRecipesProvider),
          ),
          data: (catalogRecipes) => coverage.when(
            loading: () =>
                const ZestLoadingState(label: 'Checking catalog coverage…'),
            error: (error, stack) => ZestErrorState(
              title: 'Catalog coverage is out of reach',
              message: 'The local coverage summary could not open. Try again.',
              onRetry: () => ref.invalidate(homeBarCatalogCoverageProvider),
            ),
            data: (report) => _HomeBarContent(
              shopping: shopping,
              records: records.where((record) => !record.deleted).toList(),
              recipes: catalogRecipes,
              coverageText:
                  '${report.recipeCount} ${report.recipeCount == 1 ? 'recipe' : 'recipes'} loaded from '
                  '${report.lettersCompleted} of ${report.lettersTotal} catalog letters on this device.',
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeBarContent extends ConsumerStatefulWidget {
  const _HomeBarContent({
    required this.shopping,
    required this.records,
    required this.recipes,
    required this.coverageText,
  });

  final bool shopping;
  final List<HomeBarItem> records;
  final List<Recipe> recipes;
  final String coverageText;

  @override
  ConsumerState<_HomeBarContent> createState() => _HomeBarContentState();
}

class _HomeBarContentState extends ConsumerState<_HomeBarContent> {
  bool _openingPicker = false;
  String? _pickerError;

  @override
  Widget build(BuildContext context) {
    final shopping = widget.shopping;
    final records = widget.records;
    final recipes = widget.recipes;
    final location = shopping
        ? HomeBarLocation.shopping
        : HomeBarLocation.stocked;
    final names = records.where((item) => item.location == location).toList()
      ..sort((left, right) => left.displayName.compareTo(right.displayName));
    final stocked = records
        .where((item) => item.location == HomeBarLocation.stocked)
        .map((item) => item.ingredientId)
        .toSet();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HomeBarDestinations(shopping: shopping),
        const SizedBox(height: ZestSpace.lg),
        _CoverageNote(text: widget.coverageText),
        const SizedBox(height: ZestSpace.lg),
        if (shopping) _ShoppingList(items: names) else _Shelf(items: names),
        const SizedBox(height: ZestSpace.md),
        ZestButton(
          key: ValueKey(
            shopping ? 'shopping-add-ingredient' : 'home-bar-add-ingredient',
          ),
          label: shopping
              ? 'Add ingredient to shopping'
              : 'Add ingredient to bar',
          icon: Icons.add_rounded,
          kind: ZestButtonKind.secondary,
          onPressed: _openingPicker
              ? null
              : () => _openCatalogPicker(context, shopping: shopping),
        ),
        if (_pickerError != null) ...[
          const SizedBox(height: ZestSpace.sm),
          Semantics(liveRegion: true, child: Text(_pickerError!)),
        ],
        if (!shopping) ...[
          const SizedBox(height: ZestSpace.section),
          if (recipes.isEmpty)
            ZestEmptyState(
              announce: true,
              title: 'No local recipes to match yet',
              message:
                  'Sync or browse the recipe catalog, then Zest can match this shelf against the recipes loaded here.',
              actionLabel: 'Explore discovery',
              onAction: () => context.go('/discover'),
            )
          else ...[
            DiscoveryHeading('Matches from your local catalog'),
            const SizedBox(height: ZestSpace.xs),
            Text(
              'These matches use recipes loaded on this device. They do not claim to cover the full cocktail catalog.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: ZestSpace.lg),
            HomeBarMatchGroups(
              matches: [
                for (final recipe in recipes) classifyRecipe(recipe, stocked),
              ],
              onAddMissingEssentials: (missing) async {
                final repository = ref.read(homeBarRepositoryProvider);
                for (final name in missing) {
                  await repository.addToShopping(name);
                }
              },
            ),
          ],
        ],
      ],
    );
  }

  Future<void> _openCatalogPicker(
    BuildContext context, {
    required bool shopping,
  }) async {
    setState(() {
      _openingPicker = true;
      _pickerError = null;
    });
    try {
      final options = await ref.read(
        homeBarCatalogIngredientOptionsProvider.future,
      );
      if (!mounted) return;
      await showZestSheet<void>(
        context: context,
        title: shopping ? 'Add to shopping' : 'Add to your bar',
        child: _CatalogIngredientPicker(
          options: options,
          add: (name) => shopping
              ? ref.read(homeBarRepositoryProvider).addToShopping(name)
              : ref.read(homeBarRepositoryProvider).addToBar(name),
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(
          () => _pickerError =
              'Catalog ingredients could not load. Check the local catalog and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _openingPicker = false);
    }
  }
}

class _HomeBarDestinations extends StatelessWidget {
  const _HomeBarDestinations({required this.shopping});

  final bool shopping;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Home bar destinations',
    child: Wrap(
      spacing: ZestSpace.sm,
      runSpacing: ZestSpace.sm,
      children: [
        ZestButton(
          key: const ValueKey('home-bar-destination'),
          label: 'My bar',
          kind: shopping ? ZestButtonKind.quiet : ZestButtonKind.secondary,
          expand: false,
          onPressed: shopping ? () => context.go('/bar') : null,
        ),
        ZestButton(
          key: const ValueKey('shopping-destination'),
          label: 'Shopping',
          kind: shopping ? ZestButtonKind.secondary : ZestButtonKind.quiet,
          expand: false,
          onPressed: shopping ? null : () => context.go('/bar/shopping'),
        ),
      ],
    ),
  );
}

class _CoverageNote extends StatelessWidget {
  const _CoverageNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => ZestCard(
    padding: const EdgeInsets.all(ZestSpace.md),
    color: ZestPalette.celery,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ExcludeSemantics(child: Icon(Icons.menu_book_outlined)),
        const SizedBox(width: ZestSpace.sm),
        Expanded(
          child: Text(
            '$text Counts describe this local collection, not the full provider catalog.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    ),
  );
}

class _Shelf extends ConsumerWidget {
  const _Shelf({required this.items});

  final List<HomeBarItem> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ZestCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const DiscoveryHeading('On your shelf'),
        const SizedBox(height: ZestSpace.xs),
        Text(
          items.isEmpty
              ? 'Your shelf is empty. Add an ingredient from the locally loaded catalog to start matching.'
              : '${items.length} ${items.length == 1 ? 'ingredient' : 'ingredients'} stocked.',
        ),
        if (items.isNotEmpty) ...[
          const SizedBox(height: ZestSpace.md),
          const TwineDivider(),
          for (final item in items) ...[
            _InventoryRow(
              item: item,
              actionLabel: 'Move to shopping',
              actionIcon: Icons.remove_shopping_cart_outlined,
              onAction: () => ref
                  .read(homeBarRepositoryProvider)
                  .addToShopping(item.displayName),
              onRemove: () =>
                  ref.read(homeBarRepositoryProvider).remove(item.ingredientId),
            ),
            const TwineDivider(),
          ],
        ],
      ],
    ),
  );
}

class _ShoppingList extends ConsumerWidget {
  const _ShoppingList({required this.items});

  final List<HomeBarItem> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ZestCard(
    color: ZestPalette.peach,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const DiscoveryHeading('Shopping list'),
        const SizedBox(height: ZestSpace.xs),
        Text(
          items.isEmpty
              ? 'Nothing to buy yet. Add a catalog ingredient or send missing essentials here from a match.'
              : '${items.length} ${items.length == 1 ? 'ingredient' : 'ingredients'} to pick up.',
        ),
        if (items.isNotEmpty) ...[
          const SizedBox(height: ZestSpace.md),
          const TwineDivider(),
          for (final item in items) ...[
            _InventoryRow(
              item: item,
              actionLabel: 'Added to bar',
              actionIcon: Icons.shelves,
              onAction: () => ref
                  .read(homeBarRepositoryProvider)
                  .addToBar(item.displayName),
              onRemove: () =>
                  ref.read(homeBarRepositoryProvider).remove(item.ingredientId),
            ),
            const TwineDivider(),
          ],
        ],
      ],
    ),
  );
}

class _InventoryRow extends StatelessWidget {
  const _InventoryRow({
    required this.item,
    required this.actionLabel,
    required this.actionIcon,
    required this.onAction,
    required this.onRemove,
  });

  final HomeBarItem item;
  final String actionLabel;
  final IconData actionIcon;
  final Future<void> Function() onAction;
  final Future<void> Function() onRemove;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: ZestSpace.sm),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const ExcludeSemantics(child: Icon(Icons.local_florist_outlined)),
            const SizedBox(width: ZestSpace.sm),
            Expanded(
              child: Text(
                item.displayName,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: ZestSpace.xs),
        Wrap(
          spacing: ZestSpace.sm,
          runSpacing: ZestSpace.xs,
          children: [
            ZestButton(
              label: actionLabel,
              icon: actionIcon,
              kind: ZestButtonKind.quiet,
              expand: false,
              onPressed: onAction,
            ),
            ZestButton(
              label: 'Remove',
              icon: Icons.close_rounded,
              kind: ZestButtonKind.quiet,
              expand: false,
              semanticLabel: 'Remove ${item.displayName}',
              onPressed: onRemove,
            ),
          ],
        ),
      ],
    ),
  );
}

class _CatalogIngredientPicker extends StatefulWidget {
  const _CatalogIngredientPicker({required this.options, required this.add});

  final List<HomeBarCatalogIngredient> options;
  final Future<void> Function(String name) add;

  @override
  State<_CatalogIngredientPicker> createState() =>
      _CatalogIngredientPickerState();
}

class _CatalogIngredientPickerState extends State<_CatalogIngredientPicker> {
  final _search = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _search.addListener(_changed);
  }

  @override
  void dispose() {
    _search
      ..removeListener(_changed)
      ..dispose();
    super.dispose();
  }

  void _changed() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final visible = query.isEmpty
        ? widget.options
        : widget.options
              .where(
                (ingredient) =>
                    ingredient.displayName.toLowerCase().contains(query) ||
                    ingredient.ingredientId.contains(query),
              )
              .toList();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          key: const ValueKey('home-bar-catalog-search'),
          controller: _search,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            labelText: 'Search catalog ingredients',
            hintText: 'For example, gin',
            prefixIcon: Icon(Icons.search_rounded),
          ),
        ),
        const SizedBox(height: ZestSpace.md),
        Semantics(
          liveRegion: true,
          child: Text(
            'Showing ${visible.length} of ${widget.options.length} catalog ingredients.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        const SizedBox(height: ZestSpace.sm),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 360),
          child: visible.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(ZestSpace.lg),
                    child: Text(
                      'No catalog ingredient matches. Try a shorter name.',
                    ),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: visible.length,
                  itemBuilder: (context, index) => ListTile(
                    key: ValueKey(
                      'home-bar-catalog-option-${visible[index].ingredientId}',
                    ),
                    title: Text(visible[index].displayName),
                    trailing: const Icon(Icons.add_rounded),
                    onTap: _saving
                        ? null
                        : () => _add(visible[index].displayName),
                  ),
                ),
        ),
        if (_error != null) ...[
          const SizedBox(height: ZestSpace.sm),
          Semantics(liveRegion: true, child: Text(_error!)),
        ],
      ],
    );
  }

  Future<void> _add(String name) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.add(name);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted)
        setState(() => _error = 'Unable to update your list. Try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
