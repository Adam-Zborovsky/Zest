import 'package:zest/features/account/data/account_repository.dart';
import 'package:zest/features/collection/sync/sync_exceptions.dart';
import 'package:zest/features/home_bar/sync/home_bar_sync_contract.dart';

/// In-memory home-bar server for sync tests. It follows the backend's
/// per-user bar revision and restorable-tombstone rules.
final class FakeHomeBarSyncServer {
  final _users = <String, _UserRecords>{};
  final _revoked = <String>{};
  bool offline = false;

  HomeBarSyncApi client(AccountRepository account) => _FakeApi(this, account);
  void revoke(String userId) => _revoked.add(userId);

  _UserRecords _recordsFor(String userId) =>
      _users.putIfAbsent(userId, _UserRecords.new);
}

final class _UserRecords {
  int revision = 0;
  final items = <String, HomeBarRecord>{};
}

final class _FakeApi implements HomeBarSyncApi {
  _FakeApi(this._server, this._account);

  final FakeHomeBarSyncServer _server;
  final AccountRepository _account;

  Future<String> _authorize() async {
    if (_server.offline) throw const SyncOfflineException();
    final userId = _account.currentAccount?.id;
    if (userId == null || _server._revoked.contains(userId)) {
      await _account.expireSession();
      throw const SyncUnauthorizedException();
    }
    return userId;
  }

  @override
  Future<HomeBarSyncPage> pull({required int since, int limit = 200}) async {
    final records = _server._recordsFor(await _authorize());
    final matched =
        records.items.values
            .where((record) => record.revision! > since)
            .toList()
          ..sort((a, b) => a.revision!.compareTo(b.revision!));
    final page = matched.take(limit).toList();
    return HomeBarSyncPage(
      items: page,
      revision: page.isEmpty ? since : page.last.revision!,
      hasMore: matched.length > page.length,
    );
  }

  @override
  Future<HomeBarRecord> putItem(HomeBarRecord incoming) async {
    final records = _server._recordsFor(await _authorize());
    final existing = records.items[incoming.ingredientId];
    if (existing == null || incoming.updatedAt.isAfter(existing.updatedAt)) {
      records.revision++;
      final stored = HomeBarRecord(
        ingredientId: incoming.ingredientId,
        displayName: incoming.displayName,
        location: incoming.location,
        updatedAt: incoming.updatedAt,
        deleted: incoming.deleted,
        revision: records.revision,
      );
      records.items[incoming.ingredientId] = stored;
      return stored;
    }
    return existing;
  }
}
