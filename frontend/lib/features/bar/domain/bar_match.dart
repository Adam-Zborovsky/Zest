import '../../discovery/domain/recipe.dart';
import 'ingredient_classification.dart';

/// How a recipe stands against the current ingredient selection.
enum BarMatchCategory {
  /// Every essential ingredient is selected (garnishes aside).
  ready,

  /// Every missing essential has a reviewed substitution the selection
  /// contains; the reader still reviews the swap before making it.
  substitution,

  /// At least one essential is missing with no reviewed substitution.
  missingEssentials,
}

/// One reviewed substitution suggestion. [recipeWants] is the recipe's own
/// display name; [youHave] is the normalized selected identity that could
/// stand in for it.
final class BarSubstitution {
  const BarSubstitution({required this.recipeWants, required this.youHave});

  final String recipeWants;
  final String youHave;

  @override
  bool operator ==(Object other) =>
      other is BarSubstitution &&
      other.recipeWants == recipeWants &&
      other.youHave == youHave;

  @override
  int get hashCode => Object.hash(recipeWants, youHave);

  @override
  String toString() => '$recipeWants -> $youHave';
}

/// One recipe classified against a selection of ingredient names. The source
/// recipe is never modified; this is a computed view of it.
final class BarMatch {
  const BarMatch({
    required this.recipe,
    required this.category,
    required this.missingEssentials,
    required this.substitutions,
    required this.optionalGarnishes,
  });

  final Recipe recipe;
  final BarMatchCategory category;

  /// The recipe's own display names for essentials the selection lacks,
  /// deduplicated by normalized identity, in source order.
  final List<String> missingEssentials;

  /// Reviewed substitution suggestions covering missing essentials.
  final List<BarSubstitution> substitutions;

  /// The recipe's display names for optional garnishes present in the
  /// recipe but excluded from the missing count.
  final List<String> optionalGarnishes;
}

/// Classifies [recipe] against [selectedIngredients] — names as written by
/// the user or provider; they are normalized here. Unselected is not
/// available: only explicitly selected identities count. Garnish forms from
/// the reviewed table are excluded from the missing count and reported
/// separately. Duplicate ingredient slots that normalize to one identity are
/// counted once. Throws [FormatException] on a blank selection entry.
BarMatch classifyRecipe(
  Recipe recipe,
  Set<String> selectedIngredients,
) {
  final available = {
    for (final name in selectedIngredients) normalizeSelection(name),
  };

  final missing = <String>[];
  final missingIdentities = <String>[];
  final garnishes = <String>[];
  final substitutions = <BarSubstitution>[];
  final substitutedIdentities = <String>{};
  final seenIdentities = <String>{};

  for (final ingredient in recipe.ingredients) {
    final identity = ingredient.normalizedName;
    if (!seenIdentities.add(identity)) continue;
    if (available.contains(identity)) continue;
    if (isOptionalGarnish(identity)) {
      garnishes.add(ingredient.name);
      continue;
    }
    final youHave = substitutionFor(identity, available);
    if (youHave != null) {
      substitutions.add(
        BarSubstitution(recipeWants: ingredient.name, youHave: youHave),
      );
      substitutedIdentities.add(identity);
    }
    missing.add(ingredient.name);
    missingIdentities.add(identity);
  }

  final category =
      missing.isEmpty
          ? BarMatchCategory.ready
          : substitutedIdentities.containsAll(missingIdentities)
          ? BarMatchCategory.substitution
          : BarMatchCategory.missingEssentials;

  return BarMatch(
    recipe: recipe,
    category: category,
    missingEssentials: List.unmodifiable(missing),
    substitutions: List.unmodifiable(substitutions),
    optionalGarnishes: List.unmodifiable(garnishes),
  );
}
