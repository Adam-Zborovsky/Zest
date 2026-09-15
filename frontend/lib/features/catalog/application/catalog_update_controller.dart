import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/cocktail_api_exception.dart';
import '../../constellation/application/constellation_providers.dart';
import '../../home_bar/application/home_bar_providers.dart';
import '../data/catalog_snapshot_client.dart';
import '../domain/catalog_snapshot.dart';
import '../domain/catalog_update_state.dart';
import 'catalog_providers.dart';

/// How long since the last attempted check (successful or failed) before an
/// app resume re-checks (`docs/M11.md` "Update behavior": "App resumed
/// after 6+ hours").
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

  /// The applied-snapshot version that was current at the moment
  /// [_stagedSnapshot] was staged. If the applied version has since moved on
  /// (a manual check or another apply landed first), the staged snapshot is
  /// stale and applying it would downgrade the catalog — see [applyStaged].
  String? _stagedBaseVersion;
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
    _stagedBaseVersion = null;
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
    final hadSnapshot = await _currentSnapshotSafely() != null;
    await _coalesced(() => _run0(stageOnly: false, silent: !hadSnapshot));
  }

  /// The profile sheet's "Check for catalog updates" row. Always applies a
  /// found update immediately (never stages), and its result is reported
  /// inline in the sheet via the returned outcome.
  Future<CatalogUpdateOutcome> checkNow() =>
      _coalesced(() => _run0(stageOnly: false));

  /// Called when the app is resumed. When there is no local catalog yet, a
  /// resume behaves like a launch and applies immediately — there is no
  /// session data to protect, and staging an update behind an empty state
  /// would just leave the person stuck looking at it. Otherwise, checks
  /// only when the last *attempted* check (successful or failed) was 6+
  /// hours ago, so a failed launch check does not force a re-check on every
  /// resume; when a new version exists it is downloaded and validated but
  /// **staged** rather than applied, so a person mid-session never has
  /// their data swapped under them.
  Future<void> checkAfterResume() async {
    final hasSnapshot = await _currentSnapshotSafely() != null;
    if (!hasSnapshot) {
      await _coalesced(() => _run0(stageOnly: false));
      return;
    }
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
  /// staged it was superseded, or nothing was ever staged), and also a
  /// no-op — discarding the stale staged snapshot — if the applied version
  /// has moved on since staging (an immediate apply always supersedes
  /// anything staged), so this can never downgrade the catalog.
  Future<void> applyStaged() =>
      _coalesced(() => _applyStaged());

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

  Future<CatalogUpdateOutcome> _applyStaged() async {
    final snapshot = _stagedSnapshot;
    if (snapshot == null) return const CatalogUpdateUpToDate();
    final run = ++_run;
    final repository = ref.read(catalogRepositoryProvider);

    CatalogSnapshotInfo? current;
    try {
      current = await repository.currentSnapshot();
    } catch (error) {
      return _landFailure(run, CatalogUpdateFailureKind.unknown);
    }
    if (current?.version != _stagedBaseVersion) {
      // Stale: something else applied since this was staged. Discard it
      // rather than risk downgrading the catalog.
      _stagedSnapshot = null;
      _stagedBaseVersion = null;
      return const CatalogUpdateUpToDate();
    }
    if (_run != run) return const CatalogUpdateUpToDate();

    CatalogDiff diff;
    try {
      diff = await repository.applySnapshot(snapshot);
    } catch (error) {
      return _landFailure(run, CatalogUpdateFailureKind.unknown);
    }
    _stagedSnapshot = null;
    _stagedBaseVersion = null;
    if (_run != run || !ref.mounted) return CatalogUpdateApplied(diff);
    // Silent: the notice's own Update action was the feedback; applying it
    // must not also pop the background-update notice on top of it.
    state = CatalogUpdateState(
      status: CatalogUpdateStatus.updated,
      diff: diff,
      lastCheckedAt: state.lastCheckedAt,
      silent: true,
    );
    _invalidateDerivedProviders();
    return CatalogUpdateApplied(diff);
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
    CatalogSnapshotInfo? current;
    try {
      current = await repository.currentSnapshot();
    } catch (error) {
      return _landFailure(run, CatalogUpdateFailureKind.unknown, now: now);
    }
    if (_run != run || !ref.mounted) return const CatalogUpdateUpToDate();
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
      return _landFailure(run, kind, now: now);
    } catch (error) {
      // Never let an unexpected error escape a fire-and-forget lifecycle
      // callback as an unhandled async exception — land it resumably, the
      // same way the old letter-sync engine treated non-gateway failures.
      return _landFailure(run, CatalogUpdateFailureKind.unknown, now: now);
    }
    if (_run != run || !ref.mounted) return const CatalogUpdateUpToDate();

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
      CatalogDiff diff;
      try {
        diff = await repository.previewDiff(snapshot);
      } catch (error) {
        return _landFailure(run, CatalogUpdateFailureKind.unknown, now: now);
      }
      if (_run != run || !ref.mounted) return CatalogUpdateStaged(diff);
      _stagedSnapshot = snapshot;
      _stagedBaseVersion = current?.version;
      state = CatalogUpdateState(
        status: CatalogUpdateStatus.staged,
        diff: diff,
        lastCheckedAt: now,
        silent: silent,
      );
      return CatalogUpdateStaged(diff);
    }

    CatalogDiff diff;
    try {
      diff = await repository.applySnapshot(snapshot);
    } catch (error) {
      return _landFailure(run, CatalogUpdateFailureKind.unknown, now: now);
    }
    // An immediate apply always supersedes anything staged: clear it so a
    // later "Update" tap can never re-apply a now-stale (or downgrading)
    // staged snapshot on top of this one.
    _stagedSnapshot = null;
    _stagedBaseVersion = null;
    if (_run != run || !ref.mounted) return CatalogUpdateApplied(diff);
    state = CatalogUpdateState(
      status: CatalogUpdateStatus.updated,
      diff: diff,
      lastCheckedAt: now,
      silent: silent,
    );
    _invalidateDerivedProviders();
    return CatalogUpdateApplied(diff);
  }

  /// Lands a `failed(kind)` state — unless a fresher run has already
  /// superseded this one — always recording `now` as the last *attempted*
  /// check time, per the 6h resume gate (finding #2): a failed check must
  /// not force a re-check on every subsequent resume.
  CatalogUpdateFailed _landFailure(
    int run,
    CatalogUpdateFailureKind kind, {
    DateTime? now,
  }) {
    if (_run != run || !ref.mounted) return CatalogUpdateFailed(kind);
    state = CatalogUpdateState(
      status: CatalogUpdateStatus.failed,
      failure: kind,
      lastCheckedAt: now ?? ref.read(catalogNowProvider)(),
    );
    return CatalogUpdateFailed(kind);
  }

  /// Best-effort existence check used only to decide behavior (never to
  /// report a result): a repository failure here is treated as "no local
  /// catalog", so [checkOnLaunch] and [checkAfterResume] fall through to
  /// the real, fully-guarded run in [_run0] instead of throwing out of a
  /// fire-and-forget lifecycle callback.
  Future<CatalogSnapshotInfo?> _currentSnapshotSafely() async {
    try {
      return await ref.read(catalogRepositoryProvider).currentSnapshot();
    } catch (error) {
      return null;
    }
  }

  /// Every provider whose data is derived from the on-device catalog, kept
  /// fresh here — directly, by the one place that actually changes the
  /// store — instead of relying on each screen to `ref.watch` a
  /// feature-local "freshness" provider before it arms (docs/M11.md finding
  /// #3): a cold deep link that never visits a given screen would otherwise
  /// never invalidate its providers.
  void _invalidateDerivedProviders() {
    ref.invalidate(catalogCoverageProvider);
    // Invalidating the shared decode also invalidates everything derived
    // from it (the search index and the id→Recipe map, finding #20) since
    // both `ref.watch` its `.future`.
    ref.invalidate(catalogRecipesProvider);
    ref.invalidate(constellationGraphProvider);
    ref.invalidate(homeBarCatalogRecipesProvider);
    ref.invalidate(homeBarCatalogCoverageProvider);
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
