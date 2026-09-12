import 'dart:async';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:zest/features/catalog/application/catalog_providers.dart';
import 'package:zest/features/catalog/data/catalog_database.dart';
import 'package:zest/features/catalog/data/catalog_repository.dart';
import 'package:zest/features/discovery/domain/recipe.dart';

import 'catalog_fixtures.dart';

/// In-memory catalog database for widget tests — the same wiring shape the
/// catalog application tests use, gathered here for presentation tests.
CatalogDatabase openInMemoryCatalog() => CatalogDatabase(
  DatabaseConnection(
    NativeDatabase.memory(),
    closeStreamsSynchronously: true,
  ),
);

/// Injectable letter source: answers from an invented per-letter map,
/// records every request in order, and throws one-shot failures before
/// answering. Gated letters hold their fetch open until explicitly
/// released, so tests can pause a run mid-flight deterministically.
final class FakeCatalogLetterSource {
  FakeCatalogLetterSource({
    required this.letters,
    Map<String, Object> failures = const {},
    this.gates = const {},
  }) : failures = Map.of(failures);

  final Map<String, List<Recipe>> letters;
  final Map<String, Object> failures;
  final Set<String> gates;
  final requests = <String>[];
  final _requested = <String, Completer<void>>{};
  final _release = <String, Completer<void>>{};

  Future<void> waitUntilRequested(String letter) =>
      _requested.putIfAbsent(letter, Completer<void>.new).future;

  void release(String letter) {
    final completer = _release.putIfAbsent(letter, Completer<void>.new);
    if (!completer.isCompleted) completer.complete();
  }

  Future<List<Recipe>> call(String letter) async {
    requests.add(letter);
    final requested = _requested.putIfAbsent(letter, Completer<void>.new);
    if (!requested.isCompleted) requested.complete();
    final failure = failures.remove(letter);
    if (failure != null) throw failure;
    if (gates.contains(letter)) {
      final released = _release.putIfAbsent(letter, Completer<void>.new);
      if (!released.isCompleted) await released.future;
    }
    return letters[letter] ?? const [];
  }
}

/// Full provider overrides for home/constellation widget tests: an in-memory
/// store, the fake letter source, and a zero letter gap so runs move at test
/// speed. No test touches the network through this wiring.
///
/// Typed `List<Override>`: Riverpod 3 does not export the `Override` type
/// name, so the list is dynamic and elements are checked when spread into a
/// `ProviderScope(overrides: [...])` literal — the same pattern the catalog
/// application tests use through plain literal lists.
List<dynamic> catalogTestOverrides({
  required CatalogDatabase database,
  required FakeCatalogLetterSource source,
  DateTime Function()? now,
}) {
  final stamp = DateTime(2026, 9, 12, 10);
  return [
    catalogRepositoryProvider.overrideWithValue(
      CatalogRepository(database: database, now: now ?? () => stamp),
    ),
    catalogLetterSourceProvider.overrideWithValue(source.call),
    catalogLetterGapProvider.overrideWithValue(Duration.zero),
  ];
}

/// Convenience: every letter answers with its synthetic fixture recipe, so
/// tests can sync the full alphabet instantly.
Map<String, List<Recipe>> everyCatalogLetter() => {
  for (final letter in 'abcdefghijklmnopqrstuvwxyz'.split(''))
    letter: catalogLetterRecipes(letter),
};
