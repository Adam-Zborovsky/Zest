import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:zest/features/onboarding/application/session_providers.dart';
import 'package:zest/features/onboarding/data/session_stores.dart';
import 'package:zest/features/onboarding/domain/launch_destination.dart';
import 'package:zest/features/onboarding/domain/local_profile.dart';
import 'package:zest/features/onboarding/presentation/login_screen.dart';

import '../../../support/in_memory_session.dart';

class _HomeStub extends StatelessWidget {
  const _HomeStub();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('Home')));
}

class _OnboardingStub extends StatelessWidget {
  const _OnboardingStub();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('Onboarding')));
}

/// Counts `continueOnDevice` calls while delegating everything else to a
/// real [InMemoryAuthRepository], so a double tap can be told apart from a
/// single sign-in that merely takes two frames to settle.
class _CountingAuthRepository implements AuthRepository {
  _CountingAuthRepository(this._inner);

  final InMemoryAuthRepository _inner;
  int continueCalls = 0;

  /// Held open while set, so a test can keep a first call in flight long
  /// enough for a second, overlapping call to observe the busy guard. The
  /// in-memory store otherwise resolves on the next microtask, which would
  /// let the first call finish (and clear the busy flag) before a second
  /// `tester.tap` ever fires.
  Completer<void>? gate;

  @override
  LocalProfile? get currentProfile => _inner.currentProfile;

  @override
  LocalProfile? get lastProfile => _inner.lastProfile;

  @override
  Future<LocalProfile> continueOnDevice({required String? displayName}) async {
    continueCalls++;
    final gate = this.gate;
    if (gate != null) await gate.future;
    return _inner.continueOnDevice(displayName: displayName);
  }

  @override
  Future<void> signOut() => _inner.signOut();
}

/// The small test router the login track builds against: it mirrors what
/// the state track wires into the real app — `refreshListenable` on the
/// `SessionController` and `launchRedirect` driving the gate.
Future<GoRouter> _pumpLogin(
  WidgetTester tester, {
  InMemoryOnboardingStore? onboarding,
  AuthRepository? auth,
  String initial = SessionRoutes.login,
}) async {
  final overrides = sessionTestOverrides(
    onboarding: onboarding ?? InMemoryOnboardingStore(seen: true),
    auth: auth ?? InMemoryAuthRepository(),
  );
  final container = ProviderContainer(overrides: [...overrides]);
  addTearDown(container.dispose);
  final controller = container.read(sessionControllerProvider);
  final router = GoRouter(
    initialLocation: initial,
    refreshListenable: controller,
    redirect: (context, state) => launchRedirect(
      controller.destination,
      state.uri,
    ),
    routes: [
      GoRoute(path: '/', builder: (context, state) => const _HomeStub()),
      GoRoute(
        path: SessionRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: SessionRoutes.onboarding,
        builder: (context, state) => const _OnboardingStub(),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

void main() {
  Finder keyed(String value) => find.byKey(ValueKey(value));

  testWidgets('Continue with a name lands on home with the trimmed name', (
    tester,
  ) async {
    final auth = InMemoryAuthRepository();
    final router = await _pumpLogin(tester, auth: auth);

    await tester.enterText(keyed('login-name-field'), '  Sam  ');
    await tester.tap(keyed('login-continue'));
    await tester.pumpAndSettle();

    expect(router.state.uri.path, '/');
    expect(auth.currentProfile?.displayName, 'Sam');
  });

  testWidgets('Continue with a blank name creates a profile with no name', (
    tester,
  ) async {
    final auth = InMemoryAuthRepository();
    final router = await _pumpLogin(tester, auth: auth);

    await tester.tap(keyed('login-continue'));
    await tester.pumpAndSettle();

    expect(router.state.uri.path, '/');
    expect(auth.currentProfile, isNotNull);
    expect(auth.currentProfile?.displayName, isNull);
  });

  testWidgets(
    'the returning variant prefills the name and keeps the same id',
    (tester) async {
      final auth = InMemoryAuthRepository(
        last: syntheticProfile(displayName: 'Robin'),
      );
      final lastId = auth.lastProfile!.id;
      final router = await _pumpLogin(tester, auth: auth);

      expect(find.text('Welcome back, Robin.'), findsOneWidget);
      expect(
        tester.widget<TextField>(keyed('login-name-field')).controller!.text,
        'Robin',
      );

      await tester.tap(keyed('login-continue'));
      await tester.pumpAndSettle();

      expect(router.state.uri.path, '/');
      expect(auth.currentProfile?.id, lastId);
    },
  );

  testWidgets(
    'a storage failure shows an inline error, keeps the name, and a retry '
    'succeeds',
    (tester) async {
      final auth = InMemoryAuthRepository()..failNextWrite = true;
      await _pumpLogin(tester, auth: auth);

      await tester.enterText(keyed('login-name-field'), 'Sam');
      await tester.tap(keyed('login-continue'));
      await tester.pumpAndSettle();

      expect(
        find.text("Couldn't save your profile on this device. Try again."),
        findsOneWidget,
      );
      expect(find.text('Sam'), findsOneWidget);
      expect(auth.currentProfile, isNull);

      await tester.tap(keyed('login-continue'));
      await tester.pumpAndSettle();

      expect(auth.currentProfile?.displayName, 'Sam');
      expect(
        find.text("Couldn't save your profile on this device. Try again."),
        findsNothing,
      );
    },
  );

  testWidgets('a double tap signs in only once', (tester) async {
    final gate = Completer<void>();
    final counting = _CountingAuthRepository(InMemoryAuthRepository())
      ..gate = gate;
    await _pumpLogin(tester, auth: counting);

    // Hold the first sign-in in flight so the second tap lands while the
    // screen is still busy, then release both.
    await tester.tap(keyed('login-continue'));
    await tester.pump();
    await tester.tap(keyed('login-continue'));
    await tester.pump();
    gate.complete();
    await tester.pumpAndSettle();

    expect(counting.continueCalls, 1);
  });

  testWidgets('Replay the tour goes to /onboarding', (tester) async {
    final router = await _pumpLogin(tester);

    await tester.tap(keyed('login-replay-tour'));
    await tester.pumpAndSettle();

    expect(router.state.uri.path, SessionRoutes.onboarding);
  });

  testWidgets('no overflow at 320 wide with 2x text', (tester) async {
    tester.view.physicalSize = const Size(320, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await _pumpLogin(tester);

    expect(tester.takeException(), isNull);

    // Returning variant, same size, also must not overflow.
    await _pumpLogin(
      tester,
      auth: InMemoryAuthRepository(
        last: syntheticProfile(displayName: 'Alexandria the Third'),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
