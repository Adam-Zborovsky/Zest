import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zest/core/network/cocktail_api_exception.dart';
import 'package:zest/features/catalog/application/catalog_providers.dart';
import 'package:zest/features/catalog/data/catalog_database.dart';
import 'package:zest/features/catalog/data/catalog_repository.dart';
import 'package:zest/features/catalog/domain/sync_state.dart';
import 'package:zest/features/discovery/domain/recipe.dart';

import '../../../support/catalog_fixtures.dart';

/// Injectable letter source: answers from an invented per-letter map, records
/// every request in order, and throws one-shot failures before answering.
/// Gated letters hold their fetch open until explicitly released, so tests
/// can stop a run mid-fetch deterministically.
final class _FakeLetterSource {
  final Map<String, List<Recipe>> letters;
  final Map<String, Object> failures;
  final Set<String> gates;
  final requests = <String>[];
  final _requested = <String, Completer<void>>{};
  final _release = <String, Completer<void>>{};

  _FakeLetterSource({
    required this.letters,
    Map<String, Object> failures = const {},
    this.gates = const {},
  }) : failures = Map.of(failures);

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

void main() {
  final alphabet = 'abcdefghijklmnopqrstuvwxyz'.split('');
  final stamp = DateTime(2026, 9, 12, 10);

  /// In-memory store plus the full provider wiring with the fake source.
  ({
    ProviderContainer container,
    CatalogRepository repository,
    _FakeLetterSource source,
  }) setup({
    Map<String, List<Recipe>> letters = const {},
    Map<String, Object> failures = const {},
    Set<String> gates = const {},
  }) {
    final database = CatalogDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    final repository = CatalogRepository(database: database, now: () => stamp);
    final source = _FakeLetterSource(
      letters: letters,
      failures: failures,
      gates: gates,
    );
    final container = ProviderContainer(
      overrides: [
        catalogRepositoryProvider.overrideWithValue(repository),
        catalogLetterSourceProvider.overrideWithValue(source.call),
        catalogLetterGapProvider.overrideWithValue(Duration.zero),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(database.close);
    return (container: container, repository: repository, source: source);
  }

  Map<String, List<Recipe>> everyLetter() => {
    for (final letter in alphabet) letter: catalogLetterRecipes(letter),
  };

  CocktailApiException rateLimited(int seconds) => CocktailApiException(
    CocktailApiErrorKind.rateLimited,
    statusCode: 429,
    retryAfter: Duration(seconds: seconds),
    retryAt: stamp.add(Duration(seconds: seconds)),
  );

  test('a full run browses a–z in order and reports progress', () async {
    final test = setup(letters: everyLetter());
    final notifier = test.container.read(catalogSyncProvider.notifier);

    final states = <CatalogSyncState>[];
    test.container.listen(
      catalogSyncProvider,
      (_, next) => states.add(next),
      fireImmediately: true,
    );

    await notifier.start();

    final state = test.container.read(catalogSyncProvider);
    expect(state.status, CatalogSyncStatus.finished);
    expect(state.currentLetter, isNull);
    expect(state.lettersDone, 26);
    expect(state.recipesLoaded, 26);
    expect(test.source.requests, alphabet);

    final coverage = await test.repository.coverage();
    expect(coverage.lettersCompleted, 26);
    expect(coverage.recipeCount, 26);
    expect(coverage.isAtoZComplete, isTrue);

    // The engine reported each letter as it began; totals grow with progress.
    final syncingStates = states
        .where((s) => s.status == CatalogSyncStatus.syncing)
        .toList(growable: false);
    expect(syncingStates.first.currentLetter, 'a');
    expect(syncingStates.last.lettersDone, 26);
    for (var index = 1; index < syncingStates.length; index++) {
      expect(
        syncingStates[index].lettersDone,
        greaterThanOrEqualTo(syncingStates[index - 1].lettersDone),
      );
    }
  });

  test('an empty letter is a completed letter, not a failure', () async {
    final letters = everyLetter();
    letters['q'] = const [];
    final test = setup(letters: letters);

    await test.container.read(catalogSyncProvider.notifier).start();

    final state = test.container.read(catalogSyncProvider);
    expect(state.status, CatalogSyncStatus.finished);
    expect(state.lettersDone, 26);
    expect(state.recipesLoaded, 25);
    expect(test.source.requests, contains('q'));

    final statuses = await test.repository.letterStatuses();
    expect(statuses['q']!.recipeCount, 0);
    expect((await test.repository.coverage()).isAtoZComplete, isTrue);
  });

  test('a rate limit pauses with the countdown and never auto-retries',
      () async {
    final test = setup(
      letters: everyLetter(),
      failures: {'c': rateLimited(7)},
    );

    await test.container.read(catalogSyncProvider.notifier).start();

    final state = test.container.read(catalogSyncProvider);
    expect(state.status, CatalogSyncStatus.pausedCooldown);
    expect(state.secondsRemaining, 7);
    expect(state.retryAt, stamp.add(const Duration(seconds: 7)));
    expect(state.resumable, isTrue);
    expect(state.lettersDone, 2);
    expect(state.recipesLoaded, 2);
    expect(test.source.requests, ['a', 'b', 'c']);

    // No automatic retry loop: waiting changes nothing.
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(test.source.requests, ['a', 'b', 'c']);
  });

  test('resume after a cooldown pause continues from the pending letters',
      () async {
    final test = setup(
      letters: everyLetter(),
      failures: {'c': rateLimited(7)},
    );
    final notifier = test.container.read(catalogSyncProvider.notifier);

    await notifier.start();
    await notifier.resume();

    final state = test.container.read(catalogSyncProvider);
    expect(state.status, CatalogSyncStatus.finished);
    expect(state.lettersDone, 26);
    expect(state.recipesLoaded, 26);
    // a–b were never re-requested; c was retried once, d–z once each.
    expect(test.source.requests, ['a', 'b', 'c', ...alphabet.skip(2)]);
  });

  test('a second rate limit during resume re-pauses with the new countdown',
      () async {
    final test = setup(
      letters: everyLetter(),
      failures: {'c': rateLimited(7), 'd': rateLimited(3)},
    );
    final notifier = test.container.read(catalogSyncProvider.notifier);

    await notifier.start();
    await notifier.resume();
    expect(test.container.read(catalogSyncProvider).status,
        CatalogSyncStatus.pausedCooldown);
    expect(test.container.read(catalogSyncProvider).secondsRemaining, 3);
    expect(test.source.requests, ['a', 'b', 'c', 'c', 'd']);

    await notifier.resume();
    expect(test.container.read(catalogSyncProvider).status,
        CatalogSyncStatus.finished);
    expect(test.container.read(catalogSyncProvider).lettersDone, 26);
  });

  test('a network error pauses resumably and resume finishes the run',
      () async {
    final test = setup(
      letters: everyLetter(),
      failures: {
        'd': const CocktailApiException(CocktailApiErrorKind.network),
      },
    );
    final notifier = test.container.read(catalogSyncProvider.notifier);

    await notifier.start();

    final paused = test.container.read(catalogSyncProvider);
    expect(paused.status, CatalogSyncStatus.pausedError);
    expect(paused.error, isA<CocktailApiException>());
    expect(paused.resumable, isTrue);
    expect(paused.lettersDone, 3);
    expect(test.source.requests, ['a', 'b', 'c', 'd']);

    await notifier.resume();
    final state = test.container.read(catalogSyncProvider);
    expect(state.status, CatalogSyncStatus.finished);
    expect(state.lettersDone, 26);
  });

  test('a fully synced catalog finishes immediately without new requests',
      () async {
    final test = setup(letters: everyLetter());
    final notifier = test.container.read(catalogSyncProvider.notifier);

    await notifier.start();
    expect(test.source.requests, hasLength(26));

    await notifier.start();
    expect(test.source.requests, hasLength(26));
    expect(
      test.container.read(catalogSyncProvider).status,
      CatalogSyncStatus.finished,
    );
  });

  test('stop leaves the store consistent: applied letters stay, the pending '
      'one stays pending', () async {
    final test = setup(letters: everyLetter(), gates: {'c'});
    final notifier = test.container.read(catalogSyncProvider.notifier);

    final run = notifier.start();
    await test.source.waitUntilRequested('c');
    notifier.stop();
    test.source.release('c'); // The fetch resolves after the stop…
    await run;

    // …and the run must not apply it: a letter is fully applied or pending.
    expect(test.container.read(catalogSyncProvider).status,
        CatalogSyncStatus.idle);
    final statuses = await test.repository.letterStatuses();
    expect(statuses.keys, unorderedEquals(['a', 'b']));
    expect((await test.repository.pendingLetters()).first, 'c');
    expect(await test.repository.allRecipes(), hasLength(2));

    // A later start continues from the pending letters, c included.
    await notifier.start();
    expect(
      test.container.read(catalogSyncProvider).status,
      CatalogSyncStatus.finished,
    );
    expect(test.source.requests, ['a', 'b', 'c', ...alphabet.skip(2)]);
  });

  test('a fresh repository over the same database resumes from pending '
      'letters (restart acceptance)', () async {
    final scratch = await Directory.systemTemp.createTemp('zest_catalog_test');
    addTearDown(() => scratch.delete(recursive: true));
    final dbFile = File(
      '${scratch.path}${Platform.pathSeparator}catalog.sqlite',
    );

    // Session one: a–c sync, then d fails. The run pauses; the "app" ends.
    final dbOne = CatalogDatabase(NativeDatabase(dbFile));
    final repoOne = CatalogRepository(database: dbOne, now: () => stamp);
    final sourceOne = _FakeLetterSource(
      letters: everyLetter(),
      failures: {
        'd': const CocktailApiException(CocktailApiErrorKind.network),
      },
    );
    final containerOne = ProviderContainer(
      overrides: [
        catalogRepositoryProvider.overrideWithValue(repoOne),
        catalogLetterSourceProvider.overrideWithValue(sourceOne.call),
        catalogLetterGapProvider.overrideWithValue(Duration.zero),
      ],
    );
    await containerOne.read(catalogSyncProvider.notifier).start();
    expect(
      containerOne.read(catalogSyncProvider).status,
      CatalogSyncStatus.pausedError,
    );
    containerOne.dispose();
    await dbOne.close();

    // Session two: a brand-new store over the same persisted database.
    final dbTwo = CatalogDatabase(NativeDatabase(dbFile));
    addTearDown(dbTwo.close);
    final repoTwo = CatalogRepository(
      database: dbTwo,
      now: () => stamp.add(const Duration(hours: 1)),
    );
    final sourceTwo = _FakeLetterSource(letters: everyLetter());
    final containerTwo = ProviderContainer(
      overrides: [
        catalogRepositoryProvider.overrideWithValue(repoTwo),
        catalogLetterSourceProvider.overrideWithValue(sourceTwo.call),
        catalogLetterGapProvider.overrideWithValue(Duration.zero),
      ],
    );
    addTearDown(containerTwo.dispose);

    await containerTwo.read(catalogSyncProvider.notifier).start();

    // Only the pending letters were requested — no a–c restart.
    expect(sourceTwo.requests, alphabet.skip(3).toList());
    final state = containerTwo.read(catalogSyncProvider);
    expect(state.status, CatalogSyncStatus.finished);
    // Cumulative totals include the first session's letters.
    expect(state.lettersDone, 26);
    expect(state.recipesLoaded, 26);

    final coverage = await repoTwo.coverage();
    expect(coverage.lettersCompleted, 26);
    expect(coverage.recipeCount, 26);
    expect(coverage.isAtoZComplete, isTrue);
  });
}
