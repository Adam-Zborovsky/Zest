import 'dart:async';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:zest/features/catalog/application/catalog_providers.dart';
import 'package:zest/features/catalog/data/catalog_database.dart';
import 'package:zest/features/catalog/data/catalog_repository.dart';
import 'package:zest/features/catalog/data/catalog_snapshot_client.dart';

/// In-memory catalog database for widget/application tests.
CatalogDatabase openInMemoryCatalog() => CatalogDatabase(
  DatabaseConnection(
    NativeDatabase.memory(),
    closeStreamsSynchronously: true,
  ),
);

/// A queued, injectable stand-in for `CatalogSnapshotClient.fetch` — no test
/// touches the network through this fake. Responses are consumed FIFO;
/// `gateNextCall`/`release` let a test pause a fetch mid-flight to exercise
/// coalescing and stale-run protection deterministically.
final class FakeCatalogSnapshotFetcher {
  final requests = <String?>[];
  final _queue = <Future<CatalogSnapshotFetch> Function()>[];
  Completer<void>? _gate;

  void enqueueAvailable(CatalogSnapshotFetch fetch) =>
      _queue.add(() async => fetch);

  void enqueueError(Object error) => _queue.add(() => Future.error(error));

  /// Holds the *next* call open until [release] — lets a test observe the
  /// controller mid-run (e.g. `status == checking`/`downloading`) before it
  /// settles.
  Completer<void> gateNextCall() {
    final gate = Completer<void>();
    _gate = gate;
    return gate;
  }

  void release() {
    final gate = _gate;
    _gate = null;
    if (gate != null && !gate.isCompleted) gate.complete();
  }

  Future<CatalogSnapshotFetch> call({String? ifNoneMatchVersion}) async {
    requests.add(ifNoneMatchVersion);
    final gate = _gate;
    if (gate != null) await gate.future;
    if (_queue.isEmpty) {
      throw StateError(
        'FakeCatalogSnapshotFetcher: no queued response for call '
        '${requests.length}.',
      );
    }
    return _queue.removeAt(0)();
  }
}

/// Full provider overrides for catalog-backed application/widget tests: an
/// in-memory store and the fake snapshot fetcher. No test touches the
/// network through this wiring.
///
/// Typed `List<Override>`: Riverpod 3 does not export the `Override` type
/// name, so the list is dynamic and elements are checked when spread into a
/// `ProviderScope(overrides: [...])` literal.
List<dynamic> catalogTestOverrides({
  required CatalogDatabase database,
  required FakeCatalogSnapshotFetcher fetcher,
  DateTime Function()? now,
}) {
  final stamp = DateTime(2026, 9, 12, 10);
  return [
    catalogRepositoryProvider.overrideWithValue(
      CatalogRepository(database: database, now: now ?? () => stamp),
    ),
    catalogSnapshotFetcherProvider.overrideWithValue(fetcher.call),
    if (now != null) catalogNowProvider.overrideWithValue(now),
  ];
}
