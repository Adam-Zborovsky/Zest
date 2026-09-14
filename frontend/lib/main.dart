import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/zest_app.dart';
import 'core/network/api_base_url.dart';
import 'features/account/application/account_providers.dart';
import 'features/account/application/account_sync_coordinator.dart';
import 'features/account/data/http_account_repository.dart';
import 'features/collection/application/collection_storage_providers.dart';
import 'features/collection/sync/http_sync_api.dart';
import 'features/collection/sync/sync_engine.dart';
import 'features/collection/sync/sync_providers.dart';
import 'features/home_bar/application/home_bar_storage_providers.dart';
import 'features/home_bar/sync/home_bar_sync_engine.dart';
import 'features/home_bar/sync/home_bar_sync_providers.dart';
import 'features/home_bar/sync/http_home_bar_sync_api.dart';
import 'features/onboarding/application/session_providers.dart';
import 'features/onboarding/application/session_storage_providers.dart';
import 'features/onboarding/data/prefs_session_stores.dart';

// Must stay a const: `bool.fromEnvironment` throws at runtime outside a
// constant context, and the root ProviderScope below is not const.
const _designGalleryRequested = bool.fromEnvironment('ZEST_DESIGN_GALLERY');

const _catalogBaseUrl = String.fromEnvironment(
  'ZEST_API_BASE_URL',
  defaultValue: 'http://127.0.0.1:3000/api/cocktails/',
);

/// One lifecycle and status surface over the collection and home-bar streams.
/// Both public sync providers below resolve to this same cached instance, so a
/// write in either feature schedules both independent revision streams.
final _accountSyncCoordinatorProvider = Provider<AccountSyncCoordinator>((ref) {
  final account = ref.watch(accountRepositoryProvider);
  final baseUrl = ref.watch(syncBaseUrlProvider);
  void expireSession() =>
      unawaited(ref.read(sessionControllerProvider).expireSession());

  final collection = SyncEngine(
    api: HttpSyncApi(
      baseUrl: baseUrl,
      client: ref.watch(syncHttpClientProvider),
      account: account,
    ),
    store: ref.watch(driftCollectionRepositoryProvider),
    account: account,
    onSessionExpired: expireSession,
  );
  final homeBar = HomeBarSyncEngine(
    api: HttpHomeBarSyncApi(
      baseUrl: baseUrl,
      client: ref.watch(syncHttpClientProvider),
      account: account,
    ),
    store: ref.watch(driftHomeBarRepositoryProvider),
    account: account,
    onSessionExpired: expireSession,
  );
  final coordinator = AccountSyncCoordinator(
    collection: collection,
    homeBar: homeBar,
  );
  ref.onDispose(() {
    coordinator.dispose();
    collection.dispose();
    homeBar.dispose();
  });
  scheduleMicrotask(coordinator.syncNow);
  return coordinator;
});

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    for (final family in ['Fraunces', 'DMSans']) {
      final license = await rootBundle.loadString(
        'assets/fonts/$family-OFL.txt',
      );
      yield LicenseEntryWithLineBreaks([family], license);
    }
  });
  // Created before runApp so launch state is synchronous and no splash state
  // exists: the router's first redirect already knows the answer.
  final prefs = await SharedPreferencesWithCache.create(
    cacheOptions: SharedPreferencesWithCacheOptions(
      allowList: {...SessionPrefsKeys.all, AccountPrefsKeys.account},
    ),
  );
  final accountBaseUrl = resolveAccountBaseUrl(
    validateApiBaseUrl(_catalogBaseUrl),
  );
  // Loaded before runApp so AccountRepository.currentAccount and
  // sessionToken are synchronous (docs/ACCOUNTS.md "Launch").
  final accountRepository = await HttpAccountRepository.load(
    baseUrl: accountBaseUrl,
    prefs: prefs,
  );

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        accountRepositoryProvider.overrideWithValue(accountRepository),
        syncBaseUrlProvider.overrideWithValue(accountBaseUrl),
        collectionSyncProvider.overrideWith(
          (ref) => ref.watch(_accountSyncCoordinatorProvider),
        ),
        homeBarSyncProvider.overrideWith(
          (ref) => ref.watch(_accountSyncCoordinatorProvider),
        ),
      ],
      child: ZestApp(showGallery: kDebugMode && _designGalleryRequested),
    ),
  );
}
