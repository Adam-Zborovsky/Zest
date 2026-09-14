import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/cocktail_api_exception.dart';
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

/// The application-scoped request gateway shared by discovery and bar
/// matching. Public so M4 bar matching reuses the same conservative
/// 429 cooldown; the client remains the authority for response caching.
final cocktailRequestGatewayProvider = _discoveryRequestGatewayProvider;

/// Source searches and letter browsing return full records, while ingredient
/// filtering returns summaries. The UI has one uniform summary result shape.
final discoveryResultsProvider = FutureProvider.autoDispose
    .family<List<RecipeSummary>, DiscoveryQuery>(
      (ref, query) =>
          ref.watch(_discoveryRequestGatewayProvider).results(query),
      retry: (retryCount, error) => null,
    );

final recipeDetailProvider = FutureProvider.autoDispose.family<Recipe?, String>(
  (ref, id) {
    if (!RegExp(r'^\d+$').hasMatch(id.trim())) {
      throw ArgumentError.value(id, 'id', 'Must be a numeric ID.');
    }
    return ref.watch(_discoveryRequestGatewayProvider).detail(id.trim());
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

  Future<List<RecipeSummary>> results(DiscoveryQuery query) async {
    return _throughCooldown(() async {
      switch (query.mode) {
        case DiscoveryMode.name:
          final recipes = await client.searchByName(query.value);
          return List<RecipeSummary>.unmodifiable(
            recipes.map((recipe) => RecipeSummary.fromJson(recipe.toJson())),
          );
        case DiscoveryMode.ingredient:
          return client.filterByIngredient(query.value);
        case DiscoveryMode.letter:
          final recipes = await client.browseByFirstLetter(query.value);
          return List<RecipeSummary>.unmodifiable(
            recipes.map((recipe) => RecipeSummary.fromJson(recipe.toJson())),
          );
      }
    });
  }

  Future<Recipe?> detail(String id) =>
      _throughCooldown(() => client.lookupRecipe(id));

  Future<List<String>> ingredientNames() =>
      _throughCooldown(client.listIngredientNames);

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
