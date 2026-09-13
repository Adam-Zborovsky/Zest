import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/prefs_session_stores.dart';
import '../data/session_stores.dart';
import 'session_controller.dart';
import 'session_storage_providers.dart';

/// Wired to the `shared_preferences`-backed stores over the shared
/// `SharedPreferencesWithCache` from [sharedPreferencesProvider]. Tests
/// override these with the fakes in `test/support/in_memory_session.dart`.
final onboardingStoreProvider = Provider<OnboardingStore>(
  (ref) => PrefsOnboardingStore(ref.watch(sharedPreferencesProvider)),
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => PrefsAuthRepository(ref.watch(sharedPreferencesProvider)),
);

final sessionControllerProvider = Provider<SessionController>((ref) {
  final controller = SessionController(
    onboarding: ref.watch(onboardingStoreProvider),
    auth: ref.watch(authRepositoryProvider),
  );
  ref.onDispose(controller.dispose);
  return controller;
});
