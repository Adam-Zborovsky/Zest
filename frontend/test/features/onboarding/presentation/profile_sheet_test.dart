import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:zest/core/design/zest_theme.dart';
import 'package:zest/features/account/data/account_repository.dart';
import 'package:zest/features/onboarding/application/session_providers.dart';
import 'package:zest/features/onboarding/domain/launch_destination.dart';
import 'package:zest/features/onboarding/presentation/login_screen.dart';
import 'package:zest/features/onboarding/presentation/profile_sheet.dart';

import '../../../support/fake_account_repository.dart';
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
  AccountRepository? account,
  Key? capture,
}) async {
  final overrides = sessionTestOverrides(
    onboarding: InMemoryOnboardingStore(seen: true),
    account: account ?? FakeAccountRepository(current: syntheticAccount()),
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

  testWidgets('the button opens the sheet with the account email', (
    tester,
  ) async {
    final account = FakeAccountRepository(
      current: syntheticAccount(email: 'robin@example.test'),
    );
    await _pumpHome(tester, account: account);

    await tester.tap(keyed('open-profile'));
    await tester.pumpAndSettle();

    expect(find.text('robin@example.test'), findsWidgets);
  });

  testWidgets('Sign out lands on /login and clears the account', (
    tester,
  ) async {
    final account = FakeAccountRepository(current: syntheticAccount());
    final router = await _pumpHome(tester, account: account);

    await tester.tap(keyed('open-profile'));
    await tester.pumpAndSettle();
    await tester.tap(keyed('profile-sign-out'));
    await tester.pumpAndSettle();

    expect(router.state.uri.path, SessionRoutes.login);
    expect(account.currentAccount, isNull);
  });

  testWidgets('profile-sheet Night Garden render', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(412, 915);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const capture = ValueKey('profile-sheet-capture');

    await _pumpHome(
      tester,
      account: FakeAccountRepository(
        current: syntheticAccount(email: 'robin@example.test'),
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
