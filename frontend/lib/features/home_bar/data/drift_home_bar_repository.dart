import 'package:drift/drift.dart';

import '../../collection/data/collection_database.dart';
import '../domain/home_bar_item.dart';
import '../sync/home_bar_sync_contract.dart';
import 'home_bar_repository.dart';
import 'home_bar_sync_store.dart';

/// Drift-backed home-bar state within the existing account-owned collection
/// database. A distinct table and cursor keep this stream independent from
/// collection entry sync while retaining one database lifecycle.
final class DriftHomeBarRepository
    implements HomeBarRepository, HomeBarSyncStore {
  DriftHomeBarRepository({
    required CollectionDatabase database,
    DateTime Function()? now,
  }) : _database = database,
       _now = now ?? DateTime.now;

  final CollectionDatabase _database;
  final DateTime Function() _now;

  DateTime _laterThan(DateTime? previous) {
    final now = _now();
    if (previous == null) return now;
    final floor = previous.add(const Duration(milliseconds: 1));
    return now.isAfter(floor) ? now : floor;
  }

  @override
  Stream<List<HomeBarItem>> watchItems() {
    final query = _database.select(_database.homeBarItems)
      ..where((item) => item.deleted.equals(false))
      ..orderBy([
        (item) => OrderingTerm.asc(item.displayName),
        (item) => OrderingTerm.asc(item.ingredientId),
      ]);
    return query.watch().map((rows) => List.unmodifiable(rows.map(_mapRow)));
  }

  @override
  Future<HomeBarItem> addToBar(String displayName) =>
      _put(displayName, HomeBarLocation.stocked);

  @override
  Future<HomeBarItem> addToShopping(String displayName) =>
      _put(displayName, HomeBarLocation.shopping);

  Future<HomeBarItem> _put(String displayName, HomeBarLocation location) {
    final cleanedName = _cleanDisplayName(displayName);
    final id = HomeBarItem.normalizeIngredientId(cleanedName);
    return _database.transaction(() async {
      final existing = await _row(id);
      // Adding an existing live item to its current location is idempotent:
      // do not create a needless local write or steal the user's saved
      // display spelling merely because the catalog renders it differently.
      if (existing != null &&
          !existing.deleted &&
          existing.location == location.name) {
        return _mapRow(existing);
      }
      final stamp = _laterThan(existing?.updatedAt);
      await _database
          .into(_database.homeBarItems)
          .insertOnConflictUpdate(
            HomeBarItemsCompanion.insert(
              ingredientId: id,
              displayName: cleanedName,
              location: location.name,
              updatedAt: stamp,
              deleted: const Value(false),
              dirty: const Value(true),
            ),
          );
      return _mapRow((await _row(id))!);
    });
  }

  @override
  Future<void> remove(String ingredientId) async {
    final id = HomeBarItem.normalizeIngredientId(ingredientId);
    await _database.transaction(() async {
      final existing = await _row(id);
      if (existing == null || existing.deleted) return;
      await (_database.update(
        _database.homeBarItems,
      )..where((item) => item.ingredientId.equals(id))).write(
        HomeBarItemsCompanion(
          updatedAt: Value(_laterThan(existing.updatedAt)),
          deleted: const Value(true),
          dirty: const Value(true),
        ),
      );
    });
  }

  String _cleanDisplayName(String value) {
    final result = value.trim();
    if (result.isEmpty || result.length > HomeBarItem.maxTextLength) {
      throw ArgumentError.value(
        value,
        'displayName',
        'Must contain 1 to ${HomeBarItem.maxTextLength} UTF-16 code units.',
      );
    }
    if (RegExp(r'[\u0000-\u001F\u007F]').hasMatch(value)) {
      throw ArgumentError.value(
        value,
        'displayName',
        'Must not contain control characters.',
      );
    }
    final identity = HomeBarItem.normalizeIngredientId(result);
    if (identity.length > HomeBarItem.maxTextLength) {
      throw ArgumentError.value(
        value,
        'displayName',
        'Its normalized identity exceeds ${HomeBarItem.maxTextLength} UTF-16 code units.',
      );
    }
    return result;
  }

  HomeBarItem _mapRow(HomeBarItemRow row) => HomeBarItem(
    ingredientId: row.ingredientId,
    displayName: row.displayName,
    location: HomeBarLocation.values.byName(row.location),
    updatedAt: row.updatedAt,
    deleted: row.deleted,
  );

  Future<HomeBarItemRow?> _row(String ingredientId) => (_database.select(
    _database.homeBarItems,
  )..where((item) => item.ingredientId.equals(ingredientId))).getSingleOrNull();

  @override
  Future<List<LocalHomeBarRecord>> dirtyRecords() async {
    final rows =
        await (_database.select(_database.homeBarItems)
              ..where((item) => item.dirty.equals(true))
              ..orderBy([(item) => OrderingTerm.asc(item.ingredientId)]))
            .get();
    return List.unmodifiable([
      for (final row in rows)
        LocalHomeBarRecord(item: _mapRow(row), dirty: row.dirty),
    ]);
  }

  @override
  Future<LocalHomeBarRecord?> localRecord(String ingredientId) async {
    final row = await _row(ingredientId);
    return row == null
        ? null
        : LocalHomeBarRecord(item: _mapRow(row), dirty: row.dirty);
  }

  @override
  Future<bool> applyPushResultIfUnchanged({
    required HomeBarRecord sent,
    required HomeBarRecord returned,
  }) {
    return _database.transaction(() async {
      final current = await _row(sent.ingredientId);
      if (current == null || !current.dirty || !_matches(current, sent)) {
        return false;
      }
      await _writeServerRecord(returned);
      return true;
    });
  }

  @override
  Future<bool> applyPulledRecordIfAllowed(HomeBarRecord record) {
    return _database.transaction(() async {
      final current = await _row(record.ingredientId);
      if (current != null &&
          current.dirty &&
          !current.updatedAt.isBefore(record.updatedAt)) {
        return false;
      }
      await _writeServerRecord(record);
      return true;
    });
  }

  bool _matches(HomeBarItemRow row, HomeBarRecord record) =>
      row.ingredientId == record.ingredientId &&
      row.displayName == record.displayName &&
      row.location == record.location.name &&
      row.updatedAt.isAtSameMomentAs(record.updatedAt) &&
      row.deleted == record.deleted;

  Future<void> _writeServerRecord(HomeBarRecord record) => _database
      .into(_database.homeBarItems)
      .insertOnConflictUpdate(
        HomeBarItemsCompanion.insert(
          ingredientId: record.ingredientId,
          displayName: record.displayName,
          location: record.location.name,
          updatedAt: record.updatedAt,
          deleted: Value(record.deleted),
          dirty: const Value(false),
        ),
      );

  @override
  Future<void> restamp(String ingredientId, DateTime updatedAt) async {
    final row = await _row(ingredientId);
    if (row == null) return;
    final next = updatedAt.isAfter(row.updatedAt)
        ? updatedAt
        : row.updatedAt.add(const Duration(milliseconds: 1));
    await (_database.update(
      _database.homeBarItems,
    )..where((item) => item.ingredientId.equals(ingredientId))).write(
      HomeBarItemsCompanion(updatedAt: Value(next), dirty: const Value(true)),
    );
  }

  Future<HomeBarSyncStateData> _syncStateRow() async {
    final existing = await (_database.select(
      _database.homeBarSyncState,
    )..where((state) => state.id.equals(0))).getSingleOrNull();
    if (existing != null) return existing;
    await _database
        .into(_database.homeBarSyncState)
        .insertOnConflictUpdate(const HomeBarSyncStateCompanion(id: Value(0)));
    return (_database.select(
      _database.homeBarSyncState,
    )..where((state) => state.id.equals(0))).getSingle();
  }

  @override
  Future<String?> ownerUserId() async => (await _syncStateRow()).ownerUserId;

  @override
  Future<void> setOwnerUserId(String? userId) async {
    await _syncStateRow();
    await (_database.update(_database.homeBarSyncState)
          ..where((state) => state.id.equals(0)))
        .write(HomeBarSyncStateCompanion(ownerUserId: Value(userId)));
  }

  @override
  Future<int> lastRevision() async => (await _syncStateRow()).lastRevision;

  @override
  Future<void> setLastRevision(int revision) async {
    await _syncStateRow();
    await (_database.update(_database.homeBarSyncState)
          ..where((state) => state.id.equals(0)))
        .write(HomeBarSyncStateCompanion(lastRevision: Value(revision)));
  }

  @override
  Future<void> wipe() {
    return _database.transaction(() async {
      await _database.delete(_database.homeBarItems).go();
      await _syncStateRow();
      await (_database.update(_database.homeBarSyncState)
            ..where((state) => state.id.equals(0)))
          .write(const HomeBarSyncStateCompanion(lastRevision: Value(0)));
    });
  }
}
