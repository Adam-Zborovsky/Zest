import 'dart:async';
import 'dart:typed_data';

import 'package:zest/features/collection/data/collection_repository.dart';
import 'package:zest/features/collection/data/memory_photo_picker.dart';
import 'package:zest/features/collection/domain/collection_entry.dart';
import 'package:zest/features/collection/domain/memory_photo.dart';
import 'package:zest/features/discovery/domain/recipe.dart';

/// A synchronous-feeling in-memory [CollectionRepository] for widget tests.
/// It holds the same invariants as the drift implementation and runs the
/// shared contract suite, so screens tested against it behave the same way
/// against the real store.
final class InMemoryCollectionRepository implements CollectionRepository {
  InMemoryCollectionRepository({DateTime Function()? now, this.nextId})
    : _now = now ?? DateTime.now;

  final DateTime Function() _now;

  /// Optional deterministic id source for tests.
  final String Function()? nextId;

  final _entries = <String, CollectionEntry>{};
  final _photos = <String, MemoryPhoto>{};
  final _changes = StreamController<void>.broadcast();

  String _id() => nextId?.call() ?? newCollectionEntryId();

  List<CollectionEntry> _sorted([bool Function(CollectionEntry)? where]) =>
      (where == null ? _entries.values : _entries.values.where(where)).toList()
        ..sort(compareCollectionEntries);

  Stream<T> _watch<T>(T Function() read) async* {
    yield read();
    yield* _changes.stream.map((_) => read());
  }

  void _changed() => _changes.add(null);

  @override
  Stream<List<CollectionEntry>> watchEntries() => _watch(_sorted);

  @override
  Stream<CollectionEntry?> watchEntry(String id) => _watch(() => _entries[id]);

  @override
  Stream<List<CollectionEntry>> watchSavedEntriesFor(String sourceRecipeId) =>
      _watch(
        () => _sorted(
          (entry) =>
              !entry.isVariation && entry.sourceRecipeId == sourceRecipeId,
        ),
      );

  @override
  Future<CollectionEntry> saveRecipe(Recipe source) async {
    final now = _now();
    final entry = CollectionEntry.saved(
      id: _id(),
      source: Recipe.fromJson(source.toJson()),
      day: now,
      createdAt: now,
    );
    _entries[entry.id] = entry;
    _changed();
    return entry;
  }

  @override
  Future<CollectionEntry> createVariation(
    Recipe source,
    VariationDetails details,
  ) async {
    final now = _now();
    final entry = CollectionEntry.variation(
      id: _id(),
      source: Recipe.fromJson(source.toJson()),
      details: details,
      day: now,
      createdAt: now,
    );
    _entries[entry.id] = entry;
    _changed();
    return entry;
  }

  @override
  Future<CollectionEntry> moveToDay(String id, DateTime day) async {
    final entry = _entries[id];
    if (entry == null) throw StateError('No collection entry $id.');
    final moved = entry.copyWith(day: day, updatedAt: _now());
    _entries[id] = moved;
    _changed();
    return moved;
  }

  @override
  Future<CollectionEntry> updateVariation(
    String id,
    VariationDetails details,
  ) async {
    final entry = _entries[id];
    if (entry == null) throw StateError('No collection entry $id.');
    if (!entry.isVariation) {
      throw StateError('Collection entry $id is not a variation.');
    }
    final updated = entry.copyWith(variation: details, updatedAt: _now());
    _entries[id] = updated;
    _changed();
    return updated;
  }

  @override
  Future<void> delete(String id) async {
    if (_entries.remove(id) == null) return;
    _photos.remove(id);
    _changed();
  }

  @override
  Future<void> setPhoto(String id, MemoryPhoto photo) async {
    final entry = _entries[id];
    if (entry == null) throw StateError('No collection entry $id.');
    _photos[id] = photo;
    _entries[id] = entry.copyWith(hasPhoto: true, updatedAt: _now());
    _changed();
  }

  @override
  Future<void> removePhoto(String id) async {
    final entry = _entries[id];
    if (entry == null || _photos.remove(id) == null) return;
    _entries[id] = entry.copyWith(hasPhoto: false, updatedAt: _now());
    _changed();
  }

  @override
  Future<MemoryPhoto?> photo(String id) async => _photos[id];

  Future<void> dispose() => _changes.close();
}

/// A scripted [MemoryPhotoPicker]: returns [next] (null means the person
/// cancelled) or throws [error], and records every request.
final class FakeMemoryPhotoPicker implements MemoryPhotoPicker {
  FakeMemoryPhotoPicker({this.next, this.error, this.supportsCamera = true});

  MemoryPhoto? next;
  Object? error;

  @override
  bool supportsCamera;

  final requests = <PhotoSource>[];

  @override
  Future<MemoryPhoto?> pick(PhotoSource source) async {
    requests.add(source);
    final failure = error;
    if (failure != null) throw failure;
    return next;
  }
}

/// A tiny synthetic PNG signature plus padding: enough for content sniffing.
/// It is not a decodable picture; widget tests that render the image should
/// use [validTinyPng].
MemoryPhoto syntheticPngPhoto() => MemoryPhoto.fromBytes(
  Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0]),
);

/// A valid, decodable 2×2 RGB PNG in grapefruit and leaf (synthetic, not a
/// personal photo). Generated with correct IHDR/IDAT/IEND CRCs and a zlib
/// stream; an earlier hand-typed 1×1 version failed to decode.
MemoryPhoto validTinyPng() => MemoryPhoto.fromBytes(
  Uint8List.fromList(const [
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
    0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00, 0x02, //
    0x08, 0x02, 0x00, 0x00, 0x00, 0xFD, 0xD4, 0x9A, 0x73, 0x00, 0x00, 0x00, //
    0x16, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0xF8, 0xB9, 0xB4, 0x47, //
    0xD2, 0xDE, 0x88, 0x41, 0xD2, 0xDE, 0xE8, 0xE7, 0xD2, 0x1E, 0x00, 0x26, //
    0x8E, 0x05, 0x69, 0x21, 0xB6, 0x55, 0x82, 0x00, 0x00, 0x00, 0x00, 0x49, //
    0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82, //
  ]),
);
