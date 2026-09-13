import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/session_stores.dart';
import 'session_controller.dart';

/// Contract providers: they throw until M7 integration wires the
/// `shared_preferences`-backed stores. Tests override them with the fakes in
/// `test/support/in_memory_session.dart`.
final onboardingStoreProvider = Provider<OnboardingStore>(
  (ref) => throw UnimplementedError(
    'onboardingStoreProvider is wired at M7 integration',
  ),
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => throw UnimplementedError(
    'authRepositoryProvider is wired at M7 integration',
  ),
);

final sessionControllerProvider = Provider<SessionController>((ref) {
  final controller = SessionController(
    onboarding: ref.watch(onboardingStoreProvider),
    auth: ref.watch(authRepositoryProvider),
  );
  ref.onDispose(controller.dispose);
  return controller;
});
