import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../account/application/account_providers.dart';
import '../../collection/sync/sync_providers.dart';
import '../data/prefs_session_stores.dart';
import '../data/session_stores.dart';
import 'session_controller.dart';
import 'session_storage_providers.dart';

/// Wired to the `shared_preferences`-backed store over the shared
/// `SharedPreferencesWithCache` from [sharedPreferencesProvider]. Tests
/// override this with the fake in `test/support/in_memory_session.dart`.
final onboardingStoreProvider = Provider<OnboardingStore>(
  (ref) => PrefsOnboardingStore(ref.watch(sharedPreferencesProvider)),
);

final sessionControllerProvider = Provider<SessionController>((ref) {
  final controller = SessionController(
    onboarding: ref.watch(onboardingStoreProvider),
    account: ref.watch(accountRepositoryProvider),
    sync: ref.watch(collectionSyncProvider),
  );
  ref.onDispose(controller.dispose);
  return controller;
});
