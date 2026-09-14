import 'dart:async';

import '../../account/data/account_repository.dart';
import '../../collection/sync/sync_contract.dart';
import '../../collection/sync/sync_exceptions.dart';
import '../data/home_bar_sync_store.dart';
import 'home_bar_sync_contract.dart';

/// Offline-first sync for home-bar rows. It intentionally mirrors M8's
/// ownership and conflict rules while keeping its revision cursor separate.
final class HomeBarSyncEngine implements HomeBarSync {
  HomeBarSyncEngine({
    required HomeBarSyncApi api,
    required HomeBarSyncStore store,
    required AccountRepository account,
    DateTime Function()? now,
    this.debounce = const Duration(seconds: 2),
    void Function()? onSessionExpired,
  }) : _api = api,
       _store = store,
       _account = account,
       _now = now ?? DateTime.now,
       _onSessionExpired = onSessionExpired;

  final HomeBarSyncApi _api;
  final HomeBarSyncStore _store;
  final AccountRepository _account;
  final DateTime Function() _now;
  final Duration debounce;
  final void Function()? _onSessionExpired;

  SyncStatus _status = const SyncStatus(SyncPhase.idle);
  final _statusController = StreamController<SyncStatus>.broadcast();
  Future<void>? _inFlight;
  Timer? _debounceTimer;
  bool _trailingPassRequested = false;
  bool _closed = false;

  @override
  SyncStatus get status => _status;

  @override
  Stream<SyncStatus> watchStatus() async* {
    yield _status;
    yield* _statusController.stream;
  }

  void _setStatus(SyncPhase phase, {DateTime? lastSyncedAt}) {
    _status = SyncStatus(
      phase,
      lastSyncedAt: lastSyncedAt ?? _status.lastSyncedAt,
    );
    if (!_closed) _statusController.add(_status);
  }

  @override
  Future<void> syncNow() {
    final running = _inFlight;
    if (running != null) return running;
    final pass = _runPass();
    _inFlight = pass;
    _trackCompletion(pass);
    return pass;
  }

  @override
  void scheduleAfterLocalWrite() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounce, () {
      if (_closed) return;
      if (_inFlight != null) {
        // The active pass may already have captured an older snapshot. Run
        // once more after it finishes instead of joining it and forgetting
        // the local write that triggered this debounce.
        _trailingPassRequested = true;
        return;
      }
      unawaited(syncNow());
    });
  }

  @override
  Future<void> pushBeforeSignOut() async {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _trailingPassRequested = false;
    final running = _inFlight;
    if (running != null) {
      try {
        await running;
      } catch (_) {
        // A final best-effort push still has value after a failed full pass.
      }
    }
    final push = _finalPush();
    _inFlight = push;
    _trackCompletion(push);
    await push;
  }

  void _trackCompletion(Future<void> pass) {
    pass.whenComplete(() {
      if (!identical(_inFlight, pass)) return;
      _inFlight = null;
      if (_trailingPassRequested && !_closed) {
        _trailingPassRequested = false;
        unawaited(syncNow());
      }
    });
  }

  Future<void> _finalPush() async {
    try {
      await _push();
    } catch (_) {
      // Dirty rows remain durable for the next authenticated pass.
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
      await _store.setOwnerUserId(account.id);
    } else if (owner != account.id) {
      await _store.wipe();
      await _store.setOwnerUserId(account.id);
    }
  }

  Future<void> _push() async {
    final records = await _store.dirtyRecords();
    for (final record in records.where((record) => record.dirty)) {
      await _pushRecord(record.toRecord());
    }
  }

  Future<void> _pushRecord(HomeBarRecord sent, {bool retried = false}) async {
    final returned = await _api.putItem(sent);
    if (_appliesTo(sent, returned)) {
      // The person can edit this identity while the request is in flight.
      // Clear dirty only if the local row still is the snapshot we sent.
      await _store.applyPushResultIfUnchanged(sent: sent, returned: returned);
      return;
    }
    await _store.restamp(
      sent.ingredientId,
      sent.updatedAt.add(const Duration(milliseconds: 1)),
    );
    if (retried) return;
    final refreshed = await _store.localRecord(sent.ingredientId);
    if (refreshed == null || !refreshed.dirty) return;
    await _pushRecord(refreshed.toRecord(), retried: true);
  }

  /// A tie is successful only when every client-authoritative field agrees.
  /// A different equal-timestamp record belongs to another device, so the
  /// local record stays dirty, is re-stamped, and gets one immediate retry.
  bool _appliesTo(HomeBarRecord sent, HomeBarRecord returned) =>
      returned.updatedAt.isAfter(sent.updatedAt) ||
      (returned.updatedAt.isAtSameMomentAs(sent.updatedAt) &&
          returned.ingredientId == sent.ingredientId &&
          returned.displayName == sent.displayName &&
          returned.location == sent.location &&
          returned.deleted == sent.deleted);

  Future<void> _pull() async {
    var since = await _store.lastRevision();
    while (true) {
      final page = await _api.pull(since: since);
      for (final record in page.items) {
        await _applyPulledRecord(record);
      }
      // Cursor movement is deliberately after applying this page. The bar
      // counter is separate from collection entry revisions.
      since = page.revision;
      await _store.setLastRevision(since);
      if (!page.hasMore) return;
    }
  }

  Future<void> _applyPulledRecord(HomeBarRecord server) async {
    await _store.applyPulledRecordIfAllowed(server);
  }

  void dispose() {
    _closed = true;
    _debounceTimer?.cancel();
    unawaited(_statusController.close());
  }
}
