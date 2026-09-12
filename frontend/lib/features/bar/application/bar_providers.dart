import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../discovery/application/discovery_providers.dart';
import '../domain/bar_match.dart';
import '../domain/ingredient_classification.dart';
import '../domain/recipe_scope.dart';

/// How a match run stands. A run checks the scope's recipes in explicit
/// batches of ten lookups; [checked] and [total] make that progress visible.
enum BarMatchStatus { idle, running, paused, done }

final class BarMatchState {
  const BarMatchState({
    this.status = BarMatchStatus.idle,
    this.checked = 0,
    this.total = 0,
    this.unavailable = 0,
    this.matches = const [],
    this.error,
  });

  final BarMatchStatus status;
  final int checked;
  final int total;
  final int unavailable;
  final List<BarMatch> matches;

  /// Set when [status] is [BarMatchStatus.paused]; a rate limit carries the
  /// shared cooldown for the retry countdown.
  final Object? error;
}

/// Session-only ingredient selection. Nothing is preselected and there is no
/// pantry setup; identities are normalized ingredient names. Unselected is
/// not available — matching counts only what is selected here.
final barSelectionProvider = NotifierProvider<BarSelectionNotifier, Set<String>>(
  BarSelectionNotifier.new,
);

final class BarSelectionNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  /// Toggles one ingredient by its written name, normalizing the identity.
  /// Throws [FormatException] on a blank name.
  void toggle(String name) {
    final identity = normalizeSelection(name);
    state = state.contains(identity)
        ? ({...state}..remove(identity))
        : {...state, identity};
  }

  void clear() => state = const {};
}

/// The recipe pool bar matching covers: the discovery results the user chose.
/// Null until a results screen supplies one.
final recipeScopeProvider = NotifierProvider<RecipeScopeNotifier, RecipeScope?>(
  RecipeScopeNotifier.new,
);

final class RecipeScopeNotifier extends Notifier<RecipeScope?> {
  @override
  RecipeScope? build() => null;

  void setScope(RecipeScope scope) => state = scope;

  void clear() => state = null;
}

/// The provider's ingredient filter names for the selection sheet.
final ingredientOptionsProvider = FutureProvider<List<String>>(
  (ref) => ref.watch(cocktailRequestGatewayProvider).ingredientNames(),
  retry: (retryCount, error) => null,
);

/// Runs matching over the current scope with the current selection. Any
/// change to the scope or selection resets a finished or paused run.
final barMatchProvider = NotifierProvider<BarMatchNotifier, BarMatchState>(
  BarMatchNotifier.new,
);

final class BarMatchNotifier extends Notifier<BarMatchState> {
  static const batchCount = 10;

  int _run = 0;

  @override
  BarMatchState build() {
    // A finished or paused run is stale once the scope or selection changes,
    // and an in-flight run is abandoned: both rebuild this provider, and the
    // bumped token makes the abandoned loop drop out at its next check.
    ref.watch(recipeScopeProvider);
    ref.watch(barSelectionProvider);
    _run++;
    return const BarMatchState();
  }

  /// Starts a new run from the beginning of the scope.
  Future<void> start() => _runFrom(0);

  /// Resumes a paused run from the last checked recipe. The shared cooldown
  /// still applies; the UI surfaces its countdown before enabling this.
  Future<void> resume() => _runFrom(state.checked);

  void reset() {
    _run++;
    state = const BarMatchState();
  }

  Future<void> _runFrom(int startAt) async {
    final scope = ref.read(recipeScopeProvider);
    if (scope == null) return;
    final selection = ref.read(barSelectionProvider);
    if (selection.isEmpty) return;

    final run = ++_run;
    // Paused state's matches cover exactly the recipes before [startAt];
    // lookup misses are tracked separately as [BarMatchState.unavailable].
    final matches = <BarMatch>[...state.matches];
    var unavailable = state.unavailable;

    state = BarMatchState(
      status: BarMatchStatus.running,
      checked: startAt,
      total: scope.recipes.length,
      unavailable: unavailable,
      matches: List.unmodifiable(matches),
    );

    final gateway = ref.read(cocktailRequestGatewayProvider);
    var offset = startAt;
    while (offset < scope.recipes.length) {
      if (_run != run) return;
      final batch = scope.recipes.skip(offset).take(batchCount).toList();
      try {
        final recipes = await Future.wait(
          batch.map((summary) => gateway.detail(summary.id)),
        );
        if (_run != run) return;
        for (final recipe in recipes) {
          if (recipe == null) {
            unavailable++;
            continue;
          }
          matches.add(classifyRecipe(recipe, selection));
        }
        offset += batch.length;
        state = BarMatchState(
          status: BarMatchStatus.running,
          checked: offset,
          total: scope.recipes.length,
          unavailable: unavailable,
          matches: List.unmodifiable(matches),
        );
      } catch (error) {
        if (_run != run) return;
        state = BarMatchState(
          status: BarMatchStatus.paused,
          checked: offset,
          total: scope.recipes.length,
          unavailable: unavailable,
          matches: List.unmodifiable(matches),
          error: error,
        );
        return;
      }
    }
    if (_run != run) return;
    state = BarMatchState(
      status: BarMatchStatus.done,
      checked: scope.recipes.length,
      total: scope.recipes.length,
      unavailable: unavailable,
      matches: List.unmodifiable(matches),
    );
  }
}
