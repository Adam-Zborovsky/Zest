import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:shared_preferences_platform_interface/types.dart';
import 'package:zest/features/onboarding/data/prefs_session_stores.dart';

import '../../../support/session_store_contract.dart';

/// An in-memory platform that can be told to fail its next write, so the
/// contract's failure tests exercise the same "cache runs ahead of the
/// platform" hazard [PrefsOnboardingStore] and [PrefsAuthRepository] guard
/// against, rather than a fake that can't fail at all.
base class FailingSharedPreferencesAsync extends InMemorySharedPreferencesAsync {
  FailingSharedPreferencesAsync.empty() : super.empty();

  /// When true, the next write throws and resets.
  bool failNextWrite = false;

  void _maybeFail() {
    if (!failNextWrite) return;
    failNextWrite = false;
    throw Exception('Synthetic platform write failure');
  }

  @override
  Future<bool> setString(
    String key,
    String value,
    SharedPreferencesOptions options,
  ) async {
    _maybeFail();
    return super.setString(key, value, options);
  }

  @override
  Future<bool> setBool(
    String key,
    bool value,
    SharedPreferencesOptions options,
  ) async {
    _maybeFail();
    return super.setBool(key, value, options);
  }

  @override
  Future<bool> clear(
    ClearPreferencesParameters parameters,
    SharedPreferencesOptions options,
  ) async {
    _maybeFail();
    return super.clear(parameters, options);
  }
}

void main() {
  late FailingSharedPreferencesAsync platform;

  setUp(() {
    platform = FailingSharedPreferencesAsync.empty();
    SharedPreferencesAsyncPlatform.instance = platform;
  });

  // Each call re-reads from `platform`, the single backing shared by every
  // instance in a test — the same relationship a real relaunch has to the
  // on-disk store, so `create` doubles as `relaunch`.
  Future<SharedPreferencesWithCache> prefs() => SharedPreferencesWithCache.create(
    cacheOptions: const SharedPreferencesWithCacheOptions(
      allowList: SessionPrefsKeys.all,
    ),
  );

  runOnboardingStoreContract(
    'PrefsOnboardingStore',
    create: () async => PrefsOnboardingStore(await prefs()),
    failNextWrite: () => platform.failNextWrite = true,
    relaunch: () async => PrefsOnboardingStore(await prefs()),
  );

  runAuthRepositoryContract(
    'PrefsAuthRepository',
    create: () async => PrefsAuthRepository(
      await prefs(),
      clock: () => DateTime.utc(2026, 9, 13),
      newId: () => 'prefs-profile',
    ),
    failNextWrite: () => platform.failNextWrite = true,
    relaunch: () async => PrefsAuthRepository(
      await prefs(),
      clock: () => DateTime.utc(2026, 9, 13),
      newId: () => 'prefs-profile',
    ),
    seedMalformedProfile: () async {
      const options = SharedPreferencesOptions();
      await platform.setString(
        SessionPrefsKeys.currentProfile,
        'not json',
        options,
      );
      await platform.setString(
        SessionPrefsKeys.lastProfile,
        'not json',
        options,
      );
    },
  );
}
