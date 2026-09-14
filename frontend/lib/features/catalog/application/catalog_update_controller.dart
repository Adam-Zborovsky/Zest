import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/cocktail_api_exception.dart';
import '../data/catalog_snapshot_client.dart';
import '../domain/catalog_snapshot.dart';
import '../domain/catalog_update_state.dart';
import 'catalog_providers.dart';

/// How long since the last successful check before an app resume re-checks
/// (`docs/M11.md` "Update behavior": "App resumed after 6+ hours").
const catalogResumeCheckThreshold = Duration(hours: 6);

/// Drives the shared-catalog download/apply lifecycle per `docs/M11.md`
/// "Update behavior". One instance is shared app-wide: launch, resume, and
/// the manual profile-sheet trigger all go through the same coalesced run,
/// so a run already in flight is never duplicated.
final catalogUpdateControllerProvider =
    NotifierProvider<CatalogUpdateController, CatalogUpdateState>(
      CatalogUpdateController.new,
    );

final class CatalogUpdateController extends Notifier<CatalogUpdateState> {
  int _run = 0;
  Future<CatalogUpdateOutcome>? _inFlight;
  CatalogSnapshot? _stagedSnapshot;
  bool _launchChecked = false;

  @override
  CatalogUpdateState build() {
    // Rebuilding (wiring changed, e.g. in tests) abandons any in-flight run:
    // the bumped token makes it drop out at its next check, and the staged
    // snapshot from a superseded run is discarded with it.
    ref.watch(catalogRepositoryProvider);
    ref.watch(catalogSnapshotFetcherProvider);
    _run++;
    _stagedSnapshot = null;
    _inFlight = null;
    _launchChecked = false;
    return const CatalogUpdateState();
  }

  /// Called once after the first frame. An empty on-device catalog is
  /// downloaded and applied automatically (progress shown in the home
  /// card); an existing catalog is checked in the background, applying and
  /// posting a notice only when the version actually changed.
  Future<void> checkOnLaunch() async {
    if (_launchChecked) return;
    _launchChecked = true;
    final repository = ref.read(catalogRepositoryProvider);
    final hadSnapshot = await repository.currentSnapshot() != null;
    await _coalesced(() => _run0(stageOnly: false, silent: !hadSnapshot));
  }

  /// The profile sheet's "Check for catalog updates" row. Always applies a
  /// found update immediately (never stages), and its result is reported
  /// inline in the sheet via the returned outcome.
  Future<CatalogUpdateOutcome> checkNow() =>
      _coalesced(() => _run0(stageOnly: false));

  /// Called when the app is resumed. Checks only when the last successful
  /// check was 6+ hours ago; when a new version exists it is downloaded and
  /// validated but **staged** rather than applied, so a person mid-session
  /// never has their data swapped under them.
  Future<void> checkAfterResume() async {
    final lastCheckedAt = state.lastCheckedAt;
    final now = ref.read(catalogNowProvider)();
    if (lastCheckedAt != null &&
        now.difference(lastCheckedAt) < catalogResumeCheckThreshold) {
      return;
    }
    await _coalesced(() => _run0(stageOnly: true));
  }

  /// Applies a snapshot staged by [checkAfterResume], in response to the
  /// notice's **Update** action. A no-op if nothing is staged (the run that
  /// staged it was superseded, or nothing was ever staged).
  Future<void> applyStaged() async {
    final snapshot = _stagedSnapshot;
    if (snapshot == null) return;
    final run = ++_run;
    final repository = ref.read(catalogRepositoryProvider);
    final diff = await repository.applySnapshot(snapshot);
    _stagedSnapshot = null;
    if (_run != run) return;
    // Silent: the notice's own Update action was the feedback; applying it
    // must not also pop the background-update notice on top of it.
    state = CatalogUpdateState(
      status: CatalogUpdateStatus.updated,
      diff: diff,
      lastCheckedAt: state.lastCheckedAt,
      silent: true,
    );
  }

  /// Concurrent triggers coalesce into the one run already in flight,
  /// instead of starting a second overlapping download/apply.
  Future<CatalogUpdateOutcome> _coalesced(
    Future<CatalogUpdateOutcome> Function() start,
  ) {
    final pending = _inFlight;
    if (pending != null) return pending;
    final future = start();
    _inFlight = future;
    future.whenComplete(() {
      if (identical(_inFlight, future)) _inFlight = null;
    });
    return future;
  }

  Future<CatalogUpdateOutcome> _run0({
    required bool stageOnly,
    bool silent = false,
  }) async {
    final run = ++_run;
    final repository = ref.read(catalogRepositoryProvider);
    final fetcher = ref.read(catalogSnapshotFetcherProvider);
    final now = ref.read(catalogNowProvider)();

    // Every state write below is guarded by a staleness check performed
    // immediately beforehand — never after — so a run abandoned by a rebuild
    // (the bumped token) can never clobber a fresher run's state with a
    // write that was already in flight when it was abandoned.
    final current = await repository.currentSnapshot();
    if (_run != run) return const CatalogUpdateUpToDate();
    state = CatalogUpdateState(
      status: current == null
          ? CatalogUpdateStatus.downloading
          : CatalogUpdateStatus.checking,
      lastCheckedAt: state.lastCheckedAt,
    );

    CatalogSnapshotFetch fetch;
    try {
      fetch = await fetcher(ifNoneMatchVersion: current?.version);
    } on CocktailApiException catch (error) {
      final kind = _failureKind(error);
      if (_run != run) return CatalogUpdateFailed(kind);
      state = CatalogUpdateState(
        status: CatalogUpdateStatus.failed,
        failure: kind,
        lastCheckedAt: state.lastCheckedAt,
      );
      return CatalogUpdateFailed(kind);
    } catch (error) {
      // Never let an unexpected error escape a fire-and-forget lifecycle
      // callback as an unhandled async exception — land it resumably, the
      // same way the old letter-sync engine treated non-gateway failures.
      const kind = CatalogUpdateFailureKind.unknown;
      if (_run != run) return const CatalogUpdateFailed(kind);
      state = CatalogUpdateState(
        status: CatalogUpdateStatus.failed,
        failure: kind,
        lastCheckedAt: state.lastCheckedAt,
      );
      return const CatalogUpdateFailed(kind);
    }
    if (_run != run) return const CatalogUpdateUpToDate();

    if (fetch is CatalogSnapshotUnchanged) {
      state = CatalogUpdateState(
        status: CatalogUpdateStatus.upToDate,
        lastCheckedAt: now,
      );
      return const CatalogUpdateUpToDate();
    }

    final snapshot = (fetch as CatalogSnapshotAvailable).snapshot;
    if (current != null && snapshot.version == current.version) {
      state = CatalogUpdateState(
        status: CatalogUpdateStatus.upToDate,
        lastCheckedAt: now,
      );
      return const CatalogUpdateUpToDate();
    }

    state = CatalogUpdateState(
      status: CatalogUpdateStatus.downloading,
      lastCheckedAt: state.lastCheckedAt,
    );

    if (stageOnly) {
      final diff = await repository.previewDiff(snapshot);
      if (_run != run) return CatalogUpdateStaged(diff);
      _stagedSnapshot = snapshot;
      state = CatalogUpdateState(
        status: CatalogUpdateStatus.staged,
        diff: diff,
        lastCheckedAt: now,
        silent: silent,
      );
      return CatalogUpdateStaged(diff);
    }

    final diff = await repository.applySnapshot(snapshot);
    if (_run != run) return CatalogUpdateApplied(diff);
    state = CatalogUpdateState(
      status: CatalogUpdateStatus.updated,
      diff: diff,
      lastCheckedAt: now,
      silent: silent,
    );
    return CatalogUpdateApplied(diff);
  }

  CatalogUpdateFailureKind _failureKind(CocktailApiException error) {
    if (error.kind == CocktailApiErrorKind.rateLimited) {
      return CatalogUpdateFailureKind.rateLimited;
    }
    if (error.kind == CocktailApiErrorKind.timeout) {
      return CatalogUpdateFailureKind.timeout;
    }
    if (error.kind == CocktailApiErrorKind.network) {
      return CatalogUpdateFailureKind.offline;
    }
    if (error.kind == CocktailApiErrorKind.invalidResponse) {
      return CatalogUpdateFailureKind.invalidResponse;
    }
    if (error.kind == CocktailApiErrorKind.http && error.statusCode == 503) {
      return CatalogUpdateFailureKind.unavailable;
    }
    return CatalogUpdateFailureKind.unknown;
  }
}
