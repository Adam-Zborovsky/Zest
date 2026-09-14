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
  int registerCalls = 0;

  /// Held open while set, so a test can keep a first call in flight long
  /// enough for a second, overlapping call to observe the busy guard.
  Completer<void>? gate;

  @override
  Account? get currentAccount => _inner.currentAccount;

  @override
  String? get sessionToken => _inner.sessionToken;

  @override
  Future<Account> register({required String email, required String password}) async {
    registerCalls++;
    return _inner.register(email: email, password: password);
  }

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

/// A repository whose next call always fails with a given [AccountException],
/// so error-copy tests do not depend on triggering the real validation rules.
class _FailingAccountRepository implements AccountRepository {
  _FailingAccountRepository(this.failure);

  final AccountException failure;

  @override
  Account? get currentAccount => null;

  @override
  String? get sessionToken => null;

  @override
  Future<Account> register({required String email, required String password}) =>
      throw failure;

  @override
  Future<Account> signIn({required String email, required String password}) =>
      throw failure;

  @override
  Future<void> signOut() async {}

  @override
  Future<void> expireSession() async {}
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
    redirect: (context, state) => launchRedirect(controller.destination, state.uri),
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

  Future<void> tapButton(WidgetTester tester, String key) async {
    final finder = keyed(key);
    await tester.ensureVisible(finder);
    await tester.tap(finder);
  }

  testWidgets('sign-in success lands on home', (tester) async {
    final account = FakeAccountRepository();
    account.seedAccount(email: 'sam@example.test', password: 'longenoughpass');
    final router = await _pumpLogin(tester, account: account);

    await enterCredentials(tester);
    await tapButton(tester, 'login-submit');
    await tester.pumpAndSettle();

    expect(router.state.uri.path, '/');
  });

  testWidgets('create-account success signs in and lands on home', (
    tester,
  ) async {
    final account = FakeAccountRepository();
    final router = await _pumpLogin(tester, account: account);

    await tapButton(tester, 'login-mode-create-account');
    await enterCredentials(tester);
    await tapButton(tester, 'login-submit');
    await tester.pumpAndSettle();

    expect(router.state.uri.path, '/');
    expect(account.currentAccount?.email, 'sam@example.test');
  });

  testWidgets(
    'local validation blocks the network call for a bad email',
    (tester) async {
      final inner = FakeAccountRepository();
      final counting = _CountingAccountRepository(inner);
      await _pumpLogin(tester, account: counting);

      await enterCredentials(tester, email: 'not-an-email');
      await tapButton(tester, 'login-submit');
      await tester.pumpAndSettle();

      expect(find.text('Enter a valid email address.'), findsOneWidget);
      expect(counting.signInCalls, 0);
      expect(counting.registerCalls, 0);
    },
  );

  testWidgets(
    'local validation blocks the network call for a short password',
    (tester) async {
      final inner = FakeAccountRepository();
      final counting = _CountingAccountRepository(inner);
      await _pumpLogin(tester, account: counting);

      await enterCredentials(tester, password: 'short');
      await tapButton(tester, 'login-submit');
      await tester.pumpAndSettle();

      expect(find.text('Use at least 10 characters.'), findsOneWidget);
      expect(counting.signInCalls, 0);
      expect(counting.registerCalls, 0);
    },
  );

  group('AccountFailure copy', () {
    Future<void> expectFailureCopy(
      WidgetTester tester,
      AccountException failure,
      String expectedText,
    ) async {
      await _pumpLogin(tester, account: _FailingAccountRepository(failure));
      await enterCredentials(tester);
      await tapButton(tester, 'login-submit');
      await tester.pumpAndSettle();
      expect(find.text(expectedText), findsOneWidget);
    }

    testWidgets('invalidEmail', (tester) async {
      await expectFailureCopy(
        tester,
        const AccountException(AccountFailure.invalidEmail),
        'Enter a valid email address.',
      );
    });

    testWidgets('weakPassword', (tester) async {
      await expectFailureCopy(
        tester,
        const AccountException(AccountFailure.weakPassword),
        'Use at least 10 characters.',
      );
    });

    testWidgets('invalidCredentials', (tester) async {
      await expectFailureCopy(
        tester,
        const AccountException(AccountFailure.invalidCredentials),
        "That email and password don't match.",
      );
    });

    testWidgets('emailTaken', (tester) async {
      await expectFailureCopy(
        tester,
        const AccountException(AccountFailure.emailTaken),
        'An account with that email already exists. Sign in instead.',
      );
      expect(find.byKey(const ValueKey('login-sign-in-instead')), findsOneWidget);
    });

    testWidgets('rateLimited rounds retryAfter up to whole minutes', (
      tester,
    ) async {
      await expectFailureCopy(
        tester,
        const AccountException(
          AccountFailure.rateLimited,
          retryAfter: Duration(seconds: 125),
        ),
        'Too many attempts. Try again in 3 minutes.',
      );
    });

    testWidgets('rateLimited with no retryAfter', (tester) async {
      await expectFailureCopy(
        tester,
        const AccountException(AccountFailure.rateLimited),
        'Too many attempts. Try again later.',
      );
    });

    testWidgets('unreachable', (tester) async {
      await expectFailureCopy(
        tester,
        const AccountException(AccountFailure.unreachable),
        "Can't reach the Zest server. Check that it's running and you're on "
            'the same Wi-Fi.',
      );
    });

    testWidgets('server', (tester) async {
      await expectFailureCopy(
        tester,
        const AccountException(AccountFailure.server),
        'Something went wrong on the server. Try again.',
      );
    });
  });

  testWidgets(
    '"Sign in instead" switches mode and keeps the email',
    (tester) async {
      await _pumpLogin(
        tester,
        account: _FailingAccountRepository(
          const AccountException(AccountFailure.emailTaken),
        ),
      );

      await tapButton(tester, 'login-mode-create-account');
      await enterCredentials(tester);
      await tapButton(tester, 'login-submit');
      await tester.pumpAndSettle();
      await tapButton(tester, 'login-sign-in-instead');
      await tester.pumpAndSettle();

      expect(
        tester.widget<TextField>(keyed('login-email-field')).controller!.text,
        'sam@example.test',
      );
      expect(
        tester.widget<TextField>(keyed('login-password-field')).controller!.text,
        isEmpty,
      );
      expect(find.text('Sign in'), findsWidgets);
    },
  );

  testWidgets('a double tap submits only once', (tester) async {
    final gate = Completer<void>();
    final inner = FakeAccountRepository();
    inner.seedAccount(email: 'sam@example.test', password: 'longenoughpass');
    final counting = _CountingAccountRepository(inner)..gate = gate;
    await _pumpLogin(tester, account: counting);

    // Hold the first sign-in in flight so the second tap lands while the
    // screen is still busy, then release both.
    await enterCredentials(tester);
    await tapButton(tester, 'login-submit');
    await tester.pump();
    await tapButton(tester, 'login-submit');
    await tester.pump();
    gate.complete();
    await tester.pumpAndSettle();

    expect(counting.signInCalls, 1);
  });

  testWidgets('the password visibility toggle shows and hides the password', (
    tester,
  ) async {
    await _pumpLogin(tester);

    final field = () => tester.widget<TextField>(keyed('login-password-field'));
    expect(field().obscureText, isTrue);

    await tapButton(tester, 'login-password-toggle');
    await tester.pump();
    expect(field().obscureText, isFalse);

    await tapButton(tester, 'login-password-toggle');
    await tester.pump();
    expect(field().obscureText, isTrue);
  });

  testWidgets('Replay the tour goes to onboarding', (tester) async {
    final router = await _pumpLogin(tester);

    await tapButton(tester, 'login-replay-tour');
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
  });
}
