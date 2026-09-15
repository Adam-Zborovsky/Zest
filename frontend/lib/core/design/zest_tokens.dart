import 'package:flutter/material.dart';

/// Botanical Play primitives. Use theme roles in ordinary components.
abstract final class ZestPalette {
  static const fennel = Color(0xFFF3F5DF);
  static const leaf = Color(0xFF193F32);
  static const celery = Color(0xFFDBE9B0);
  static const grapefruit = Color(0xFFF9A58C);
  static const peach = Color(0xFFFFF9ED);
  static const berry = Color(0xFF813C4D);
  static const secondaryInk = Color(0xFF496453);
  static const outline = Color(0xFF496453);
  static const divider = Color(0xFFDCE2CB);
  static const errorSurface = Color(0xFFFFF0F3);
  static const disabledSurface = Color(0xFFE4E6D7);
  static const disabledInk = Color(0xFF707668);

  /// Night Garden: the leaf-green field behind page headers and the
  /// constellation.
  static const night = leaf;

  /// Raised surfaces and spirit glyphs on the night field.
  static const moss = Color(0xFF2E5E4C);

  /// Primary ink on the night field.
  static const nightInk = peach;

  /// Supporting ink on the night field.
  static const nightMuted = celery;
}

abstract final class ZestSpace {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const page = 20.0;
  static const xl = 24.0;
  static const section = 28.0;
  static const xxl = 32.0;
  static const touchTarget = 48.0;
  static const contentWidth = 480.0;
  static const pageWidth = 800.0;
}

abstract final class ZestShape {
  static const control = BorderRadius.all(Radius.circular(16));
  static const card = BorderRadius.all(Radius.circular(24));
  static const pill = BorderRadius.all(Radius.circular(999));
  static const recipe = BorderRadiusDirectional.only(
    topStart: Radius.circular(36),
    topEnd: Radius.circular(14),
    bottomStart: Radius.circular(14),
    bottomEnd: Radius.circular(36),
  );
  static const sheet = BorderRadius.vertical(top: Radius.circular(32));
}

abstract final class ZestElevation {
  static const flat = 0.0;
  static const sheet = 4.0;
}

/// Cut-paper depth: a crisp, unblurred offset shadow. Reserved for things
/// that can be pressed (primary buttons, action tiles, recipe cards) so
/// elevation keeps meaning something.
abstract final class ZestShadow {
  static List<BoxShadow> hard(Color color, {double offset = 3}) => [
    BoxShadow(color: color, offset: Offset(offset, offset)),
  ];
}

abstract final class ZestMotion {
  static const feedback = Duration(milliseconds: 140);
  static const enter = Duration(milliseconds: 260);
  static const exit = Duration(milliseconds: 180);

  /// The selected-node pop in the constellation.
  static const pop = Duration(milliseconds: 320);
  static const easeOut = Cubic(0.2, 0.0, 0.0, 1.0);

  /// Whether idle, looping motion — the constellation float — runs at all.
  /// Reduced motion always disables it regardless. The test harness turns
  /// it off (test/flutter_test_config.dart) so `pumpAndSettle` can settle.
  static bool ambientMotion = true;

  static bool reduced(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context) ||
      MediaQuery.accessibleNavigationOf(context);

  static Duration duration(BuildContext context, Duration normal) =>
      reduced(context) ? Duration.zero : normal;

  static AnimationStyle sheetStyle(BuildContext context) => reduced(context)
      ? AnimationStyle.noAnimation
      : const AnimationStyle(duration: enter, reverseDuration: exit);
}
