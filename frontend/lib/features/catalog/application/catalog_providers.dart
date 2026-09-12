import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/cocktail_api_exception.dart';
import '../../discovery/application/discovery_providers.dart';
import '../../discovery/domain/recipe.dart';
import '../data/catalog_connection.dart';
import '../data/catalog_database.dart';
import '../data/catalog_repository.dart';
import '../domain/coverage_report.dart';
import '../domain/sync_state.dart';

/// The application-scoped catalog database, opened through the documented
/// cross-platform connection. Tests override this provider with an
/// in-memory or temp-file backed database.
final catalogDatabaseProvider = Provider<CatalogDatabase>((ref) {
  final database = CatalogDatabase(openCatalogConnection());
  ref.onDispose(database.close);
  return database;
});

final catalogRepositoryProvider = Provider<CatalogRepository>((ref) {
  return CatalogRepository(
    database: ref.watch(catalogDatabaseProvider),
    now: ref.watch(nowProvider),
  );
});

/// Where the sync's letters come from: full Recipe records for one A–Z
/// browse. The app wiring goes through the shared request gateway (one
/// conservative 429 cooldown for the whole provider layer); tests inject a
/// fake so no test touches the network.
typedef CatalogLetterSource = Future<List<Recipe>> Function(String letter);

final catalogLetterSourceProvider = Provider<CatalogLetterSource>((ref) {
  return ref.watch(cocktailRequestGatewayProvider).letterRecipes;
});

/// Polite pacing between letter browses. Short and injectable: tests run
/// with [Duration.zero] or a tick, the app keeps its conservative pause.
final catalogLetterGapProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 2),
);

/// The stored coverage snapshot. The sync engine writes to the store between
/// reads, so consumers watching [catalogSyncProvider] should invalidate this
/// when sync state changes to see fresh numbers.
final catalogCoverageProvider = FutureProvider<CoverageReport>(
  (ref) => ref.watch(catalogRepositoryProvider).coverage(),
  retry: (retryCount, error) => null,
);

/// Drives the resumable A–Z catalog sync. Progress lives in the store's
/// letter rows, so `start`/`resume` both continue from the pending letters:
/// a fresh session (or a re-created repository over the same database)
/// picks up exactly where the previous run stopped.
final catalogSyncProvider =
    NotifierProvider<CatalogSyncNotifier, CatalogSyncState>(
      CatalogSyncNotifier.new,
    );

final class CatalogSyncNotifier extends Notifier<CatalogSyncState> {
  /// Mirrors the request gateway's conservative fallback cooldown for the
  /// rare 429 that arrives without a Retry-After.
  static const _fallbackCooldownSeconds = 30;

  int _run = 0;

  @override
  CatalogSyncState build() {
    // Invalidate (and abandon any in-flight loop) when the wiring changes;
    // the bumped token makes abandoned loops drop out at their next check.
    ref.watch(catalogRepositoryProvider);
    ref.watch(catalogLetterSourceProvider);
    ref.watch(catalogLetterGapProvider);
    _run++;
    return const CatalogSyncState();
  }

  /// Begins (or continues) a sync over the store's pending letters. Letters
  /// already synced are never re-requested; when nothing is pending the run
  /// finishes immediately with the stored coverage totals.
  Future<void> start() => _runPending();

  /// Continues after a cooldown or error pause. Resumability is durable —
  /// this is `start` over whatever letters remain pending, so it also works
  /// across app restarts.
  Future<void> resume() => _runPending();

  /// Stops an in-flight run at the next checkpoint. The store keeps its
  /// partial state: a letter whose fetch was already applied stays applied,
  /// one still in flight stays pending. The progress fields below may lag
  /// the store by at most one letter; the store remains the source of truth.
  void stop() {
    _run++;
    state = CatalogSyncState(
      lettersDone: state.lettersDone,
      recipesLoaded: state.recipesLoaded,
    );
  }

  Future<void> _runPending() async {
    final repository = ref.read(catalogRepositoryProvider);
    final source = ref.read(catalogLetterSourceProvider);
    final gap = ref.read(catalogLetterGapProvider);
    final run = ++_run;

    // The preamble runs before the per-letter loop and can fail the same
    // way (the store can be unreadable), so it shares the loop's error
    // handling: failures pause the run resumably instead of escaping as
    // unhandled async exceptions from fire-and-forget button handlers.
    List<String> pending;
    CoverageReport coverage;
    try {
      pending = await repository.pendingLetters();
      if (_run != run) return;
      // Cumulative totals from the store, so a resumed run keeps the
      // earlier letters' progress visible instead of restarting at zero.
      coverage = await repository.coverage();
    } on CocktailApiException catch (error) {
      if (_run != run) return;
      state = error.kind == CocktailApiErrorKind.rateLimited
          ? CatalogSyncState(
              status: CatalogSyncStatus.pausedCooldown,
              lettersDone: state.lettersDone,
              recipesLoaded: state.recipesLoaded,
              secondsRemaining:
                  error.retryAfter?.inSeconds ?? _fallbackCooldownSeconds,
              retryAt: error.retryAt,
            )
          : CatalogSyncState(
              status: CatalogSyncStatus.pausedError,
              lettersDone: state.lettersDone,
              recipesLoaded: state.recipesLoaded,
              error: error,
            );
      return;
    } catch (error) {
      if (_run != run) return;
      state = CatalogSyncState(
        status: CatalogSyncStatus.pausedError,
        lettersDone: state.lettersDone,
        recipesLoaded: state.recipesLoaded,
        error: error,
      );
      return;
    }
    if (_run != run) return;
    var lettersDone = coverage.lettersCompleted;
    var recipesLoaded = coverage.recipeCount;

    if (pending.isEmpty) {
      state = CatalogSyncState(
        status: CatalogSyncStatus.finished,
        lettersDone: lettersDone,
        recipesLoaded: recipesLoaded,
      );
      return;
    }

    state = CatalogSyncState(
      status: CatalogSyncStatus.syncing,
      currentLetter: pending.first,
      lettersDone: lettersDone,
      recipesLoaded: recipesLoaded,
    );

    for (var index = 0; index < pending.length; index++) {
      final letter = pending[index];
      try {
        final recipes = await source(letter);
        if (_run != run) return; // stopped mid-fetch: leave the letter pending
        await repository.upsertLetter(letter, recipes);
        if (_run != run) return; // letter fully applied; state just won't move
        lettersDone++;
        recipesLoaded += recipes.length;
        state = CatalogSyncState(
          status: CatalogSyncStatus.syncing,
          currentLetter:
              index + 1 < pending.length ? pending[index + 1] : null,
          lettersDone: lettersDone,
          recipesLoaded: recipesLoaded,
        );
      } on CocktailApiException catch (error) {
        if (_run != run) return;
        state = error.kind == CocktailApiErrorKind.rateLimited
            ? CatalogSyncState(
                status: CatalogSyncStatus.pausedCooldown,
                lettersDone: lettersDone,
                recipesLoaded: recipesLoaded,
                secondsRemaining:
                    error.retryAfter?.inSeconds ?? _fallbackCooldownSeconds,
                retryAt: error.retryAt,
              )
            : CatalogSyncState(
                status: CatalogSyncStatus.pausedError,
                lettersDone: lettersDone,
                recipesLoaded: recipesLoaded,
                error: error,
              );
        return; // No automatic retries — an explicit resume continues.
      } catch (error) {
        if (_run != run) return;
        state = CatalogSyncState(
          status: CatalogSyncStatus.pausedError,
          lettersDone: lettersDone,
          recipesLoaded: recipesLoaded,
          error: error,
        );
        return;
      }
      if (index + 1 < pending.length) {
        await Future<void>.delayed(gap);
        if (_run != run) return;
      }
    }

    state = CatalogSyncState(
      status: CatalogSyncStatus.finished,
      lettersDone: lettersDone,
      recipesLoaded: recipesLoaded,
    );
  }
}
