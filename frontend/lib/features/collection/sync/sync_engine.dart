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
      final pushed = await _api.putEntry(record.toEntryRecord());
      await _store.applyServerRecord(pushed);
    }
    for (final record in dirty.where((r) => r.photoDirty && !r.deleted)) {
      final local = await _store.photoForSync(record.id);
      final EntryRecord result;
      if (local == null) {
        result = await _api.deletePhoto(record.id, updatedAt: record.updatedAt);
      } else {
        result = await _api.putPhoto(
          record.id,
          local.photo,
          updatedAt: local.updatedAt,
        );
      }
      // The photo bytes locally already match what was just pushed (or were
      // already absent); applyServerRecord only touches the entry row and
      // photoDirty, and leaves an existing local photo row untouched.
      await _store.applyServerRecord(result, clearPhotoDirty: true);
    }
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
