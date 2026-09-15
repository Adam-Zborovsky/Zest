import 'catalog_snapshot.dart';

/// How the shared-catalog update controller stands, per `docs/M11.md`
/// "Update behavior". `staged` means a new snapshot has been downloaded and
/// validated but not yet applied to the on-device store — the person must
/// tap **Update**, or it applies automatically at the next launch.
enum CatalogUpdateStatus {
  idle,
  checking,
  downloading,
  upToDate,
  updated,
  staged,
  failed,
}

/// Why a check or download failed. Mirrors (rather than wraps) the relevant
/// `CocktailApiErrorKind` values so the UI never needs to import the network
/// layer's exception type.
enum CatalogUpdateFailureKind {
  offline,
  timeout,
  unavailable,
  rateLimited,
  invalidResponse,
  unknown,
}

final class CatalogUpdateState {
  const CatalogUpdateState({
    this.status = CatalogUpdateStatus.idle,
    this.diff,
    this.failure,
    this.lastCheckedAt,
    this.silent = false,
  });

  final CatalogUpdateStatus status;

  /// Present when [status] is [CatalogUpdateStatus.updated] or
  /// [CatalogUpdateStatus.staged].
  final CatalogDiff? diff;

  /// Present when [status] is [CatalogUpdateStatus.failed].
  final CatalogUpdateFailureKind? failure;

  /// The last time a check completed (successfully or not), used for the
  /// "resumed after 6+ hours" rule and the profile-sheet status line.
  final DateTime? lastCheckedAt;

  /// True on the transition into [CatalogUpdateStatus.updated] that
  /// represents the very first automatic download onto an empty catalog —
  /// `docs/M11.md` never shows a notice for that case, only home-card
  /// progress. UI listeners should skip the update notice when this is true.
  final bool silent;
}

/// The one-shot result of a check, returned by
/// `CatalogUpdateController.checkNow()` for the profile sheet's own inline
/// wording — independent of the shared [CatalogUpdateState] stream.
sealed class CatalogUpdateOutcome {
  const CatalogUpdateOutcome();
}

final class CatalogUpdateUpToDate extends CatalogUpdateOutcome {
  const CatalogUpdateUpToDate();
}

final class CatalogUpdateApplied extends CatalogUpdateOutcome {
  const CatalogUpdateApplied(this.diff);
  final CatalogDiff diff;
}

final class CatalogUpdateStaged extends CatalogUpdateOutcome {
  const CatalogUpdateStaged(this.diff);
  final CatalogDiff diff;
}

final class CatalogUpdateFailed extends CatalogUpdateOutcome {
  const CatalogUpdateFailed(this.kind);
  final CatalogUpdateFailureKind kind;
}

/// Agreed wording for the *applied* update notice — stated in
/// `docs/M11.md`: "The diff wording only states counts it measured." Never
/// mentions counts that weren't part of the diff.
String catalogUpdateNoticeText(CatalogDiff diff) =>
    _diffNoticeText(diff, verb: 'updated');

/// Wording for a *staged* update notice (finding #7): a staged snapshot has
/// been downloaded and validated but not applied, so the copy must not
/// claim the catalog was already updated — it offers the **Update** action
/// instead.
String catalogUpdateStagedNoticeText(CatalogDiff diff) =>
    _diffNoticeText(diff, verb: 'update available');

String _diffNoticeText(CatalogDiff diff, {required String verb}) {
  if (diff.added > 0) {
    return 'Catalog $verb · ${diff.added} new '
        '${diff.added == 1 ? 'recipe' : 'recipes'}';
  }
  if (diff.changed > 0) {
    return 'Catalog $verb · ${diff.changed} '
        '${diff.changed == 1 ? 'recipe' : 'recipes'} changed';
  }
  if (diff.removed > 0) {
    return 'Catalog $verb · ${diff.removed} '
        '${diff.removed == 1 ? 'recipe' : 'recipes'} removed';
  }
  return 'Catalog $verb';
}
