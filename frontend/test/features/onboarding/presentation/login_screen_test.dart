import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:zest/features/account/data/account_repository.dart';
import 'package:zest/features/account/domain/account.dart';
import 'package:zest/features/onboarding/application/session_providers.dart';
import 'package:zest/features/onboarding/domain/launch_destination.dart';
import 'package:zest/features/onboarding/presentation/login_screen.dart';

import '../../../support/fake_account_repository.dart';
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

/// Counts `signIn` calls while delegating everything else to a real
/// [FakeAccountRepository], so a double tap can be told apart from a single
/// sign-in that merely takes two frames to settle.
class _CountingAccountRepository implements AccountRepository {
  _CountingAccountRepository(this._inner);

  final FakeAccountRepository _inner;
  int signInCalls = 0;

  /// Held open while set, so a test can keep a first call in flight long
  /// enough for a second, overlapping call to observe the busy guard.
  Completer<void>? gate;

  @override
  Account? get currentAccount => _inner.currentAccount;

  @override
  String? get sessionToken => _inner.sessionToken;

  @override
  Future<Account> register({required String email, required String password}) =>
      _inner.register(email: email, password: password);

  @override
  Future<Account> signIn({required String email, required String password}) async {
    signInCalls++;
    final gate = this.gate;
    if (gate != null) await gate.future;
    return _inner.signIn(email: email, password: password);
  }

  @override
  Future<void> signOut() => _inner.signOut();

  @override
  Future<void> expireSession() => _inner.expireSession();
}

/// The small test router the login track builds against: it mirrors what
/// the state track wires into the real app — `refreshListenable` on the
/// `SessionController` and `launchRedirect` driving the gate.
Future<GoRouter> _pumpLogin(
  WidgetTester tester, {
  InMemoryOnboardingStore? onboarding,
  AccountRepository? account,
  String initial = SessionRoutes.login,
}) async {
  final overrides = sessionTestOverrides(
    onboarding: onboarding ?? InMemoryOnboardingStore(seen: true),
    account: account ?? FakeAccountRepository(),
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

  Future<void> enterCredentials(
    WidgetTester tester, {
    String email = 'sam@example.test',
    String password = 'longenoughpass',
  }) async {
    await tester.enterText(keyed('login-email-field'), email);
    await tester.enterText(keyed('login-password-field'), password);
  }

  // The taller email/password card can push the submit buttons below the
  // fold on the default test surface, unlike the single-field M7 form.
  Future<void> tapButton(WidgetTester tester, String key) async {
    final finder = keyed(key);
    await tester.ensureVisible(finder);
    await tester.tap(finder);
  }

  testWidgets('Create account signs in and lands on home', (tester) async {
    final account = FakeAccountRepository();
    final router = await _pumpLogin(tester, account: account);

    await enterCredentials(tester);
    await tapButton(tester, 'login-create-account');
    await tester.pumpAndSettle();

    expect(router.state.uri.path, '/');
    expect(account.currentAccount?.email, 'sam@example.test');
  });

  testWidgets('Sign in with correct credentials lands on home', (tester) async {
    final account = FakeAccountRepository();
    account.seedAccount(email: 'sam@example.test', password: 'longenoughpass');
    final router = await _pumpLogin(tester, account: account);

    await enterCredentials(tester);
    await tapButton(tester, 'login-sign-in');
    await tester.pumpAndSettle();

    expect(router.state.uri.path, '/');
  });

  testWidgets('an invalid email shows an inline error and does not sign in', (
    tester,
  ) async {
    final account = FakeAccountRepository();
    await _pumpLogin(tester, account: account);

    await enterCredentials(tester, email: 'not-an-email');
    await tapButton(tester, 'login-sign-in');
    await tester.pumpAndSettle();

    expect(find.text('Enter a valid email address.'), findsOneWidget);
    expect(account.currentAccount, isNull);
  });

  testWidgets('wrong credentials show an inline error', (tester) async {
    final account = FakeAccountRepository();
    account.seedAccount(email: 'sam@example.test', password: 'longenoughpass');
    await _pumpLogin(tester, account: account);

    await enterCredentials(tester, password: 'thewrongpassword');
    await tapButton(tester, 'login-sign-in');
    await tester.pumpAndSettle();

    expect(find.text('Incorrect email or password.'), findsOneWidget);
    expect(account.currentAccount, isNull);
  });

  testWidgets(
    'creating an account with a taken email shows an inline error, and a '
    'retry with different credentials succeeds',
    (tester) async {
      final account = FakeAccountRepository();
      account.seedAccount(email: 'sam@example.test', password: 'longenoughpass');
      final router = await _pumpLogin(tester, account: account);

      await enterCredentials(tester);
      await tapButton(tester, 'login-create-account');
      await tester.pumpAndSettle();

      expect(
        find.text('An account with that email already exists.'),
        findsOneWidget,
      );

      await enterCredentials(tester, email: 'robin@example.test');
      await tapButton(tester, 'login-create-account');
      await tester.pumpAndSettle();

      expect(router.state.uri.path, '/');
      expect(account.currentAccount?.email, 'robin@example.test');
    },
  );

  testWidgets('a double tap signs in only once', (tester) async {
    final gate = Completer<void>();
    final inner = FakeAccountRepository();
    inner.seedAccount(email: 'sam@example.test', password: 'longenoughpass');
    final counting = _CountingAccountRepository(inner)..gate = gate;
    await _pumpLogin(tester, account: counting);

    // Hold the first sign-in in flight so the second tap lands while the
    // screen is still busy, then release both.
    await enterCredentials(tester);
    await tapButton(tester, 'login-sign-in');
    await tester.pump();
    await tapButton(tester, 'login-sign-in');
    await tester.pump();
    gate.complete();
    await tester.pumpAndSettle();

    expect(counting.signInCalls, 1);
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
  });
}
