import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zest/core/network/cocktail_api_exception.dart';
import 'package:zest/features/bar/application/bar_providers.dart';
import 'package:zest/features/bar/domain/bar_match.dart';
import 'package:zest/features/bar/domain/recipe_scope.dart';
import 'package:zest/features/discovery/application/discovery_providers.dart';
import 'package:zest/features/discovery/data/cocktail_db_client.dart';
import 'package:zest/features/discovery/domain/recipe.dart';

import '../../../support/discovery_fixtures.dart';

RecipeSummary summary(String id, String name) =>
    RecipeSummary.fromJson(discoverySummary({'idDrink': id, 'strDrink': name}));

/// Lookups answer with a synthetic recipe whose essentials depend on [id]:
/// 1 ready, 2 substitution, 3 missing, 4 garnish-only extra.
http.Response lookupResponse(String id) {
  final (String, String?) extra;
  final number = int.parse(id) % 4;
  if (number == 0) {
    extra = ('Nutmeg', null);
  } else if (number == 1) {
    extra = ('Fresh Lime Juice', '1 oz');
  } else if (number == 2) {
    extra = ('Unlisted bitters', '2 dashes');
  } else {
    extra = ('Pretend lime juice', '1 oz');
  }
  return http.Response(
    jsonEncode({
      'drinks': [
        {
          'idDrink': id,
          'strDrink': 'Testbench ${id.hashCode % 100}',
          'strInstructions': 'Invented steps only.',
          'strIngredient1': 'Imaginary gin',
          'strMeasure1': '2 oz',
          'strIngredient2': extra.$1,
          'strMeasure2': extra.$2,
        },
      ],
    }),
    200,
  );
}

void main() {
  ({ProviderContainer container, List<Uri> requests}) setup({
    required Future<http.Response> Function(http.Request) respond,
    DateTime Function()? now,
  }) {
    final requests = <Uri>[];
    final transport = MockClient((request) async {
      requests.add(request.url);
      return respond(request);
    });
    final client = CocktailDbClient(client: transport);
    final container = ProviderContainer(
      overrides: [
        cocktailDbClientProvider.overrideWithValue(client),
        if (now != null) nowProvider.overrideWithValue(now),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(client.close);
    addTearDown(transport.close);
    return (container: container, requests: requests);
  }

  RecipeScope scope(int count) => RecipeScope(
    label: 'Recipes for “test”',
    recipes: [
      for (var id = 1; id <= count; id++)
        summary('$id', 'Testbench $id'),
    ],
  );

  test('starting without a scope or selection leaves the run idle', () async {
    final test = setup(respond: (_) async => lookupResponse('1'));
    final notifier = test.container.read(barMatchProvider.notifier);
    await notifier.start();
    expect(test.container.read(barMatchProvider).status, BarMatchStatus.idle);

    test.container.read(recipeScopeProvider.notifier).setScope(scope(2));
    await notifier.start();
    expect(test.container.read(barMatchProvider).status, BarMatchStatus.idle);
    expect(test.requests, isEmpty);
  });

  test('a full run checks every recipe and classifies the three buckets', () async {
    final test = setup(respond: (request) async => lookupResponse(
      request.url.queryParameters['i']!,
    ));
    test.container.read(recipeScopeProvider.notifier).setScope(scope(24));
    final selection = test.container.read(barSelectionProvider.notifier);
    selection.toggle('Imaginary gin');
    selection.toggle('Pretend lime juice');
    selection.toggle('Lime juice');

    final statuses = <BarMatchStatus>[];
    test.container.listen(barMatchProvider, (_, next) {
      if (!statuses.contains(next.status)) statuses.add(next.status);
    }, fireImmediately: true);

    await test.container.read(barMatchProvider.notifier).start();

    final state = test.container.read(barMatchProvider);
    expect(state.status, BarMatchStatus.done);
    expect(state.checked, 24);
    expect(state.total, 24);
    expect(state.unavailable, 0);
    expect(state.matches, hasLength(24));
    expect(statuses, [BarMatchStatus.idle, BarMatchStatus.running, BarMatchStatus.done]);
    // 24 ids: numbers 1..24 spread over the four fixture shapes.
    expect(
      state.matches
          .where((match) => match.category == BarMatchCategory.ready)
          .length,
      12,
    );
    expect(
      state.matches
          .where((match) => match.category == BarMatchCategory.substitution)
          .length,
      6,
    );
    expect(
      state.matches
          .where((match) => match.category == BarMatchCategory.missingEssentials)
          .length,
      6,
    );
    expect(test.requests, hasLength(24));
  });

  test('lookups that miss still count as checked and reported unavailable', () async {
    final test = setup(
      respond: (request) async =>
          request.url.queryParameters['i'] == '3'
              ? http.Response(jsonEncode({'drinks': null}), 200)
              : lookupResponse(request.url.queryParameters['i']!),
    );
    test.container.read(recipeScopeProvider.notifier).setScope(scope(3));
    test.container
        .read(barSelectionProvider.notifier)
        .toggle('Imaginary gin');

    await test.container.read(barMatchProvider.notifier).start();

    final state = test.container.read(barMatchProvider);
    expect(state.status, BarMatchStatus.done);
    expect(state.checked, 3);
    expect(state.unavailable, 1);
    expect(state.matches, hasLength(2));
  });

  test('a rate limit pauses the run and keeps partial matches for resume', () async {
    var clock = DateTime.utc(2026, 9, 12);
    var limited = false;
    final test = setup(
      now: () => clock,
      respond: (request) async {
        final id = int.parse(request.url.queryParameters['i']!);
        if (id == 21 && !limited) {
          limited = true;
          return http.Response('', 429, headers: {'retry-after': '2'});
        }
        return lookupResponse(request.url.queryParameters['i']!);
      },
    );
    test.container.read(recipeScopeProvider.notifier).setScope(scope(25));
    test.container.read(barSelectionProvider.notifier).toggle('Imaginary gin');

    await test.container.read(barMatchProvider.notifier).start();

    var state = test.container.read(barMatchProvider);
    expect(state.status, BarMatchStatus.paused);
    expect(state.checked, 20);
    expect(state.matches, hasLength(20));
    final error = state.error;
    expect(error, isA<CocktailApiException>());
    expect(
      (error as CocktailApiException).kind,
      CocktailApiErrorKind.rateLimited,
    );

    // While the shared cooldown is active, resuming immediately re-pauses.
    await test.container.read(barMatchProvider.notifier).resume();
    state = test.container.read(barMatchProvider);
    expect(state.status, BarMatchStatus.paused);
    expect(state.checked, 20);

    clock = clock.add(const Duration(seconds: 3));
    await test.container.read(barMatchProvider.notifier).resume();

    state = test.container.read(barMatchProvider);
    expect(state.status, BarMatchStatus.done);
    expect(state.checked, 25);
    expect(state.matches, hasLength(25));
  });

  test('changing the selection or scope resets a finished run', () async {
    final test = setup(respond: (request) async => lookupResponse(
      request.url.queryParameters['i']!,
    ));
    final selection = test.container.read(barSelectionProvider.notifier);
    final scopeNotifier = test.container.read(recipeScopeProvider.notifier);
    scopeNotifier.setScope(scope(4));
    selection.toggle('Imaginary gin');

    await test.container.read(barMatchProvider.notifier).start();
    expect(test.container.read(barMatchProvider).status, BarMatchStatus.done);

    selection.toggle('Pretend lime juice');
    expect(test.container.read(barMatchProvider).status, BarMatchStatus.idle);

    await test.container.read(barMatchProvider.notifier).start();
    expect(test.container.read(barMatchProvider).status, BarMatchStatus.done);

    scopeNotifier.setScope(scope(2));
    expect(test.container.read(barMatchProvider).status, BarMatchStatus.idle);
  });

  test('starting again after a done run replaces the results', () async {
    final test = setup(respond: (request) async => lookupResponse(
      request.url.queryParameters['i']!,
    ));
    test.container.read(recipeScopeProvider.notifier).setScope(scope(4));
    test.container.read(barSelectionProvider.notifier).toggle('Imaginary gin');

    final notifier = test.container.read(barMatchProvider.notifier);
    await notifier.start();
    var state = test.container.read(barMatchProvider);
    expect(state.status, BarMatchStatus.done);
    expect(state.matches, hasLength(4));

    await notifier.start();
    state = test.container.read(barMatchProvider);
    expect(state.status, BarMatchStatus.done);
    expect(state.checked, 4);
    expect(state.matches, hasLength(4));
    expect(
      state.matches.map((match) => match.recipe.id).toSet(),
      hasLength(4),
      reason: 'A fresh start must not duplicate the previous run.',
    );
  });

  test('starting while a run is in flight abandons the earlier loop', () async {
    final gate = Completer<http.Response>();
    final test = setup(
      respond: (request) => gate.future.then(
        (_) => lookupResponse(request.url.queryParameters['i']!),
      ),
    );
    test.container.read(recipeScopeProvider.notifier).setScope(scope(4));
    test.container.read(barSelectionProvider.notifier).toggle('Imaginary gin');

    final notifier = test.container.read(barMatchProvider.notifier);
    final first = notifier.start();
    await Future<void>.delayed(Duration.zero);
    final second = notifier.start();
    gate.complete(lookupResponse('1'));
    await Future.wait([first, second]);

    final state = test.container.read(barMatchProvider);
    expect(state.status, BarMatchStatus.done);
    expect(state.checked, 4);
    expect(state.matches, hasLength(4));
    expect(
      state.matches.map((match) => match.recipe.id).toSet(),
      hasLength(4),
      reason: 'The abandoned loop must not double the results.',
    );
  });

  test('the ingredient options provider serves the provider list', () async {
    final test = setup(
      respond: (request) async => http.Response(
        jsonEncode({
          'drinks': [
            {'strIngredient1': 'Imaginary gin'},
            {'strIngredient1': 'Zest Orange'},
          ],
        }),
        200,
      ),
    );
    final options = await test.container.read(
      ingredientOptionsProvider.future,
    );
    expect(options, ['Imaginary gin', 'Zest Orange']);
  });
}
