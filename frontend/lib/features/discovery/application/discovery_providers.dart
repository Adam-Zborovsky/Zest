import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/cocktail_api_exception.dart';
import '../../catalog/application/catalog_providers.dart';
import '../../catalog/domain/catalog_search_index.dart';
import '../data/cocktail_db_client.dart';
import '../domain/discovery_query.dart';
import '../domain/recipe.dart';

/// The application-scoped CocktailDB client. Tests and app composition may
/// override this provider with an injected client.
final cocktailDbClientProvider = Provider<CocktailDbClient>((ref) {
  final client = CocktailDbClient();
  ref.onDispose(client.close);
  return client;
});

/// Injectable clock for deterministic cooldown behavior.
final nowProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final _discoveryRequestGatewayProvider = Provider<CocktailRequestGateway>((ref) {
  return CocktailRequestGateway(
    client: ref.watch(cocktailDbClientProvider),
    now: ref.watch(nowProvider),
  );
});

/// Local-catalog results per `docs/M11.md` "Surfaces": name and ingredient
/// results come from the ranked search index, letter results are every
/// stored recipe whose folded name starts with that letter, ordered by
/// name. No network call is made; offline with a downloaded catalog works
/// the same as online.
final discoveryResultsProvider = FutureProvider.autoDispose
    .family<List<RecipeSummary>, DiscoveryQuery>((ref, query) async {
      final index = await ref.watch(catalogSearchIndexProvider.future);
      final recipes = await ref.watch(catalogRepositoryProvider).allRecipes();
      final byId = {for (final recipe in recipes) recipe.id: recipe};
      final List<String> ids;
      switch (query.mode) {
        case DiscoveryMode.name:
          ids = index.recipeIdsMatchingName(query.value);
        case DiscoveryMode.ingredient:
          ids = index.recipeIdsWithIngredient(query.value);
        case DiscoveryMode.letter:
          final matches = recipes
              .where(
                (recipe) => foldSearchText(recipe.name).startsWith(query.value),
              )
              .toList()
            ..sort(
              (a, b) => foldSearchText(a.name).compareTo(foldSearchText(b.name)),
            );
          ids = [for (final recipe in matches) recipe.id];
      }
      return [
        for (final id in ids)
          if (byId[id] case final recipe?)
            RecipeSummary.fromJson(recipe.toJson()),
      ];
    }, retry: (retryCount, error) => null);

/// Local catalog first, `lookup.php` only when the id is absent from the
/// downloaded catalog (a saved recipe that has since left the shared
/// snapshot). Shared with the M4 bar-matching detail fetches.
Future<Recipe?> lookupRecipeLocalFirst(Ref ref, String id) async {
  final local = await ref.watch(catalogRepositoryProvider).recipeById(id);
  if (local != null) return local;
  return ref.watch(_discoveryRequestGatewayProvider).detail(id);
}

final recipeDetailProvider = FutureProvider.autoDispose.family<Recipe?, String>(
  (ref, id) {
    final trimmed = id.trim();
    if (!RegExp(r'^\d+$').hasMatch(trimmed)) {
      throw ArgumentError.value(id, 'id', 'Must be a numeric ID.');
    }
    return lookupRecipeLocalFirst(ref, trimmed);
  },
  retry: (retryCount, error) => null,
);

/// Coordinates the provider layer's single conservative 429 cooldown. The
/// client remains the authority for response caching and never gets closed here.
final class CocktailRequestGateway {
  CocktailRequestGateway({required this.client, required this.now});

  static const _fallbackCooldown = Duration(seconds: 30);

  final CocktailDbClient client;
  final DateTime Function() now;
  DateTime? _cooldownUntil;

  Future<Recipe?> detail(String id) =>
      _throughCooldown(() => client.lookupRecipe(id));

  Future<T> _throughCooldown<T>(Future<T> Function() request) async {
    final until = _cooldownUntil;
    if (until != null) {
      final remaining = until.difference(now());
      if (remaining > Duration.zero) {
        throw CocktailApiException(
          CocktailApiErrorKind.rateLimited,
          statusCode: 429,
          retryAfter: remaining,
          retryAt: until,
        );
      }
      _cooldownUntil = null;
    }
    try {
      return await request();
    } on CocktailApiException catch (error) {
      if (error.kind == CocktailApiErrorKind.rateLimited) {
        final delay = error.retryAfter ?? _fallbackCooldown;
        final currentTime = now();
        final proposedUntil = currentTime.add(delay);
        final existingUntil = _cooldownUntil;
        final effectiveUntil =
            existingUntil != null && existingUntil.isAfter(proposedUntil)
            ? existingUntil
            : proposedUntil;
        _cooldownUntil = effectiveUntil;
        throw CocktailApiException(
          CocktailApiErrorKind.rateLimited,
          statusCode: 429,
          retryAfter: effectiveUntil.difference(currentTime),
          retryAt: effectiveUntil,
        );
      }
      rethrow;
    }
  }
}
