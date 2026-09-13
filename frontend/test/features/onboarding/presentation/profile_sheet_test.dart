import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:zest/core/design/zest_theme.dart';
import 'package:zest/features/onboarding/application/session_providers.dart';
import 'package:zest/features/onboarding/data/session_stores.dart';
import 'package:zest/features/onboarding/domain/launch_destination.dart';
import 'package:zest/features/onboarding/presentation/login_screen.dart';
import 'package:zest/features/onboarding/presentation/profile_sheet.dart';

import '../../../support/in_memory_session.dart';
import '../../../support/load_fonts.dart';

class _HomeStub extends StatelessWidget {
  const _HomeStub();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Home'),
      actions: const [ProfileButton()],
    ),
    body: const Center(child: Text('Home')),
  );
}

class _OnboardingStub extends StatelessWidget {
  const _OnboardingStub();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('Onboarding')));
}

/// The small router the login track builds against, signed in by default so
/// the profile button and its sheet have someone to show.
Future<GoRouter> _pumpHome(
  WidgetTester tester, {
  AuthRepository? auth,
  Key? capture,
}) async {
  final overrides = sessionTestOverrides(
    onboarding: InMemoryOnboardingStore(seen: true),
    auth: auth ?? InMemoryAuthRepository(current: syntheticProfile()),
  );
  final container = ProviderContainer(overrides: [...overrides]);
  addTearDown(container.dispose);
  final controller = container.read(sessionControllerProvider);
  final router = GoRouter(
    initialLocation: '/',
    refreshListenable: controller,
    redirect: (context, state) =>
        launchRedirect(controller.destination, state.uri),
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
  final app = MaterialApp.router(
    theme: ZestTheme.build(),
    themeMode: ThemeMode.light,
    debugShowCheckedModeBanner: false,
    routerConfig: router,
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: capture == null ? app : RepaintBoundary(key: capture, child: app),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

void main() {
  setUpAll(loadZestFonts);

  Finder keyed(String value) => find.byKey(ValueKey(value));

  testWidgets('the button opens the sheet with the name and date', (
    tester,
  ) async {
    final auth = InMemoryAuthRepository(
      current: syntheticProfile(displayName: 'Robin'),
    );
    await _pumpHome(tester, auth: auth);

    await tester.tap(keyed('open-profile'));
    await tester.pumpAndSettle();

    expect(find.text('Robin'), findsOneWidget);
    expect(find.textContaining('Kept on this device since'), findsOneWidget);
  });

  testWidgets('the sheet shows "On this device" for a nameless profile', (
    tester,
  ) async {
    final auth = InMemoryAuthRepository(current: syntheticProfile(displayName: null));
    await _pumpHome(tester, auth: auth);

    await tester.tap(keyed('open-profile'));
    await tester.pumpAndSettle();

    expect(find.text('On this device'), findsOneWidget);
  });

  testWidgets(
    'Sign out lands on /login, clears the profile, and keeps lastProfile',
    (tester) async {
      final auth = InMemoryAuthRepository(current: syntheticProfile());
      final router = await _pumpHome(tester, auth: auth);

      await tester.tap(keyed('open-profile'));
      await tester.pumpAndSettle();
      await tester.tap(keyed('profile-sign-out'));
      await tester.pumpAndSettle();

      expect(router.state.uri.path, SessionRoutes.login);
      expect(auth.currentProfile, isNull);
      expect(auth.lastProfile, isNotNull);
    },
  );

  testWidgets(
    'a sign-out failure keeps the sheet open and shows the inline error',
    (tester) async {
      final auth = InMemoryAuthRepository(current: syntheticProfile())
        ..failNextWrite = true;
      await _pumpHome(tester, auth: auth);

      await tester.tap(keyed('open-profile'));
      await tester.pumpAndSettle();
      await tester.tap(keyed('profile-sign-out'));
      await tester.pumpAndSettle();

      expect(
        find.text("Couldn't sign out on this device. Try again."),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('profile-sign-out')), findsOneWidget);
      expect(auth.currentProfile, isNotNull);

      await tester.tap(keyed('profile-sign-out'));
      await tester.pumpAndSettle();

      expect(auth.currentProfile, isNull);
    },
  );

  testWidgets('profile-sheet Night Garden render', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(412, 915);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const capture = ValueKey('profile-sheet-capture');

    await _pumpHome(
      tester,
      auth: InMemoryAuthRepository(
        current: syntheticProfile(displayName: 'Robin'),
      ),
      capture: capture,
    );

    await tester.tap(keyed('open-profile'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    await expectLater(
      find.byKey(capture),
      matchesGoldenFile('goldens/profile-sheet.png'),
    );
    final semantics = tester.ensureSemantics();
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    semantics.dispose();
  });
}
