import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  runApp(const ZestApp());
}
