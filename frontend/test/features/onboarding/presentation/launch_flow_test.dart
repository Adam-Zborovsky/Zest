import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zest/app/zest_app.dart';
import 'package:zest/features/constellation/presentation/home_screen.dart';
import 'package:zest/features/onboarding/application/session_providers.dart';
import 'package:zest/features/onboarding/data/session_stores.dart';
import 'package:zest/features/onboarding/presentation/login_screen.dart';
import 'package:zest/features/onboarding/presentation/onboarding_screen.dart';

import '../../../support/catalog_wiring.dart';
import '../../../support/collection_test_overrides.dart';
import '../../../support/in_memory_session.dart';

/// Pumps `ZestApp` behind a manually created container so tests can drive the
/// session directly (as `continueOnDevice`/`signOut` would from a screen the
/// onboarding/login tracks own) and still observe the resulting screen.
///
/// Home is reachable in every state under test, so catalog and collection
/// wiring is always present, matching the pattern other app-level tests use.
Future<ProviderContainer> openApp(
  WidgetTester tester, {
  String? initialLocation,
  bool onboardingSeen = true,
  bool signedIn = true,
  OnboardingStore? onboarding,
  AuthRepository? auth,
}) async {
  final database = openInMemoryCatalog();
  addTearDown(database.close);
  final source = FakeCatalogLetterSource(letters: {});
  final container = ProviderContainer(
    overrides: [
      ...catalogTestOverrides(database: database, source: source),
      ...collectionTestOverrides(),
      ...sessionTestOverrides(
        onboardingSeen: onboardingSeen,
        signedIn: signedIn,
        onboarding: onboarding,
        auth: auth,
      ),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: ZestApp(initialLocation: initialLocation),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('a fresh launch opens onboarding', (tester) async {
    await openApp(tester, onboardingSeen: false, signedIn: false);

    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
    expect(find.byType(HomeScreen), findsNothing);
  });

  testWidgets('onboarding seen and signed in opens home', (tester) async {
    await openApp(tester, onboardingSeen: true, signedIn: true);

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(OnboardingScreen), findsNothing);
    expect(find.byType(LoginScreen), findsNothing);
  });

  testWidgets('skipped and never signed in opens login', (tester) async {
    await openApp(tester, onboardingSeen: true, signedIn: false);

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(OnboardingScreen), findsNothing);
    expect(find.byType(HomeScreen), findsNothing);
  });

  testWidgets('signed out after having signed in opens login', (tester) async {
    final last = syntheticProfile();
    await openApp(
      tester,
      onboarding: InMemoryOnboardingStore(seen: true),
      auth: InMemoryAuthRepository(current: null, last: last),
    );

    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets(
    'a signed-out deep link to a recipe redirects to login',
    (tester) async {
      await openApp(
        tester,
        initialLocation: '/discover/recipe/11007',
        onboardingSeen: true,
        signedIn: false,
      );

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
    },
  );

  testWidgets('a signed-in person landing on /login is sent to home', (
    tester,
  ) async {
    await openApp(
      tester,
      initialLocation: '/login',
      onboardingSeen: true,
      signedIn: true,
    );

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
  });

  testWidgets(
    'continuing on this device while on login moves to home without manual '
    'navigation',
    (tester) async {
      final container = await openApp(
        tester,
        initialLocation: '/login',
        onboardingSeen: false,
        signedIn: false,
      );
      expect(find.byType(LoginScreen), findsOneWidget);

      await container
          .read(sessionControllerProvider)
          .continueOnDevice(displayName: 'Sam');
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
    },
  );

  testWidgets('signing out from home moves to login', (tester) async {
    final container = await openApp(
      tester,
      onboardingSeen: true,
      signedIn: true,
    );
    expect(find.byType(HomeScreen), findsOneWidget);

    await container.read(sessionControllerProvider).signOut();
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
  });

  group('a way home from every screen', () {
    testWidgets('Find recipes, then Back, returns home', (tester) async {
      // Tall enough that the home action tiles are on screen and tappable.
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(900, 1600);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await openApp(tester);
      final tile = find.byKey(const ValueKey('home-discover'));
      await tester.ensureVisible(tile);
      await tester.tap(tile);
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsNothing);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('Back with no history (a deep link) goes home', (
      tester,
    ) async {
      await openApp(tester, initialLocation: '/discover');
      expect(find.byType(HomeScreen), findsNothing);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('the wordmark goes home from deep inside the app', (
      tester,
    ) async {
      await openApp(tester, initialLocation: '/collection');
      expect(find.byType(HomeScreen), findsNothing);

      await tester.tap(find.byKey(const ValueKey('wordmark-home')));
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
    });
  });

  group('through the real screens', () {
    testWidgets('fresh launch: Skip, then Continue on this device, opens '
        'home', (tester) async {
      await openApp(tester, onboardingSeen: false, signedIn: false);

      await tester.tap(find.byKey(const ValueKey('onboarding-skip')));
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('login-name-field')),
        'Sam',
      );
      await tester.tap(find.byKey(const ValueKey('login-continue')));
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('Sign out from the profile sheet opens login, which welcomes '
        'the same profile back', (tester) async {
      await openApp(tester, onboardingSeen: true, signedIn: true);

      await tester.tap(find.byKey(const ValueKey('open-profile')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('profile-sign-out')));
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.textContaining('Welcome back'), findsOneWidget);
    });
  });
}
