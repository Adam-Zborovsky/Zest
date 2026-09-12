import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zest/core/design/zest_theme.dart';
import 'package:zest/core/network/cocktail_api_exception.dart';
import 'package:zest/features/discovery/application/discovery_providers.dart';
import 'package:zest/features/discovery/presentation/discovery_widgets.dart';

void main() {
  testWidgets('cooldown follows its deadline, not timer ticks or remounts', (
    tester,
  ) async {
    var clock = DateTime.utc(2026, 9, 12);
    final error = CocktailApiException(
      CocktailApiErrorKind.rateLimited,
      retryAfter: const Duration(seconds: 30),
      retryAt: clock.add(const Duration(seconds: 30)),
    );
    var retries = 0;
    Widget content(Key key) => ProviderScope(
      overrides: [nowProvider.overrideWithValue(() => clock)],
      child: MaterialApp(
        theme: ZestTheme.build(),
        home: Scaffold(
          body: DiscoveryFailure(
            key: key,
            error: error,
            onRetry: () => retries++,
          ),
        ),
      ),
    );
    await tester.pumpWidget(content(const ValueKey('first')));
    expect(find.text('Try again in 30 s'), findsOneWidget);
    // Simulates time spent backgrounded: only one UI timer tick is delivered.
    clock = clock.add(const Duration(minutes: 2));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Try again'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    expect(retries, 1);
    await tester.pumpWidget(content(const ValueKey('remounted')));
    expect(find.text('Try again'), findsOneWidget);
    expect(find.textContaining('Try again in'), findsNothing);
  });
}
