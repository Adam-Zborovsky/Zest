import 'package:flutter_test/flutter_test.dart';
import 'package:zest/features/account/data/account_repository.dart';
import 'package:zest/features/onboarding/application/session_controller.dart';
import 'package:zest/features/onboarding/data/session_stores.dart';
import 'package:zest/features/onboarding/domain/launch_destination.dart';

import '../../../support/fake_account_repository.dart';
import '../../../support/in_memory_session.dart';

void main() {
  late InMemoryOnboardingStore onboarding;
  late FakeAccountRepository account;
  late SessionController session;
  late int notifications;

  SessionController buildSession() =>
      SessionController(onboarding: onboarding, account: account, sync: NoOpCollectionSync());

  setUp(() {
    onboarding = InMemoryOnboardingStore();
    account = FakeAccountRepository();
    session = buildSession();
    notifications = 0;
    session.addListener(() => notifications++);
  });

  tearDown(() => session.dispose());

  group('roadmap launch states', () {
    test('a fresh user goes to onboarding', () {
      expect(session.destination, LaunchDestination.onboarding);
    });

    test('Skip records onboarding as seen, not signed in, so the next '
        'launch goes to login', () async {
      await session.markOnboardingSeen();

      final relaunched = buildSession();
      addTearDown(relaunched.dispose);
      expect(relaunched.destination, LaunchDestination.login);
      expect(relaunched.account, isNull);
    });

    test('onboarding completed and signed in goes to the app', () async {
      await session.markOnboardingSeen();
      await session.register(email: 'sam@example.test', password: 'longenoughpass');

      final relaunched = buildSession();
      addTearDown(relaunched.dispose);
      expect(relaunched.destination, LaunchDestination.app);
    });

    test('signed out after having signed in goes to login', () async {
      await session.markOnboardingSeen();
      await session.register(email: 'sam@example.test', password: 'longenoughpass');
      await session.signOut();

      expect(session.destination, LaunchDestination.login);
    });
  });

  test('signing in from a direct login link also records onboarding, so '
      'signing out lands on login, not onboarding', () async {
    await session.register(email: 'sam@example.test', password: 'longenoughpass');
    await session.signOut();

    expect(onboarding.hasSeenOnboarding, isTrue);
    expect(session.destination, LaunchDestination.login);
  });

  test('register throws AccountException for an invalid email or weak '
      'password without touching onboarding', () async {
    await expectLater(
      session.register(email: 'not-an-email', password: 'longenoughpass'),
      throwsA(isA<AccountException>()),
    );
    expect(session.account, isNull);

    await expectLater(
      session.signIn(email: 'sam@example.test', password: 'longenoughpass'),
      throwsA(
        isA<AccountException>().having(
          (e) => e.failure,
          'failure',
          AccountFailure.invalidCredentials,
        ),
      ),
    );
  });

  test('each successful change notifies once; repeated Skip does not', () async {
    await session.markOnboardingSeen();
    await session.markOnboardingSeen();
    expect(notifications, 1);

    await session.register(email: 'sam@example.test', password: 'longenoughpass');
    await session.signOut();
    expect(notifications, 3);
  });

  test('a failed onboarding write changes nothing and does not notify', () async {
    onboarding.failNextWrite = true;
    await expectLater(
      session.markOnboardingSeen(),
      throwsA(isA<SessionStorageException>()),
    );
    expect(session.destination, LaunchDestination.onboarding);
    expect(notifications, 0);
  });

  test('a failed register throws AccountException and does not sign in', () async {
    account.failNext = const AccountException(AccountFailure.server);
    await expectLater(
      session.register(email: 'sam@example.test', password: 'longenoughpass'),
      throwsA(isA<AccountException>()),
    );
    expect(session.account, isNull);
  });

  group('launchRedirect', () {
    final home = Uri.parse('/');
    final recipe = Uri.parse('/discover/recipe/11007');
    final onboardingUri = Uri.parse(SessionRoutes.onboarding);
    final loginUri = Uri.parse(SessionRoutes.login);

    test('onboarding sends app locations to onboarding and allows both '
        'gates', () {
      const d = LaunchDestination.onboarding;
      expect(launchRedirect(d, home), SessionRoutes.onboarding);
      expect(launchRedirect(d, recipe), SessionRoutes.onboarding);
      expect(launchRedirect(d, onboardingUri), isNull);
      expect(launchRedirect(d, loginUri), isNull);
    });

    test('login sends app locations to login and allows the tour replay', () {
      const d = LaunchDestination.login;
      expect(launchRedirect(d, recipe), SessionRoutes.login);
      expect(launchRedirect(d, loginUri), isNull);
      expect(launchRedirect(d, onboardingUri), isNull);
    });

    test('app leaves app locations alone and closes both gates', () {
      const d = LaunchDestination.app;
      expect(launchRedirect(d, recipe), isNull);
      expect(launchRedirect(d, home), isNull);
      expect(launchRedirect(d, onboardingUri), SessionRoutes.home);
      expect(launchRedirect(d, loginUri), SessionRoutes.home);
    });
  });
}
