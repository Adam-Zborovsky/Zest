import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:zest/core/design/zest_theme.dart';
import 'package:zest/features/account/data/account_repository.dart';
import 'package:zest/features/collection/sync/sync_contract.dart';
import 'package:zest/features/onboarding/application/session_providers.dart';
import 'package:zest/features/onboarding/domain/launch_destination.dart';
import 'package:zest/features/onboarding/presentation/login_screen.dart';
import 'package:zest/features/onboarding/presentation/profile_sheet.dart';

import '../../../support/fake_account_repository.dart';
import '../../../support/fake_collection_sync.dart';
import '../../../support/in_memory_session.dart';
import '../../../support/load_fonts.dart';

class _HomeStub extends StatelessWidget {
  const _HomeStub();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Home'), actions: const [ProfileButton()]),
    body: const Center(child: Text('Home')),
  );
}

class _OnboardingStub extends StatelessWidget {
  const _OnboardingStub();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('Onboarding')));
}

Future<void> _pumpProfileSheet(
  WidgetTester tester, {
  required Key capture,
  AccountRepository? account,
  FakeCollectionSync? sync,
}) async {
  final overrides = sessionTestOverrides(
    onboarding: InMemoryOnboardingStore(seen: true),
    account: account ?? FakeAccountRepository(current: syntheticAccount()),
    sync: sync ?? FakeCollectionSync(),
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
  await tester.tap(find.byKey(const ValueKey('open-profile')));
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

  Future<void> setSurface(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(412, 915);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('profile-sheet-synced render', (tester) async {
    await setSurface(tester);
    const capture = ValueKey('profile-sheet-synced-capture');

    await _pumpProfileSheet(
      tester,
      capture: capture,
      account: FakeAccountRepository(
        current: syntheticAccount(email: 'robin@example.test'),
      ),
      sync: FakeCollectionSync(
        initial: SyncStatus(SyncPhase.idle, lastSyncedAt: DateTime(2026, 9, 14, 9)),
      ),
    );

    expect(tester.takeException(), isNull);
    await expectLater(
      find.byKey(capture),
      matchesGoldenFile('goldens/profile-sheet-synced.png'),
    );
    await checkGuidelines(tester);
  });

  testWidgets('profile-sheet-offline render', (tester) async {
    await setSurface(tester);
    const capture = ValueKey('profile-sheet-offline-capture');

    await _pumpProfileSheet(
      tester,
      capture: capture,
      account: FakeAccountRepository(
        current: syntheticAccount(email: 'robin@example.test'),
      ),
      sync: FakeCollectionSync(initial: const SyncStatus(SyncPhase.offline)),
    );

    expect(tester.takeException(), isNull);
    await expectLater(
      find.byKey(capture),
      matchesGoldenFile('goldens/profile-sheet-offline.png'),
    );
    await checkGuidelines(tester);
  });
}
