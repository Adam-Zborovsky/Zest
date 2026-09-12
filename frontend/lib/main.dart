import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/zest_app.dart';

void main() {
  LicenseRegistry.addLicense(() async* {
    for (final family in ['Fraunces', 'DMSans']) {
      final license = await rootBundle.loadString(
        'assets/fonts/$family-OFL.txt',
      );
      yield LicenseEntryWithLineBreaks([family], license);
    }
  });
  runApp(
    const ProviderScope(
      child: ZestApp(
        showGallery: kDebugMode && bool.fromEnvironment('ZEST_DESIGN_GALLERY'),
      ),
    ),
  );
}
