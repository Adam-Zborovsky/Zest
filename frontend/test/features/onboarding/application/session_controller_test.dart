import 'package:flutter_test/flutter_test.dart';
import 'package:zest/features/onboarding/application/session_controller.dart';
import 'package:zest/features/onboarding/data/session_stores.dart';
import 'package:zest/features/onboarding/domain/launch_destination.dart';
import 'package:zest/features/onboarding/domain/local_profile.dart';

import '../../../support/in_memory_session.dart';

void main() {
  late InMemoryOnboardingStore onboarding;
  late InMemoryAuthRepository auth;
  late SessionController session;
  late int notifications;

  setUp(() {
    onboarding = InMemoryOnboardingStore();
    auth = InMemoryAuthRepository(clock: () => DateTime.utc(2026, 9, 13));
    session = SessionController(onboarding: onboarding, auth: auth);
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

      final relaunched = SessionController(onboarding: onboarding, auth: auth);
      addTearDown(relaunched.dispose);
      expect(relaunched.destination, LaunchDestination.login);
      expect(relaunched.profile, isNull);
    });

    test('onboarding completed and signed in goes to the app', () async {
      await session.markOnboardingSeen();
      await session.continueOnDevice(displayName: 'Sam');

      final relaunched = SessionController(onboarding: onboarding, auth: auth);
      addTearDown(relaunched.dispose);
      expect(relaunched.destination, LaunchDestination.app);
    });

    test('signed out after having signed in goes to login', () async {
      await session.markOnboardingSeen();
      await session.continueOnDevice(displayName: null);
      await session.signOut();

      expect(session.destination, LaunchDestination.login);
    });
  });

  test('signing in from a direct login link also records onboarding, so '
      'signing out lands on login, not onboarding', () async {
    await session.continueOnDevice(displayName: null);
    await session.signOut();

    expect(onboarding.hasSeenOnboarding, isTrue);
    expect(session.destination, LaunchDestination.login);
  });

  test('continuing again after sign-out keeps the same profile id and '
      'replaces the name, including clearing it', () async {
    final first = await session.continueOnDevice(displayName: 'Sam');
    await session.signOut();
    expect(session.lastProfile, first);

    final again = await session.continueOnDevice(displayName: '  ');
    expect(again.id, first.id);
    expect(again.createdAt, first.createdAt);
    expect(again.displayName, isNull);
  });

  test('each successful change notifies once; repeated Skip does not', () async {
    await session.markOnboardingSeen();
    await session.markOnboardingSeen();
    expect(notifications, 1);

    await session.continueOnDevice(displayName: null);
    await session.signOut();
    expect(notifications, 3);
  });

  test('a failed write changes nothing and does not notify', () async {
    onboarding.failNextWrite = true;
    await expectLater(
      session.markOnboardingSeen(),
      throwsA(isA<SessionStorageException>()),
    );
    expect(session.destination, LaunchDestination.onboarding);

    await session.markOnboardingSeen();
    auth.failNextWrite = true;
    await expectLater(
      session.continueOnDevice(displayName: 'Sam'),
      throwsA(isA<SessionStorageException>()),
    );
    expect(session.destination, LaunchDestination.login);
    expect(notifications, 1);
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

  group('LocalProfile', () {
    test('trims names, treats blank as no name, and rejects overlong names', () {
      final at = DateTime.utc(2026, 9, 13);
      expect(
        LocalProfile(id: 'p', displayName: '  Sam ', createdAt: at).displayName,
        'Sam',
      );
      expect(
        LocalProfile(id: 'p', displayName: '', createdAt: at).displayName,
        isNull,
      );
      expect(
        () => LocalProfile(id: 'p', displayName: 'x' * 41, createdAt: at),
        throwsArgumentError,
      );
      expect(
        () => LocalProfile(id: ' ', displayName: null, createdAt: at),
        throwsArgumentError,
      );
    });

    test('round-trips through JSON and rejects malformed records', () {
      final profile = LocalProfile(
        id: 'p',
        displayName: 'Sam',
        createdAt: DateTime.utc(2026, 9, 13, 8),
      );
      expect(LocalProfile.fromJson(profile.toJson()), profile);
      expect(
        () => LocalProfile.fromJson({'id': 3, 'createdAt': 'x'}),
        throwsFormatException,
      );
      expect(
        () => LocalProfile.fromJson({'id': 'p', 'createdAt': 'not a date'}),
        throwsFormatException,
      );
    });
  });
}
