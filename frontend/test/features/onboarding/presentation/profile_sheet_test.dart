import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:zest/features/account/data/account_repository.dart';
import 'package:zest/features/collection/sync/sync_contract.dart';
import 'package:zest/features/onboarding/application/session_providers.dart';
import 'package:zest/features/onboarding/domain/launch_destination.dart';
import 'package:zest/features/onboarding/presentation/login_screen.dart';
import 'package:zest/features/onboarding/presentation/profile_sheet.dart';

import '../../../support/fake_account_repository.dart';
import '../../../support/fake_collection_sync.dart';
import '../../../support/in_memory_session.dart';

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

/// The small router the login track builds against, signed in by default so
/// the profile button and its sheet have someone to show.
Future<GoRouter> _pumpHome(
  WidgetTester tester, {
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

  testWidgets('renders the account email and join date', (tester) async {
    final account = FakeAccountRepository(
      current: syntheticAccount(email: 'robin@example.test'),
    );
    await _pumpHome(tester, account: account);

    await tester.tap(keyed('open-profile'));
    await tester.pumpAndSettle();

    expect(find.text('robin@example.test'), findsWidgets);
    expect(find.textContaining('Signed in since'), findsOneWidget);
  });

  testWidgets('idle before the first sync shows "Not synced yet"', (
    tester,
  ) async {
    final sync = FakeCollectionSync();
    await _pumpHome(tester, sync: sync);

    await tester.tap(keyed('open-profile'));
    await tester.pumpAndSettle();

    expect(find.text('Not synced yet'), findsOneWidget);
  });

  testWidgets('idle with lastSyncedAt shows a synced line', (tester) async {
    final sync = FakeCollectionSync(
      initial: SyncStatus(SyncPhase.idle, lastSyncedAt: DateTime.now()),
    );
    await _pumpHome(tester, sync: sync);

    await tester.tap(keyed('open-profile'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Synced'), findsOneWidget);
  });

  testWidgets('syncing shows "Syncing…"', (tester) async {
    final sync = FakeCollectionSync(initial: const SyncStatus(SyncPhase.syncing));
    await _pumpHome(tester, sync: sync);

    await tester.tap(keyed('open-profile'));
    await tester.pumpAndSettle();

    expect(find.text('Syncing…'), findsOneWidget);
  });

  testWidgets('offline shows the offline copy', (tester) async {
    final sync = FakeCollectionSync(initial: const SyncStatus(SyncPhase.offline));
    await _pumpHome(tester, sync: sync);

    await tester.tap(keyed('open-profile'));
    await tester.pumpAndSettle();

    expect(
      find.text('Offline — changes will sync when the server is reachable.'),
      findsOneWidget,
    );
  });

  testWidgets('failed shows the retry copy', (tester) async {
    final sync = FakeCollectionSync(initial: const SyncStatus(SyncPhase.failed));
    await _pumpHome(tester, sync: sync);

    await tester.tap(keyed('open-profile'));
    await tester.pumpAndSettle();

    expect(find.text("Couldn't sync. Try again."), findsOneWidget);
  });

  testWidgets('"Sync now" calls syncNow and disables while syncing', (
    tester,
  ) async {
    final sync = FakeCollectionSync();
    await _pumpHome(tester, sync: sync);

    await tester.tap(keyed('open-profile'));
    await tester.pumpAndSettle();

    await tester.tap(keyed('profile-sync-now'));
    await tester.pump();
    expect(sync.syncNowCalls, 1);

    sync.emit(const SyncStatus(SyncPhase.syncing));
    await tester.pump();

    final button = tester.widget<FilledButton>(
      find.descendant(
        of: keyed('profile-sync-now'),
        matching: find.byType(FilledButton),
      ),
    );
    expect(button.enabled, isFalse);
  });

  testWidgets('sign out lands on /login and clears the account', (
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

  testWidgets('no overflow at 320 wide with 2x text', (tester) async {
    tester.view.physicalSize = const Size(320, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await _pumpHome(tester);
    await tester.tap(keyed('open-profile'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
