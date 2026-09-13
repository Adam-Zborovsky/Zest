import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/design/zest_tokens.dart';
import '../features/bar/presentation/bar_screen.dart';
import '../features/collection/presentation/collection_entry_screen.dart';
import '../features/collection/presentation/collection_screen.dart';
import '../features/collection/presentation/variation_editor_screen.dart';
import '../features/constellation/presentation/home_screen.dart';
import '../features/discovery/domain/discovery_query.dart';
import '../features/discovery/presentation/discovery_screen.dart';
import '../features/discovery/presentation/recipe_detail_screen.dart';

GoRouter createZestRouter({String? initialLocation}) {
  // Keep recipe pushes addressable on web while preserving their origin on Back.
  GoRouter.optionURLReflectsImperativeAPIs = true;
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/',
        pageBuilder: (context, state) =>
            _page(context, state, const HomeScreen()),
      ),
      GoRoute(
        path: '/bar',
        pageBuilder: (context, state) =>
            _page(context, state, const BarScreen()),
      ),
      GoRoute(
        path: '/discover',
        pageBuilder: (context, state) => _page(context, state, _search(state)),
        routes: [
          GoRoute(
            path: 'results',
            pageBuilder: (context, state) =>
                _page(context, state, _search(state, all: true)),
          ),
          GoRoute(
            path: 'recipe/:id',
            pageBuilder: (context, state) => _page(
              context,
              state,
              RecipeDetailScreen(id: state.pathParameters['id']!),
            ),
          ),
          GoRoute(
            path: 'recipe/:id/variation',
            pageBuilder: (context, state) => _page(
              context,
              state,
              VariationEditorScreen.newVariation(
                sourceRecipeId: state.pathParameters['id']!,
              ),
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/collection',
        pageBuilder: (context, state) =>
            _page(context, state, const CollectionScreen()),
        routes: [
          GoRoute(
            path: ':id',
            pageBuilder: (context, state) => _page(
              context,
              state,
              CollectionEntryScreen(id: state.pathParameters['id']!),
            ),
            routes: [
              GoRoute(
                path: 'edit',
                pageBuilder: (context, state) => _page(
                  context,
                  state,
                  VariationEditorScreen.editVariation(
                    entryId: state.pathParameters['id']!,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ],
    errorBuilder: (_, _) =>
        const InvalidDiscoveryLink(title: 'This page is not here'),
  );
}

Widget _search(GoRouterState state, {bool all = false}) {
  try {
    final query = DiscoveryQuery.fromUri(state.uri);
    if (all)
      return query == null
          ? const InvalidDiscoveryLink()
          : ResultsScreen(query: query);
    return DiscoveryScreen(query: query);
  } on FormatException {
    return const InvalidDiscoveryLink();
  }
}

Page<void> _page(BuildContext context, GoRouterState state, Widget child) =>
    CustomTransitionPage<void>(
      key: state.pageKey,
      name: state.uri.toString(),
      child: child,
      transitionDuration: ZestMotion.duration(context, ZestMotion.feedback),
      reverseTransitionDuration: ZestMotion.duration(
        context,
        ZestMotion.feedback,
      ),
      transitionsBuilder: (context, animation, secondaryAnimation, child) =>
          ZestMotion.reduced(context)
          ? child
          : FadeTransition(opacity: animation, child: child),
    );
