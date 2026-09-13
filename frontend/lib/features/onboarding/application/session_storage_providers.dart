import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The shared `SharedPreferencesWithCache`, created before `runApp` so every
/// read stays synchronous. Overridden in `main()`; tests never see this
/// provider directly, they override `onboardingStoreProvider` and
/// `authRepositoryProvider` (see `test/support/in_memory_session.dart`) or,
/// for the prefs contract suite, install
/// `SharedPreferencesAsyncPlatform.instance` before constructing a real
/// `SharedPreferencesWithCache`.
final sharedPreferencesProvider = Provider<SharedPreferencesWithCache>(
  (ref) => throw UnimplementedError(
    'sharedPreferencesProvider is overridden in main()',
  ),
);
