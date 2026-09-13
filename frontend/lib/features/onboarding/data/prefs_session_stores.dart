import 'dart:convert';
import 'dart:math' as math;

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/local_profile.dart';
import 'session_stores.dart';

/// The `shared_preferences` keys these stores read and write, and the
/// allowlist `main()` gives `SharedPreferencesWithCache.create`.
abstract final class SessionPrefsKeys {
  static const onboardingSeen = 'zest.onboarding.seen';
  static const currentProfile = 'zest.profile.current';
  static const lastProfile = 'zest.profile.last';

  static const all = {onboardingSeen, currentProfile, lastProfile};
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

/// [AuthRepository] over a shared `SharedPreferencesWithCache`. See
/// [PrefsOnboardingStore] for why profile state is mirrored locally rather
/// than re-read from the cache after construction.
class PrefsAuthRepository implements AuthRepository {
  PrefsAuthRepository(
    this._prefs, {
    DateTime Function()? clock,
    String Function()? newId,
  }) : _clock = clock ?? DateTime.now,
       _newId = newId ?? newLocalProfileId,
       _current = _decode(_prefs.getString(SessionPrefsKeys.currentProfile)),
       _last = _decode(_prefs.getString(SessionPrefsKeys.lastProfile));

  final SharedPreferencesWithCache _prefs;
  final DateTime Function() _clock;
  final String Function() _newId;

  LocalProfile? _current;
  LocalProfile? _last;

  @override
  LocalProfile? get currentProfile => _current;

  @override
  LocalProfile? get lastProfile => _last;

  @override
  Future<LocalProfile> continueOnDevice({
    required String? displayName,
  }) async {
    // Throws ArgumentError for an overlong name before anything is written,
    // per the AuthRepository contract.
    final name = LocalProfile.normalizeDisplayName(displayName);
    final previous = _last;
    final profile = previous == null
        ? LocalProfile(id: _newId(), displayName: name, createdAt: _clock())
        : previous.withDisplayName(name);
    final encoded = jsonEncode(profile.toJson());
    try {
      await _prefs.setString(SessionPrefsKeys.currentProfile, encoded);
      await _prefs.setString(SessionPrefsKeys.lastProfile, encoded);
    } catch (error) {
      throw SessionStorageException(
        'Could not save the local profile',
        error,
      );
    }
    _current = profile;
    _last = profile;
    return profile;
  }

  @override
  Future<void> signOut() async {
    try {
      await _prefs.remove(SessionPrefsKeys.currentProfile);
    } catch (error) {
      throw SessionStorageException('Could not sign out', error);
    }
    _current = null;
  }

  static LocalProfile? _decode(String? raw) {
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, Object?>) return null;
      return LocalProfile.fromJson(json);
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }
}

/// A random 128-bit identifier in lowercase hex, the same shape the
/// collection feature uses for entry ids (`newCollectionEntryId`). Local-only
/// ids: profiles never sync anywhere, so no coordination is needed.
String newLocalProfileId([math.Random? random]) {
  final source = random ?? math.Random.secure();
  return [
    for (var i = 0; i < 16; i++)
      source.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ].join();
}
