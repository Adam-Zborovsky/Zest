import 'package:shared_preferences/shared_preferences.dart';

import 'session_stores.dart';

/// The `shared_preferences` keys these stores read and write, and the
/// allowlist `main()` gives `SharedPreferencesWithCache.create`.
abstract final class SessionPrefsKeys {
  static const onboardingSeen = 'zest.onboarding.seen';

  static const all = {onboardingSeen};
}

/// [OnboardingStore] over a shared `SharedPreferencesWithCache`.
///
/// `SharedPreferencesWithCache.setBool` updates its own internal cache
/// *before* the platform write settles, so on a failed write that cache (and
/// any synchronous read from it) would show the new value even though
/// nothing was actually persisted. This store keeps its own mirror of
/// [hasSeenOnboarding], advanced only after a write is confirmed to have
/// succeeded, so a failed write truly changes nothing observable.
class PrefsOnboardingStore implements OnboardingStore {
  PrefsOnboardingStore(this._prefs)
    : _seen = _prefs.getBool(SessionPrefsKeys.onboardingSeen) ?? false;

  final SharedPreferencesWithCache _prefs;
  bool _seen;

  @override
  bool get hasSeenOnboarding => _seen;

  @override
  Future<void> markOnboardingSeen() async {
    try {
      await _prefs.setBool(SessionPrefsKeys.onboardingSeen, true);
    } catch (error) {
      throw SessionStorageException(
        'Could not save that onboarding was seen',
        error,
      );
    }
    _seen = true;
  }
}
