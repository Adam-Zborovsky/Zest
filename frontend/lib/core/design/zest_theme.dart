import 'package:flutter/material.dart';

import 'zest_tokens.dart';

abstract final class ZestTheme {
  static ThemeData build({bool reduceMotion = false}) {
    const colors = ColorScheme.light(
      primary: ZestPalette.leaf,
      onPrimary: ZestPalette.peach,
      primaryContainer: ZestPalette.celery,
      onPrimaryContainer: ZestPalette.leaf,
      secondary: ZestPalette.leaf,
      onSecondary: ZestPalette.peach,
      secondaryContainer: ZestPalette.celery,
      onSecondaryContainer: ZestPalette.leaf,
      tertiary: ZestPalette.berry,
      onTertiary: ZestPalette.peach,
      tertiaryContainer: ZestPalette.grapefruit,
      onTertiaryContainer: ZestPalette.leaf,
      error: ZestPalette.berry,
      onError: ZestPalette.peach,
      errorContainer: ZestPalette.errorSurface,
      onErrorContainer: ZestPalette.berry,
      surface: ZestPalette.peach,
      onSurface: ZestPalette.leaf,
      onSurfaceVariant: ZestPalette.secondaryInk,
      surfaceContainerLowest: ZestPalette.peach,
      surfaceContainerLow: ZestPalette.fennel,
      surfaceContainer: ZestPalette.fennel,
      surfaceContainerHigh: ZestPalette.celery,
      surfaceContainerHighest: ZestPalette.disabledSurface,
      outline: ZestPalette.outline,
      outlineVariant: ZestPalette.divider,
      inverseSurface: ZestPalette.leaf,
      onInverseSurface: ZestPalette.peach,
      inversePrimary: ZestPalette.celery,
      shadow: ZestPalette.leaf,
      scrim: ZestPalette.leaf,
      surfaceTint: Colors.transparent,
    );
    final text = TextTheme(
      displayLarge: _display(40, 1.08),
      displayMedium: _display(34, 1.12),
      displaySmall: _display(30, 1.15),
      headlineLarge: _display(28, 1.2),
      headlineMedium: _display(24, 1.22),
      headlineSmall: _display(22, 1.25),
      titleLarge: _display(20, 1.3),
      titleMedium: _body(18, FontWeight.w600),
      titleSmall: _body(16, FontWeight.w600),
      bodyLarge: _body(16, FontWeight.w400),
      bodyMedium: _body(16, FontWeight.w400),
      bodySmall: _body(14, FontWeight.w600),
      labelLarge: _body(16, FontWeight.w600),
      labelMedium: _body(14, FontWeight.w600),
      labelSmall: _body(12, FontWeight.w600),
    );
    final button = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: ZestSpace.lg, vertical: ZestSpace.md),
      ),
      shape: const WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: ZestShape.control),
      ),
      side: WidgetStateProperty.resolveWith(
        (states) => BorderSide(
          color: states.contains(WidgetState.focused)
              ? colors.onPrimary
              : Colors.transparent,
          width: 2,
        ),
      ),
      textStyle: WidgetStatePropertyAll(text.labelLarge),
      foregroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled)
            ? ZestPalette.disabledInk
            : colors.onPrimary,
      ),
      backgroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled)
            ? ZestPalette.disabledSurface
            : colors.primary,
      ),
      elevation: const WidgetStatePropertyAll(ZestElevation.flat),
      animationDuration: reduceMotion ? Duration.zero : ZestMotion.feedback,
      splashFactory: reduceMotion
          ? NoSplash.splashFactory
          : InkRipple.splashFactory,
      tapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
    );
    const inkBorder = OutlineInputBorder(
      borderRadius: ZestShape.control,
      borderSide: BorderSide(color: ZestPalette.leaf, width: 1.5),
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colors,
      scaffoldBackgroundColor: ZestPalette.fennel,
      fontFamily: 'DM Sans',
      textTheme: text,
      splashFactory: reduceMotion
          ? NoSplash.splashFactory
          : InkRipple.splashFactory,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      filledButtonTheme: FilledButtonThemeData(style: button),
      textButtonTheme: TextButtonThemeData(
        style: button.copyWith(
          side: WidgetStateProperty.resolveWith(
            (states) => BorderSide(
              color: states.contains(WidgetState.focused)
                  ? colors.primary
                  : Colors.transparent,
              width: 2,
            ),
          ),
          backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? ZestPalette.disabledInk
                : colors.primary,
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
          foregroundColor: WidgetStatePropertyAll(colors.primary),
          side: WidgetStateProperty.resolveWith(
            (states) => BorderSide(
              color: states.contains(WidgetState.focused)
                  ? colors.primary
                  : Colors.transparent,
              width: 2,
            ),
          ),
          animationDuration: button.animationDuration,
          splashFactory: button.splashFactory,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: ZestPalette.peach,
        hintStyle: text.bodyLarge!.copyWith(color: ZestPalette.secondaryInk),
        prefixIconColor: ZestPalette.leaf,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: ZestSpace.lg,
          vertical: 14,
        ),
        border: inkBorder,
        enabledBorder: inkBorder,
        focusedBorder: inkBorder.copyWith(
          borderSide: const BorderSide(color: ZestPalette.leaf, width: 3),
        ),
        errorBorder: inkBorder.copyWith(
          borderSide: const BorderSide(color: ZestPalette.berry, width: 1.5),
        ),
        focusedErrorBorder: inkBorder.copyWith(
          borderSide: const BorderSide(color: ZestPalette.berry, width: 3),
        ),
      ),
      cardTheme: const CardThemeData(
        color: ZestPalette.peach,
        elevation: ZestElevation.flat,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: ZestShape.card,
          side: BorderSide(color: ZestPalette.divider),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colors.secondaryContainer,
        selectedColor: colors.primary,
        disabledColor: ZestPalette.disabledSurface,
        labelStyle: text.labelMedium,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        shape: const RoundedRectangleBorder(borderRadius: ZestShape.control),
        side: const BorderSide(color: ZestPalette.outline),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: ZestPalette.peach,
        surfaceTintColor: Colors.transparent,
        elevation: ZestElevation.sheet,
        modalElevation: ZestElevation.sheet,
        shape: RoundedRectangleBorder(borderRadius: ZestShape.sheet),
        constraints: BoxConstraints(maxWidth: ZestSpace.contentWidth),
      ),
      dividerTheme: const DividerThemeData(
        color: ZestPalette.divider,
        space: 1,
      ),
    );
  }

  static TextStyle _display(double size, double height) => TextStyle(
    fontFamily: 'Fraunces',
    fontWeight: FontWeight.w600,
    fontSize: size,
    height: height,
    color: ZestPalette.leaf,
    fontVariations: const [FontVariation('SOFT', 60), FontVariation('WONK', 1)],
  );

  static TextStyle _body(double size, FontWeight weight) => TextStyle(
    fontFamily: 'DM Sans',
    fontWeight: weight,
    fontSize: size,
    height: 1.5,
    color: ZestPalette.leaf,
  );
}
