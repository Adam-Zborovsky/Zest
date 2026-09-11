import 'package:flutter/services.dart';

Future<void> loadZestFonts() async {
  for (final font in {
    'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    'Fraunces': 'assets/fonts/Fraunces.ttf',
    'DM Sans': 'assets/fonts/DMSans.ttf',
  }.entries) {
    final loader = FontLoader(font.key)..addFont(rootBundle.load(font.value));
    await loader.load();
  }
}
