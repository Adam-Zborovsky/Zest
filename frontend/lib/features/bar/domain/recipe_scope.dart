import '../../discovery/domain/recipe.dart';

/// The recipe pool a bar match runs against: a labeled set of discovery
/// results. Matching covers exactly these recipes — never the provider's
/// whole catalog.
final class RecipeScope {
  RecipeScope({required this.label, required List<RecipeSummary> recipes})
    : recipes = List.unmodifiable(recipes) {
    if (label.trim().isEmpty) {
      throw ArgumentError.value(label, 'label', 'Must not be blank.');
    }
  }

  /// Human-readable description of the discovery results, e.g.
  /// "Recipes for “gin”".
  final String label;

  final List<RecipeSummary> recipes;
}
