import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:zest/core/design/zest_theme.dart';
import 'package:zest/features/onboarding/application/session_providers.dart';
import 'package:zest/features/onboarding/data/session_stores.dart';
import 'package:zest/features/onboarding/domain/launch_destination.dart';
import 'package:zest/features/onboarding/presentation/login_screen.dart';

import '../../../support/in_memory_session.dart';
import '../../../support/load_fonts.dart';

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

/// The Night Garden theme wrapped around a small router — the same shape the
/// login track's logic tests use, but with the real theme so the golden
/// matches the reviewed design instead of Material's defaults.
Future<void> _pumpLogin(
  WidgetTester tester, {
  required Key capture,
  AuthRepository? auth,
}) async {
  final overrides = sessionTestOverrides(
    onboarding: InMemoryOnboardingStore(seen: true),
    auth: auth ?? InMemoryAuthRepository(),
  );
  final container = ProviderContainer(overrides: [...overrides]);
  addTearDown(container.dispose);
  final controller = container.read(sessionControllerProvider);
  final router = GoRouter(
    initialLocation: SessionRoutes.login,
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
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: RepaintBoundary(
        key: capture,
        child: MaterialApp.router(
          theme: ZestTheme.build(),
          themeMode: ThemeMode.light,
          debugShowCheckedModeBanner: false,
          routerConfig: router,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadZestFonts);

  Future<void> checkGuidelines(WidgetTester tester) async {
    final semantics = tester.ensureSemantics();
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    semantics.dispose();
  }

  testWidgets('login-fresh Night Garden render', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(412, 915);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const capture = ValueKey('login-fresh-capture');

    await _pumpLogin(tester, capture: capture);

    expect(tester.takeException(), isNull);
    await expectLater(
      find.byKey(capture),
      matchesGoldenFile('goldens/login-fresh.png'),
    );
    await checkGuidelines(tester);
  });

  testWidgets('login-returning Night Garden render', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(412, 915);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const capture = ValueKey('login-returning-capture');

    await _pumpLogin(
      tester,
      capture: capture,
      auth: InMemoryAuthRepository(last: syntheticProfile(displayName: 'Robin')),
    );

    expect(tester.takeException(), isNull);
    await expectLater(
      find.byKey(capture),
      matchesGoldenFile('goldens/login-returning.png'),
    );
    await checkGuidelines(tester);
  });
}
