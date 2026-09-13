import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/zest_app.dart';
import 'features/onboarding/application/session_storage_providers.dart';
import 'features/onboarding/data/prefs_session_stores.dart';

// Must stay a const: `bool.fromEnvironment` throws at runtime outside a
// constant context, and the root ProviderScope below is not const.
const _designGalleryRequested = bool.fromEnvironment('ZEST_DESIGN_GALLERY');

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
    cacheOptions: const SharedPreferencesWithCacheOptions(
      allowList: SessionPrefsKeys.all,
    ),
  );
  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: ZestApp(
        showGallery: kDebugMode && _designGalleryRequested,
      ),
    ),
  );
}
