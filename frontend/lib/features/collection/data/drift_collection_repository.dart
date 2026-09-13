import 'dart:convert';

import 'package:drift/drift.dart';

import '../../discovery/domain/recipe.dart';
import '../domain/collection_entry.dart';
import '../domain/memory_photo.dart';
import 'collection_database.dart';
import 'collection_repository.dart';

/// Drift-backed [CollectionRepository]. See the interface doc for the
/// invariants this implementation holds; the shared contract suite in
/// `test/support/collection_repository_contract.dart` checks them.
final class DriftCollectionRepository implements CollectionRepository {
  DriftCollectionRepository({
    required CollectionDatabase database,
    DateTime Function()? now,
    String Function()? newId,
  }) : _database = database,
       _now = now ?? DateTime.now,
       _newId = newId ?? newCollectionEntryId;

  final CollectionDatabase _database;
  final DateTime Function() _now;
  final String Function() _newId;

  SimpleSelectStatement<$EntriesTable, Entry> _ordered(
    Expression<bool> Function($EntriesTable t)? filter,
  ) {
    final query = _database.select(_database.entries);
    if (filter != null) query.where(filter);
    return query..orderBy([
      (t) => OrderingTerm.desc(t.day),
      (t) => OrderingTerm.desc(t.updatedAt),
      (t) => OrderingTerm.asc(t.id),
    ]);
  }

  @override
  Stream<List<CollectionEntry>> watchEntries() => _ordered(
    null,
  ).watch().map((rows) => List.unmodifiable(rows.map(_mapRow)));

  @override
  Stream<CollectionEntry?> watchEntry(String id) {
    final query = _database.select(_database.entries)
      ..where((t) => t.id.equals(id));
    return query.watchSingleOrNull().map(
      (row) => row == null ? null : _mapRow(row),
    );
  }

  @override
  Stream<List<CollectionEntry>> watchSavedEntriesFor(String sourceRecipeId) =>
      _ordered(
        (t) =>
            t.sourceRecipeId.equals(sourceRecipeId) &
            t.kind.equalsValue(CollectionEntryKind.saved),
      ).watch().map((rows) => List.unmodifiable(rows.map(_mapRow)));

  @override
  Future<CollectionEntry> saveRecipe(Recipe source) async {
    final now = _now();
    final id = _newId();
    await _database
        .into(_database.entries)
        .insert(
          EntriesCompanion.insert(
            id: id,
            kind: CollectionEntryKind.saved,
            sourceRecipeId: source.id,
            sourceJson: jsonEncode(source.toJson()),
            day: Value(collectionDayKey(collectionDay(now))),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return CollectionEntry.saved(
      id: id,
      source: source,
      day: now,
      createdAt: now,
      updatedAt: now,
    );
  }

  @override
  Future<CollectionEntry> createVariation(
    Recipe source,
    VariationDetails details,
  ) async {
    final now = _now();
    final id = _newId();
    await _database
        .into(_database.entries)
        .insert(
          EntriesCompanion.insert(
            id: id,
            kind: CollectionEntryKind.variation,
            sourceRecipeId: source.id,
            sourceJson: jsonEncode(source.toJson()),
            variationJson: Value(jsonEncode(details.toJson())),
            day: Value(collectionDayKey(collectionDay(now))),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return CollectionEntry.variation(
      id: id,
      source: source,
      details: details,
      day: now,
      createdAt: now,
      updatedAt: now,
    );
  }

  @override
  Future<CollectionEntry> updateVariation(String id, VariationDetails details) {
    return _database.transaction(() async {
      final row = await _entryRow(id);
      if (row == null) throw StateError('No collection entry $id.');
      if (row.kind != CollectionEntryKind.variation) {
        throw StateError('Collection entry $id is not a variation.');
      }
      await (_database.update(
        _database.entries,
      )..where((t) => t.id.equals(id))).write(
        EntriesCompanion(
          variationJson: Value(jsonEncode(details.toJson())),
          updatedAt: Value(_now()),
        ),
      );
      return _mapRow((await _entryRow(id))!);
    });
  }

  @override
  Future<CollectionEntry> moveToDay(String id, DateTime day) {
    return _database.transaction(() async {
      final row = await _entryRow(id);
      if (row == null) throw StateError('No collection entry $id.');
      await (_database.update(
        _database.entries,
      )..where((t) => t.id.equals(id))).write(
        EntriesCompanion(
          day: Value(collectionDayKey(collectionDay(day))),
          updatedAt: Value(_now()),
        ),
      );
      return _mapRow((await _entryRow(id))!);
    });
  }

  @override
  Future<void> delete(String id) {
    return _database.transaction(() async {
      await (_database.delete(
        _database.photos,
      )..where((t) => t.entryId.equals(id))).go();
      await (_database.delete(
        _database.entries,
      )..where((t) => t.id.equals(id))).go();
    });
  }

  @override
  Future<void> setPhoto(String id, MemoryPhoto photo) {
    return _database.transaction(() async {
      final row = await _entryRow(id);
      if (row == null) throw StateError('No collection entry $id.');
      final now = _now();
      await _database
          .into(_database.photos)
          .insertOnConflictUpdate(
            PhotosCompanion.insert(
              entryId: id,
              mimeType: photo.mimeType,
              bytes: photo.bytes,
              updatedAt: now,
            ),
          );
      await (_database.update(
        _database.entries,
      )..where((t) => t.id.equals(id))).write(
        EntriesCompanion(hasPhoto: const Value(true), updatedAt: Value(now)),
      );
    });
  }

  @override
  Future<void> removePhoto(String id) {
    return _database.transaction(() async {
      final deletedCount = await (_database.delete(
        _database.photos,
      )..where((t) => t.entryId.equals(id))).go();
      if (deletedCount == 0) return;
      await (_database.update(
        _database.entries,
      )..where((t) => t.id.equals(id))).write(
        EntriesCompanion(
          hasPhoto: const Value(false),
          updatedAt: Value(_now()),
        ),
      );
    });
  }

  @override
  Future<MemoryPhoto?> photo(String id) async {
    final row = await (_database.select(
      _database.photos,
    )..where((t) => t.entryId.equals(id))).getSingleOrNull();
    if (row == null) return null;
    return MemoryPhoto.fromBytes(row.bytes);
  }

  Future<Entry?> _entryRow(String id) => (_database.select(
    _database.entries,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Rehydrates a stored row into a [CollectionEntry]. The source snapshot,
  /// the day, and for a variation the variation details are parsed here;
  /// malformed stored data throws a clear [FormatException] naming the entry
  /// instead of surfacing as a silently empty or misdated entry.
  CollectionEntry _mapRow(Entry row) {
    final Recipe source;
    try {
      source = Recipe.fromJson(
        jsonDecode(row.sourceJson) as Map<String, dynamic>,
      );
    } catch (error) {
      throw FormatException(
        'Malformed source snapshot for collection entry ${row.id}: $error',
      );
    }
    final DateTime day;
    try {
      day = parseCollectionDayKey(row.day);
    } on FormatException catch (error) {
      throw FormatException(
        'Malformed day for collection entry ${row.id}: ${error.message}',
      );
    }
    switch (row.kind) {
      case CollectionEntryKind.saved:
        return CollectionEntry.saved(
          id: row.id,
          source: source,
          day: day,
          createdAt: row.createdAt,
          updatedAt: row.updatedAt,
          hasPhoto: row.hasPhoto,
        );
      case CollectionEntryKind.variation:
        final variationJson = row.variationJson;
        if (variationJson == null) {
          throw FormatException(
            'Collection entry ${row.id} is a variation with no variation '
            'details.',
          );
        }
        final VariationDetails details;
        try {
          details = VariationDetails.fromJson(
            jsonDecode(variationJson) as Map<String, dynamic>,
          );
        } catch (error) {
          throw FormatException(
            'Malformed variation details for collection entry ${row.id}: '
            '$error',
          );
        }
        return CollectionEntry.variation(
          id: row.id,
          source: source,
          details: details,
          day: day,
          createdAt: row.createdAt,
          updatedAt: row.updatedAt,
          hasPhoto: row.hasPhoto,
        );
    }
  }
}
