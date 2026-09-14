import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/zest_tokens.dart';
import '../../../core/widgets/zest_button.dart';
import '../../../core/widgets/zest_card.dart';
import '../../../core/widgets/zest_chip.dart';
import '../../../core/widgets/zest_states.dart';
import '../../../core/widgets/zest_suggestion_field.dart';
import '../../bar/domain/recipe_scope.dart';
import '../../bar/presentation/bar_widgets.dart';
import '../../catalog/application/catalog_providers.dart';
import '../../catalog/domain/catalog_search_index.dart';
import '../../constellation/presentation/constellation_widgets.dart'
    show CatalogStatusCard;
import '../application/discovery_providers.dart';
import '../domain/discovery_query.dart';
import '../domain/recipe.dart';
import 'discovery_widgets.dart';

class DiscoveryScreen extends ConsumerStatefulWidget {
  const DiscoveryScreen({super.key, this.query});
  final DiscoveryQuery? query;

  @override
  ConsumerState<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends ConsumerState<DiscoveryScreen> {
  final _form = GlobalKey<FormState>();
  final _fieldFocus = FocusNode();
  late final TextEditingController _text;
  late DiscoveryMode _mode;

  @override
  void initState() {
    super.initState();
    _mode = widget.query?.mode == DiscoveryMode.ingredient
        ? DiscoveryMode.ingredient
        : DiscoveryMode.name;
    _text = TextEditingController(
      text: widget.query?.mode == DiscoveryMode.letter
          ? ''
          : widget.query?.value ?? '',
    );
  }

  @override
  void didUpdateWidget(DiscoveryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query &&
        widget.query?.mode != DiscoveryMode.letter) {
      _mode = widget.query?.mode ?? DiscoveryMode.name;
      _form.currentState?.reset();
      _text.text = widget.query?.value ?? '';
    }
  }

  @override
  void dispose() {
    _text.dispose();
    _fieldFocus.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_form.currentState!.validate()) {
      _fieldFocus.requestFocus();
      return;
    }
    _fieldFocus.unfocus();
    final query = DiscoveryQuery(mode: _mode, value: _text.text);
    if (query == widget.query) ref.invalidate(discoveryResultsProvider(query));
    context.go(query.uri.toString());
  }

  /// A recipe suggestion opens its detail, preserving the current route's
  /// query params the same way a result card does. An ingredient suggestion
  /// runs ingredient results for it, matching a free-text submit in that
  /// mode (`docs/M11.md` "Surfaces").
  void _selectSuggestion(CatalogSuggestion suggestion) {
    _fieldFocus.unfocus();
    if (suggestion.kind == CatalogSuggestionKind.recipe) {
      final base = widget.query?.uri ?? Uri(path: '/discover');
      context.push(
        base.replace(path: '/discover/recipe/${suggestion.id}').toString(),
      );
      return;
    }
    setState(() {
      _mode = DiscoveryMode.ingredient;
      _text.text = suggestion.label;
    });
    context.go(
      DiscoveryQuery(
        mode: DiscoveryMode.ingredient,
        value: suggestion.label,
      ).uri.toString(),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Arms the shared search-index freshness listener: a snapshot apply
    // rebuilds `catalogSearchIndexProvider`, which this screen reads below.
    ref.watch(catalogSearchIndexFreshnessProvider);
    final index = ref.watch(catalogSearchIndexProvider).value ??
        CatalogSearchIndex.empty;
    final hasCatalog = ref.watch(catalogCoverageProvider).value?.hasSnapshot ??
        false;
    final query = widget.query;
    return DiscoveryFrame(
      back: true,
      eyebrow: 'Discover',
      title: 'A little curiosity.\n',
      titleAccent: 'A new cocktail.',
      intro: 'Start with a name or an ingredient. See where it takes you.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ZestCard(
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    spacing: ZestSpace.sm,
                    runSpacing: ZestSpace.sm,
                    children: [
                      ZestChip(
                        key: const ValueKey('mode-name'),
                        label: 'By name',
                        selected: _mode == DiscoveryMode.name,
                        onSelected: (_) => setState(() {
                          final draft = _text.text;
                          _mode = DiscoveryMode.name;
                          _form.currentState?.reset();
                          _text.text = draft;
                        }),
                      ),
                      ZestChip(
                        key: const ValueKey('mode-ingredient'),
                        label: 'By ingredient',
                        selected: _mode == DiscoveryMode.ingredient,
                        onSelected: (_) => setState(() {
                          final draft = _text.text;
                          _mode = DiscoveryMode.ingredient;
                          _form.currentState?.reset();
                          _text.text = draft;
                        }),
                      ),
                    ],
                  ),
                  const SizedBox(height: ZestSpace.lg),
                  ExcludeSemantics(
                    child: Text(
                      _mode == DiscoveryMode.name
                          ? 'Cocktail name'
                          : 'Ingredient name',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                  const SizedBox(height: ZestSpace.sm),
                  ZestSuggestionField<CatalogSuggestion>(
                    key: const ValueKey('discovery-query'),
                    controller: _text,
                    focusNode: _fieldFocus,
                    label: _mode == DiscoveryMode.name
                        ? 'Cocktail name'
                        : 'Ingredient name',
                    textInputAction: TextInputAction.search,
                    onFieldSubmitted: (_) => _submit(),
                    validator: (value) =>
                        value == null || value.trim().isEmpty
                        ? 'Enter a name to start your search.'
                        : null,
                    suggestionsFor: (text) => index.suggest(
                      text,
                      kinds: _mode == DiscoveryMode.name
                          ? const {CatalogSuggestionKind.recipe}
                          : const {CatalogSuggestionKind.ingredient},
                    ),
                    labelFor: (suggestion) => suggestion.label,
                    captionFor: (suggestion) =>
                        suggestion.kind == CatalogSuggestionKind.ingredient
                        ? '${suggestion.recipeCount} '
                              '${suggestion.recipeCount == 1 ? 'recipe' : 'recipes'}'
                        : null,
                    semanticLabelFor: (suggestion) =>
                        suggestion.kind == CatalogSuggestionKind.recipe
                        ? '${suggestion.label}, cocktail'
                        : '${suggestion.label}, ingredient, '
                              '${suggestion.recipeCount} '
                              '${suggestion.recipeCount == 1 ? 'recipe' : 'recipes'}',
                    replaceTextOnSelect: false,
                    onSelected: _selectSuggestion,
                  ),
                  const SizedBox(height: ZestSpace.lg),
                  ZestButton(
                    key: const ValueKey('search-submit'),
                    label: 'Find recipes',
                    icon: Icons.search_rounded,
                    onPressed: _submit,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: ZestSpace.md),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              key: PageStorageKey(
                'alphabet-${query?.mode == DiscoveryMode.letter}',
              ),
              initiallyExpanded: query?.mode == DiscoveryMode.letter,
              tilePadding: const EdgeInsets.symmetric(horizontal: ZestSpace.sm),
              title: Text(
                'Browse A–Z',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              subtitle: const Text('Choose the first letter of a cocktail.'),
              expansionAnimationStyle: ZestMotion.reduced(context)
                  ? AnimationStyle.noAnimation
                  : null,
              children: [
                Wrap(
                  spacing: ZestSpace.xs,
                  runSpacing: ZestSpace.xs,
                  children: [
                    for (var code = 97; code <= 122; code++)
                      ZestChip(
                        key: ValueKey('letter-${String.fromCharCode(code)}'),
                        label: String.fromCharCode(code).toUpperCase(),
                        selected:
                            query?.mode == DiscoveryMode.letter &&
                            query?.value == String.fromCharCode(code),
                        onSelected: (_) {
                          _fieldFocus.unfocus();
                          context.go(
                            DiscoveryQuery(
                              mode: DiscoveryMode.letter,
                              value: String.fromCharCode(code),
                            ).uri.toString(),
                          );
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: ZestSpace.section),
          if (query != null) ...[
            DiscoveryHeading(resultTitle(query)),
            const SizedBox(height: ZestSpace.lg),
            if (!hasCatalog)
              const CatalogStatusCard(key: ValueKey('discovery-catalog-status'))
            else
            ref
                .watch(discoveryResultsProvider(query))
                .when(
                  skipLoadingOnRefresh: false,
                  data: (recipes) => recipes.isEmpty
                      ? const _NoResults()
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Semantics(
                              liveRegion: true,
                              child: Text(
                                '${recipes.length} ${recipes.length == 1 ? 'recipe' : 'recipes'} found in your downloaded catalog.',
                              ),
                            ),
                            const SizedBox(height: ZestSpace.lg),
                            for (final recipe in recipes.take(6)) ...[
                              RecipeResultCard(recipe: recipe, query: query),
                              const SizedBox(height: ZestSpace.lg),
                            ],
                            if (recipes.length > 6)
                              ZestButton(
                                key: const ValueKey('see-all-results'),
                                label: 'See all ${recipes.length} results',
                                onPressed: () => context.push(
                                  query.uri
                                      .replace(path: '/discover/results')
                                      .toString(),
                                ),
                              ),
                            const SizedBox(height: ZestSpace.md),
                            ZestButton(
                              key: const ValueKey('bar-from-preview'),
                              label: 'What can I make from these results?',
                              icon: Icons.local_bar_rounded,
                              kind: ZestButtonKind.secondary,
                              onPressed: () => openBarMatching(
                                context,
                                ref,
                                RecipeScope(
                                  label: resultTitle(query),
                                  recipes: recipes,
                                ),
                              ),
                            ),
                            const SizedBox(height: ZestSpace.md),
                            const Text(
                              'Results reflect this search, not the full recipe collection.',
                            ),
                          ],
                        ),
                  loading: () => const ZestLoadingState(),
                  error: (error, stack) => DiscoveryFailure(
                    error: error,
                    onRetry: () =>
                        ref.invalidate(discoveryResultsProvider(query)),
                  ),
                ),
          ] else ...[
            const DiscoveryHeading('No need to know the recipe'),
            const SizedBox(height: ZestSpace.sm),
            const Text(
              'An ingredient is enough to explore. These searches find recipes containing it—not a list of what you can make.',
            ),
          ],
        ],
      ),
    );
  }
}

String resultTitle(DiscoveryQuery query) => switch (query.mode) {
  DiscoveryMode.name => 'Recipes for “${query.value}”',
  DiscoveryMode.ingredient => 'With ${query.value}',
  DiscoveryMode.letter => 'Beginning with ${query.value.toUpperCase()}',
};

class RecipeResultCard extends StatelessWidget {
  const RecipeResultCard({
    super.key,
    required this.recipe,
    required this.query,
  });
  final RecipeSummary recipe;
  final DiscoveryQuery query;

  @override
  Widget build(BuildContext context) => ZestCard(
    recipe: true,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RecipeImage(url: recipe.thumbnailUrl, name: recipe.name, compact: true),
        const SizedBox(height: ZestSpace.lg),
        DiscoveryHeading(recipe.name),
        const SizedBox(height: ZestSpace.xs),
        Text('TheCocktailDB', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: ZestSpace.md),
        ZestButton(
          key: ValueKey('recipe-${recipe.id}'),
          label: 'View recipe',
          semanticLabel: 'View recipe: ${recipe.name}',
          kind: ZestButtonKind.secondary,
          onPressed: () => context.push(
            query.uri.replace(path: '/discover/recipe/${recipe.id}').toString(),
          ),
        ),
      ],
    ),
  );
}

class _NoResults extends StatelessWidget {
  const _NoResults();
  @override
  Widget build(BuildContext context) => ZestEmptyState(
    announce: true,
    title: 'No recipes found',
    message: 'Try another spelling, a shorter name, or a different ingredient.',
    actionLabel: 'Start a new search',
    onAction: () => context.go('/discover'),
  );
}

class ResultsScreen extends ConsumerWidget {
  const ResultsScreen({super.key, required this.query});
  final DiscoveryQuery query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final results = ref.watch(discoveryResultsProvider(query));
    return DiscoveryFrame(
      back: true,
      eyebrow: 'All results',
      title: resultTitle(query),
      intro:
          'All results returned for this search. This is not the full recipe collection.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (results.isLoading)
            const ZestLoadingState()
          else if (results.hasError)
            DiscoveryFailure(
              error: results.error!,
              onRetry: () => ref.invalidate(discoveryResultsProvider(query)),
            )
          else if (results.requireValue.isEmpty)
            const _NoResults()
          else ...[
            ZestButton(
              key: const ValueKey('bar-from-results'),
              label: 'What can I make from these results?',
              icon: Icons.local_bar_rounded,
              kind: ZestButtonKind.secondary,
              onPressed: () => openBarMatching(
                context,
                ref,
                RecipeScope(
                  label: resultTitle(query),
                  recipes: results.requireValue,
                ),
              ),
            ),
            const SizedBox(height: ZestSpace.lg),
          ],
        ],
      ),
      slivers: [
        if (results.hasValue && !results.isLoading && !results.hasError)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: ZestSpace.page),
            sliver: SliverList.builder(
              itemCount: results.requireValue.length,
              itemBuilder: (context, index) => Padding(
                padding: const EdgeInsets.only(bottom: ZestSpace.lg),
                child: RecipeResultCard(
                  recipe: results.requireValue[index],
                  query: query,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
