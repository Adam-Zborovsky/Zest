/// How a catalog sync run stands. Progress persists through the store's
/// letter rows, so every status is durable across app restarts — a fresh
/// session resumes from the pending letters instead of restarting.
enum CatalogSyncStatus { idle, syncing, pausedCooldown, pausedError, finished }

final class CatalogSyncState {
  const CatalogSyncState({
    this.status = CatalogSyncStatus.idle,
    this.currentLetter,
    this.lettersDone = 0,
    this.recipesLoaded = 0,
    this.secondsRemaining,
    this.retryAt,
    this.error,
  });

  final CatalogSyncStatus status;

  /// The letter currently being fetched, while [status] is
  /// [CatalogSyncStatus.syncing]; null once the last letter has applied.
  final String? currentLetter;

  /// Cumulative counts, including letters synced before this run (the engine
  /// seeds them from the store's coverage, so restarts don't reset progress).
  final int lettersDone;
  final int recipesLoaded;

  /// Cooldown remaining in whole seconds at the moment of the pause, when
  /// [status] is [CatalogSyncStatus.pausedCooldown]. [retryAt] is the
  /// absolute deadline; a countdown UI can tick from it between rebuilds.
  final int? secondsRemaining;
  final DateTime? retryAt;

  /// The failure behind [CatalogSyncStatus.pausedError]. Paused runs are
  /// always resumable by design ([resumable]); the engine never retries
  /// automatically — only explicit `resume()` continues.
  final Object? error;

  bool get resumable =>
      status == CatalogSyncStatus.pausedCooldown ||
      status == CatalogSyncStatus.pausedError;
}
