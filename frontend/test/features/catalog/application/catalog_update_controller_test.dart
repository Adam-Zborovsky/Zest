import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zest/core/network/cocktail_api_exception.dart';
import 'package:zest/features/catalog/application/catalog_providers.dart';
import 'package:zest/features/catalog/application/catalog_update_controller.dart';
import 'package:zest/features/catalog/data/catalog_repository.dart';
import 'package:zest/features/catalog/data/catalog_snapshot_client.dart';
import 'package:zest/features/catalog/domain/catalog_update_state.dart';

import '../../../support/catalog_fixtures.dart';
import '../../../support/catalog_wiring.dart';

void main() {
  var clock = DateTime.utc(2026, 9, 14, 8);

  ({
    ProviderContainer container,
    CatalogRepository repository,
    FakeCatalogSnapshotFetcher fetcher,
  }) setup() {
    final database = openInMemoryCatalog();
    final repository = CatalogRepository(database: database, now: () => clock);
    final fetcher = FakeCatalogSnapshotFetcher();
    final container = ProviderContainer(
      overrides: [
        catalogRepositoryProvider.overrideWithValue(repository),
        catalogSnapshotFetcherProvider.overrideWithValue(fetcher.call),
        catalogNowProvider.overrideWithValue(() => clock),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(database.close);
    return (container: container, repository: repository, fetcher: fetcher);
  }

  setUp(() => clock = DateTime.utc(2026, 9, 14, 8));

  group('launch, empty catalog', () {
    test('downloads and applies automatically, silently (no notice)', () async {
      final test = setup();
      final snapshot = catalogSnapshotFixture(
        version: fakeCatalogVersion('first'),
        drinks: [catalogRecipeModel(id: '1', name: 'First Drink')],
      );
      test.fetcher.enqueueAvailable(CatalogSnapshotAvailable(snapshot));

      final notifier = test.container.read(catalogUpdateControllerProvider.notifier);
      await notifier.checkOnLaunch();

      final state = test.container.read(catalogUpdateControllerProvider);
      expect(state.status, CatalogUpdateStatus.updated);
      expect(state.diff!.added, 1);
      expect(state.silent, isTrue);
      expect(await test.repository.recipeCount(), 1);
      expect(test.fetcher.requests, [null]); // no local version to send
    });

    test('a failure surfaces as failed, with an empty catalog', () async {
      final test = setup();
      test.fetcher.enqueueError(
        const CocktailApiException(CocktailApiErrorKind.network),
      );

      await test.container.read(catalogUpdateControllerProvider.notifier).checkOnLaunch();

      final state = test.container.read(catalogUpdateControllerProvider);
      expect(state.status, CatalogUpdateStatus.failed);
      expect(state.failure, CatalogUpdateFailureKind.offline);
      expect(await test.repository.recipeCount(), 0);
    });

    test('checkOnLaunch only runs once per controller instance', () async {
      final test = setup();
      test.fetcher.enqueueAvailable(
        CatalogSnapshotAvailable(catalogSnapshotFixture()),
      );
      final notifier = test.container.read(catalogUpdateControllerProvider.notifier);
      await notifier.checkOnLaunch();
      await notifier.checkOnLaunch();
      expect(test.fetcher.requests, hasLength(1));
    });
  });

  group('launch, catalog already exists', () {
    test('a new version is downloaded and applied automatically, with a '
        'non-silent notice-worthy diff', () async {
      final test = setup();
      await test.repository.applySnapshot(
        catalogSnapshotFixture(
          version: fakeCatalogVersion('old'),
          drinks: [catalogRecipeModel(id: '1', name: 'Old Drink')],
        ),
      );
      test.fetcher.enqueueAvailable(
        CatalogSnapshotAvailable(
          catalogSnapshotFixture(
            version: fakeCatalogVersion('new'),
            drinks: [
              catalogRecipeModel(id: '1', name: 'Old Drink'),
              catalogRecipeModel(id: '2', name: 'New Drink'),
            ],
          ),
        ),
      );

      await test.container.read(catalogUpdateControllerProvider.notifier).checkOnLaunch();

      final state = test.container.read(catalogUpdateControllerProvider);
      expect(state.status, CatalogUpdateStatus.updated);
      expect(state.diff!.added, 1);
      expect(state.silent, isFalse);
      expect(test.fetcher.requests, [fakeCatalogVersion('old')]);
    });

    test('a 304 / identical version leaves state upToDate with no diff', () async {
      final test = setup();
      await test.repository.applySnapshot(
        catalogSnapshotFixture(version: fakeCatalogVersion('same')),
      );
      test.fetcher.enqueueAvailable(const CatalogSnapshotUnchanged());

      await test.container.read(catalogUpdateControllerProvider.notifier).checkOnLaunch();

      final state = test.container.read(catalogUpdateControllerProvider);
      expect(state.status, CatalogUpdateStatus.upToDate);
      expect(state.diff, isNull);
    });

    test('a failure with an existing catalog leaves the catalog untouched',
        () async {
      final test = setup();
      await test.repository.applySnapshot(
        catalogSnapshotFixture(
          version: fakeCatalogVersion('kept'),
          drinks: [catalogRecipeModel(id: '1')],
        ),
      );
      test.fetcher.enqueueError(
        const CocktailApiException(CocktailApiErrorKind.timeout),
      );

      await test.container.read(catalogUpdateControllerProvider.notifier).checkOnLaunch();

      final state = test.container.read(catalogUpdateControllerProvider);
      expect(state.status, CatalogUpdateStatus.failed);
      expect(state.failure, CatalogUpdateFailureKind.timeout);
      expect(await test.repository.recipeCount(), 1);
    });
  });

  group('resume', () {
    test('checked under 6 hours ago: does nothing', () async {
      final test = setup();
      test.fetcher.enqueueAvailable(const CatalogSnapshotUnchanged());
      final notifier = test.container.read(catalogUpdateControllerProvider.notifier);
      await notifier.checkOnLaunch(); // sets lastCheckedAt = clock

      clock = clock.add(const Duration(hours: 5));
      await notifier.checkAfterResume();

      expect(test.fetcher.requests, hasLength(1)); // no second call
    });

    test('checked 6+ hours ago with a new version: stages it, never applies '
        'it, and reports a non-silent diff', () async {
      final test = setup();
      await test.repository.applySnapshot(
        catalogSnapshotFixture(
          version: fakeCatalogVersion('resume-old'),
          drinks: [catalogRecipeModel(id: '1', name: 'Kept')],
        ),
      );
      test.fetcher.enqueueAvailable(const CatalogSnapshotUnchanged());
      final notifier = test.container.read(catalogUpdateControllerProvider.notifier);
      await notifier.checkOnLaunch();

      clock = clock.add(const Duration(hours: 7));
      test.fetcher.enqueueAvailable(
        CatalogSnapshotAvailable(
          catalogSnapshotFixture(
            version: fakeCatalogVersion('resume-new'),
            drinks: [
              catalogRecipeModel(id: '1', name: 'Kept'),
              catalogRecipeModel(id: '2', name: 'Staged Only'),
            ],
          ),
        ),
      );
      await notifier.checkAfterResume();

      final state = test.container.read(catalogUpdateControllerProvider);
      expect(state.status, CatalogUpdateStatus.staged);
      expect(state.diff!.added, 1);
      expect(state.silent, isFalse);
      // Not applied: the on-device catalog is unchanged.
      expect(await test.repository.recipeCount(), 1);

      await notifier.applyStaged();
      expect(await test.repository.recipeCount(), 2);
      final applied = test.container.read(catalogUpdateControllerProvider);
      expect(applied.status, CatalogUpdateStatus.updated);
      // Applying the staged update is its own feedback; no second notice.
      expect(applied.silent, isTrue);
    });

    test('applyStaged with nothing staged is a safe no-op', () async {
      final test = setup();
      await test.container.read(catalogUpdateControllerProvider.notifier).applyStaged();
      expect(
        test.container.read(catalogUpdateControllerProvider).status,
        CatalogUpdateStatus.idle,
      );
    });
  });

  group('manual checkNow', () {
    test('reports up to date', () async {
      final test = setup();
      await test.repository.applySnapshot(
        catalogSnapshotFixture(version: fakeCatalogVersion('v')),
      );
      test.fetcher.enqueueAvailable(const CatalogSnapshotUnchanged());

      final outcome =
          await test.container.read(catalogUpdateControllerProvider.notifier).checkNow();
      expect(outcome, isA<CatalogUpdateUpToDate>());
    });

    test('reports updated and applies immediately, never staging', () async {
      final test = setup();
      test.fetcher.enqueueAvailable(
        CatalogSnapshotAvailable(
          catalogSnapshotFixture(drinks: [catalogRecipeModel(id: '1')]),
        ),
      );

      final outcome =
          await test.container.read(catalogUpdateControllerProvider.notifier).checkNow();
      expect(outcome, isA<CatalogUpdateApplied>());
      expect(
        test.container.read(catalogUpdateControllerProvider).status,
        CatalogUpdateStatus.updated,
      );
    });

    test('reports failed', () async {
      final test = setup();
      test.fetcher.enqueueError(
        const CocktailApiException(CocktailApiErrorKind.invalidResponse),
      );
      final outcome =
          await test.container.read(catalogUpdateControllerProvider.notifier).checkNow();
      expect(outcome, isA<CatalogUpdateFailed>());
      expect(
        (outcome as CatalogUpdateFailed).kind,
        CatalogUpdateFailureKind.invalidResponse,
      );
    });
  });

  test('concurrent triggers coalesce into one run', () async {
    final test = setup();
    final gate = test.fetcher.gateNextCall();
    test.fetcher.enqueueAvailable(
      CatalogSnapshotAvailable(
        catalogSnapshotFixture(drinks: [catalogRecipeModel(id: '1')]),
      ),
    );
    final notifier = test.container.read(catalogUpdateControllerProvider.notifier);

    final first = notifier.checkNow();
    final second = notifier.checkNow(); // coalesces onto the same run
    gate.complete();
    final results = await Future.wait([first, second]);

    expect(results[0], isA<CatalogUpdateApplied>());
    expect(results[1], isA<CatalogUpdateApplied>());
    expect(test.fetcher.requests, hasLength(1)); // only one network call
  });

  test('a stale run abandoned by a rebuild never overwrites fresher state',
      () async {
    final database = openInMemoryCatalog();
    addTearDown(database.close);
    final repository = CatalogRepository(database: database, now: () => clock);
    final fetcherA = FakeCatalogSnapshotFetcher();
    final container = ProviderContainer(
      overrides: [
        catalogRepositoryProvider.overrideWithValue(repository),
        catalogNowProvider.overrideWithValue(() => clock),
        catalogSnapshotFetcherProvider.overrideWith((ref) {
          ref.watch(_rebuildTokenProvider);
          // A fresh closure each rebuild (unlike a bare tear-off, which
          // Dart would treat as `==` across rebuilds) so Riverpod actually
          // notifies `CatalogUpdateController.build()`'s watcher.
          return ({String? ifNoneMatchVersion}) =>
              fetcherA.call(ifNoneMatchVersion: ifNoneMatchVersion);
        }),
      ],
    );
    addTearDown(container.dispose);
    // An active listener so a dependency change (the rebuild token below)
    // propagates eagerly instead of merely marking the provider dirty for
    // a future read.
    container.listen(catalogUpdateControllerProvider, (_, __) {});

    final gate = fetcherA.gateNextCall();
    fetcherA.enqueueAvailable(
      CatalogSnapshotAvailable(
        catalogSnapshotFixture(
          version: fakeCatalogVersion('stale'),
          drinks: [catalogRecipeModel(id: '1', name: 'Stale Result')],
        ),
      ),
    );
    final notifier = container.read(catalogUpdateControllerProvider.notifier);
    final staleRun = notifier.checkNow();
    // Let the run reach and suspend at the gated fetch call.
    await Future<void>.delayed(Duration.zero);

    // Rebuild the controller (as happens when a watched dependency changes)
    // while the first run's fetch is still gated open. Riverpod schedules
    // dependent rebuilds on a microtask, so flush the event queue to let it
    // actually run before releasing the gate.
    container.read(_rebuildTokenProvider.notifier).bump();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    // The rebuild has already happened: the controller is back to idle even
    // though the superseded run is still suspended on the gate.
    expect(
      container.read(catalogUpdateControllerProvider).status,
      CatalogUpdateStatus.idle,
    );

    gate.complete();
    await staleRun;

    // The abandoned run's state write never landed: the freshly rebuilt
    // controller is back at its initial idle state, not "updated".
    expect(
      container.read(catalogUpdateControllerProvider).status,
      CatalogUpdateStatus.idle,
    );
    expect(await repository.recipeCount(), 0);
  });
}

final class _RebuildToken extends Notifier<int> {
  @override
  int build() => 0;
  void bump() => state++;
}

final _rebuildTokenProvider = NotifierProvider<_RebuildToken, int>(
  _RebuildToken.new,
);
