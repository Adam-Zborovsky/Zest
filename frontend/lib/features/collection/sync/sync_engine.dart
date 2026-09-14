import 'dart:async';

import '../../account/data/account_repository.dart';
import '../data/collection_sync_store.dart';
import 'sync_contract.dart';
import 'sync_exceptions.dart';

/// [CollectionSync] over one [SyncApi] and the local [CollectionSyncStore].
/// See `docs/ACCOUNTS.md` "Sync pass" and "Ownership" for the rules this
/// implements.
///
/// A pass: push dirty entries, push photo changes, pull pages until
/// `hasMore` is false (resolving conflicts by last-edit-wins and fetching
/// changed photos), then clear flags only for records the server applied.
/// Ownership is resolved before any push or pull. [syncNow] joins a pass
/// already running; local writes should call [scheduleAfterLocalWrite],
/// which debounces by [debounce] before running a pass.
final class SyncEngine implements CollectionSync {
  SyncEngine({
    required SyncApi api,
    required CollectionSyncStore store,
    required AccountRepository account,
    DateTime Function()? now,
    this.debounce = const Duration(seconds: 2),
    void Function()? onSessionExpired,
  }) : _api = api,
       _store = store,
       _account = account,
       _now = now ?? DateTime.now,
       _onSessionExpired = onSessionExpired;

  final SyncApi _api;
  final CollectionSyncStore _store;
  final AccountRepository _account;
  final DateTime Function() _now;
  final Duration debounce;
  final void Function()? _onSessionExpired;

  SyncStatus _status = const SyncStatus(SyncPhase.idle);
  final _statusController = StreamController<SyncStatus>.broadcast();
  Future<void>? _inFlight;
  Timer? _debounceTimer;
  bool _closed = false;

  @override
  SyncStatus get status => _status;

  @override
  Stream<SyncStatus> watchStatus() async* {
    yield _status;
    yield* _statusController.stream;
  }

  void _setStatus(SyncPhase phase, {DateTime? lastSyncedAt}) {
    _status = SyncStatus(phase, lastSyncedAt: lastSyncedAt ?? _status.lastSyncedAt);
    if (!_closed) _statusController.add(_status);
  }

  @override
  Future<void> syncNow() {
    final inFlight = _inFlight;
    if (inFlight != null) return inFlight;
    final future = _runPass();
    _inFlight = future;
    future.whenComplete(() {
      if (identical(_inFlight, future)) _inFlight = null;
    });
    return future;
  }

  /// Debounces a pass by [debounce] after a local write. Call from wherever
  /// the collection database is written.
  @override
  void scheduleAfterLocalWrite() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounce, () {
      unawaited(syncNow());
    });
  }

  /// One final push attempt on sign-out, before the account repository
  /// clears the session. Never throws; a failure is silently accepted, as
  /// the collection cache still keeps the unsynced local changes.
  ///
  /// Routed through the single-flight guard ([_inFlight]) rather than
  /// calling `_push()` directly: a debounced or already-running pass could
  /// otherwise race this final push, sending two concurrent requests, or
  /// (worse) finish after the caller clears the session token. This joins
  /// any pass already running, cancels the debounce timer so no further
  /// pass starts on its own, then runs one more push under the same guard
  /// so a concurrent `syncNow()`/`scheduleAfterLocalWrite()` call joins this
  /// push instead of racing it. The caller (`SessionController.signOut`)
  /// awaits this before clearing the token, so no request goes out after.
  @override
  Future<void> pushBeforeSignOut() async {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    final running = _inFlight;
    if (running != null) {
      try {
        await running;
      } catch (_) {
        // The prior pass's own failure handling already recorded status;
        // proceed to the final push regardless.
      }
    }
    final future = _finalPush();
    _inFlight = future;
    future.whenComplete(() {
      if (identical(_inFlight, future)) _inFlight = null;
    });
    await future;
  }

  Future<void> _finalPush() async {
    try {
      await _push();
    } catch (_) {
      // Best effort: the spec accepts the loss of this final push on
      // failure, since a fresh sign-in re-attempts the same dirty rows.
    }
  }

  Future<void> _runPass() async {
    if (_account.currentAccount == null) {
      _setStatus(SyncPhase.idle);
      return;
    }
    _setStatus(SyncPhase.syncing);
    try {
      await _resolveOwnership();
      await _push();
      await _pull();
      _setStatus(SyncPhase.idle, lastSyncedAt: _now());
    } on SyncUnauthorizedException {
      _onSessionExpired?.call();
      _setStatus(SyncPhase.failed);
    } on SyncOfflineException {
      _setStatus(SyncPhase.offline);
    } catch (_) {
      _setStatus(SyncPhase.failed);
    }
  }

  Future<void> _resolveOwnership() async {
    final account = _account.currentAccount;
    if (account == null) return;
    final owner = await _store.ownerUserId();
    if (owner == null) {
      // No owner yet: claim the device's existing data for this account and
      // upload it (every existing row is already dirty from creation or
      // from the schema 3 migration).
      await _store.setOwnerUserId(account.id);
    } else if (owner != account.id) {
      // A different account signed in on this device: wipe local data
      // first, then start this account's cache from scratch.
      await _store.wipe();
      await _store.setOwnerUserId(account.id);
    }
  }

  Future<void> _push() async {
    final dirty = await _store.dirtyRecords();
    for (final record in dirty.where((r) => r.dirty)) {
      await _pushEntry(record.toEntryRecord());
    }
    for (final record in dirty.where((r) => r.photoDirty && !r.deleted)) {
      await _pushPhoto(record);
    }
  }

  /// Pushes one entry body and resolves what the server sends back.
  ///
  /// The server's rule (`backend/src/accounts/repository.ts` `upsertEntry`,
  /// `docs/ACCOUNTS.md` sync rule 2) is: an incoming `updatedAt` strictly
  /// later than the stored one applies; an equal or earlier one is a no-op
  /// that returns the *stored* record unchanged. That stored record is not
  /// always this push: when two devices last synced the same `updatedAt`
  /// and both then stamp their independent edit at the same floored
  /// `previous + 1ms` (`DriftCollectionRepository._laterThan`), their pushes
  /// tie, and whichever pushes second gets back a foreign record — applying
  /// it unconditionally would adopt someone else's content and clear this
  /// device's own `dirty` flag, silently discarding the edit.
  ///
  /// So [returned] is only ever applied when it demonstrably reflects this
  /// push having taken effect:
  /// - **Server newer** (`returned.updatedAt` after [sent]'s): a genuine
  ///   later edit exists server-side; last-edit-wins says adopt it.
  /// - **Identical content at an equal timestamp:** this push applied, or
  ///   this is an idempotent retry of the same push. Apply it (to record
  ///   the new `revision`) and clear `dirty`.
  ///
  /// Anything else — an equal timestamp with different content, or (per the
  /// server contract, which should never happen) an *earlier* returned
  /// timestamp — means the server kept a different version: a rejected tie.
  /// The local row is re-stamped strictly later than what was sent and
  /// retried once in this same pass, so it is not left silently believing
  /// it is in sync with content the server does not have. A retry that
  /// still does not apply leaves the row dirty for the next pass, rather
  /// than looping.
  Future<void> _pushEntry(EntryRecord sent, {bool retried = false}) async {
    final returned = await _api.putEntry(sent);
    if (_appliesTo(sent, returned)) {
      await _store.applyServerRecord(returned);
      return;
    }
    final restamped = sent.updatedAt.add(const Duration(milliseconds: 1));
    await _store.restampEntry(sent.id, restamped);
    if (retried) return;
    final refreshed = await _store.localRecord(sent.id);
    if (refreshed == null) return;
    await _pushEntry(refreshed.toEntryRecord(), retried: true);
  }

  /// True when [returned] reflects [sent] having taken effect on the
  /// server: strictly newer (a real later edit exists), or an equal
  /// timestamp with identical content (this push applied, or an idempotent
  /// retry of it). See [_pushEntry] for the tie this distinguishes from.
  bool _appliesTo(EntryRecord sent, EntryRecord returned) {
    // Tombstones are final (docs/ACCOUNTS.md sync rule 3): once an entry is
    // deleted, the server returns the tombstone unconditionally, even for a
    // non-deleted PUT with a *later* `updatedAt` — deliberately breaking
    // last-edit-wins so a stale device cannot resurrect a deleted drink.
    // That is not the timestamp-tie bug this method otherwise guards
    // against, so a returned tombstone is always adopted regardless of how
    // its `updatedAt` compares to what was sent.
    if (returned.deleted) return true;
    if (returned.updatedAt.isAfter(sent.updatedAt)) return true;
    if (returned.updatedAt.isAtSameMomentAs(sent.updatedAt)) {
      return _deepEquals(sent.toJson(), returned.toJson());
    }
    return false;
  }

  /// The photo-push analogue of [_pushEntry], against the same server rule
  /// applied to `photoUpdatedAt` (`setEntryPhoto`/`clearEntryPhoto` in
  /// `backend/src/accounts/repository.ts`): a strictly later incoming
  /// `photoUpdatedAt` applies; an equal or earlier one no-ops and returns
  /// the stored record. The same unconditional-apply bug existed here: two
  /// devices setting or clearing a photo at a tied `photoUpdatedAt` could
  /// have the losing device adopt the winner's `hasPhoto` state and clear
  /// its own `photoDirty`, losing its photo change.
  ///
  /// There is no cheap way to compare photo *bytes* against what the server
  /// now holds, so "identical" here is approximated by whether the returned
  /// `hasPhoto` matches what this push intended (present for a set, absent
  /// for a delete) at a tied timestamp — true exactly when this device's
  /// own write is what the server applied or echoed back. A tie with the
  /// other `hasPhoto` value is unambiguously a foreign write and is
  /// rejected the same way as the entry path: re-stamp and retry once.
  Future<void> _pushPhoto(LocalSyncRecord record, {bool retried = false}) async {
    final local = await _store.photoForSync(record.id);
    final sentAt = local?.updatedAt ?? record.updatedAt;
    final intendedHasPhoto = local != null;
    final EntryRecord result;
    if (local == null) {
      result = await _api.deletePhoto(record.id, updatedAt: sentAt);
    } else {
      result = await _api.putPhoto(record.id, local.photo, updatedAt: sentAt);
    }
    final returnedAt = result.photoUpdatedAt;
    final applied =
        returnedAt != null &&
        (returnedAt.isAfter(sentAt) ||
            (returnedAt.isAtSameMomentAs(sentAt) &&
                result.hasPhoto == intendedHasPhoto));
    if (applied) {
      // The photo bytes locally already match what was just pushed (or were
      // already absent); applyServerRecord only touches the entry row and
      // photoDirty, and leaves an existing local photo row untouched.
      await _store.applyServerRecord(result, clearPhotoDirty: true);
      return;
    }
    final restamped = sentAt.add(const Duration(milliseconds: 1));
    if (local == null) {
      // A rejected photo-delete's timestamp is the entry's own `updatedAt`
      // (there is no local photo row to re-stamp).
      await _store.restampEntry(record.id, restamped);
    } else {
      await _store.restampPhoto(record.id, restamped);
    }
    if (retried) return;
    final refreshed = await _store.localRecord(record.id);
    if (refreshed == null || !refreshed.photoDirty) return;
    await _pushPhoto(refreshed, retried: true);
  }

  Future<void> _pull() async {
    var since = await _store.lastRevision();
    while (true) {
      final page = await _api.pull(since: since);
      for (final entry in page.entries) {
        await _applyPulledEntry(entry);
      }
      since = page.revision;
      await _store.setLastRevision(since);
      if (!page.hasMore) break;
    }
  }

  Future<void> _applyPulledEntry(EntryRecord entry) async {
    final local = await _store.localRecord(entry.id);
    // A dirty local row must never be silently overwritten (and its dirty
    // flag cleared) by a pulled record at an equal or earlier `updatedAt`:
    // an equal timestamp does not prove the server has seen this edit yet —
    // it may belong to a different device's write that happened to land on
    // the same millisecond, or (pre-M8-review-fix) the same second. Only a
    // pulled record strictly *newer* than a dirty local row may replace it;
    // a clean (already-synced) local row has nothing to lose, so the server
    // always wins for it, ties included.
    final serverWins =
        local == null || !local.dirty || local.updatedAt.isBefore(entry.updatedAt);
    if (!serverWins) {
      // The local edit is newer than, or tied with, the server's version and
      // still unpushed; keep it and let the next push resolve it.
      return;
    }
    await _store.applyServerRecord(entry);
    if (entry.hasPhoto) {
      final needsFetch =
          local == null ||
          !local.hasPhoto ||
          local.photoUpdatedAt == null ||
          entry.photoUpdatedAt == null ||
          !local.photoUpdatedAt!.isAtSameMomentAs(entry.photoUpdatedAt!);
      if (needsFetch) {
        final photo = await _api.getPhoto(entry.id);
        if (photo != null && entry.photoUpdatedAt != null) {
          await _store.setServerPhoto(entry.id, photo, entry.photoUpdatedAt!);
        }
      }
    }
  }

  void dispose() {
    _closed = true;
    _debounceTimer?.cancel();
    unawaited(_statusController.close());
  }
}

/// Structural equality over decoded JSON values (the nested `Map`/`List`
/// trees `EntryRecord.toJson()` produces), which `==` does not give `Map`
/// or `List` by default. Used to tell an idempotent push echo apart from a
/// foreign record that happens to share a timestamp.
bool _deepEquals(Object? a, Object? b) {
  if (identical(a, b)) return true;
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key) || !_deepEquals(a[key], b[key])) return false;
    }
    return true;
  }
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!_deepEquals(a[i], b[i])) return false;
    }
    return true;
  }
  return a == b;
}
