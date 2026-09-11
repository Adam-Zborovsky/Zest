import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zest/core/design/zest_theme.dart';
import 'package:zest/core/design/zest_tokens.dart';

double _contrast(Color foreground, Color background) {
  final foregroundLuminance = foreground.computeLuminance();
  final backgroundLuminance = background.computeLuminance();
  final lighter = foregroundLuminance > backgroundLuminance
      ? foregroundLuminance
      : backgroundLuminance;
  final darker = foregroundLuminance < backgroundLuminance
      ? foregroundLuminance
      : backgroundLuminance;
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  group('Botanical Play theme', () {
    test('semantic text colors meet normal-text contrast requirements', () {
      final theme = ZestTheme.build();
      final colors = theme.colorScheme;
      final textPairs = <String, (Color, Color)>{
        'primary': (colors.onPrimary, colors.primary),
        'primary container': (
          colors.onPrimaryContainer,
          colors.primaryContainer,
        ),
        'secondary': (colors.onSecondary, colors.secondary),
        'secondary container': (
          colors.onSecondaryContainer,
          colors.secondaryContainer,
        ),
        'tertiary': (colors.onTertiary, colors.tertiary),
        'tertiary container': (
          colors.onTertiaryContainer,
          colors.tertiaryContainer,
        ),
        'error': (colors.onError, colors.error),
        'error container': (colors.onErrorContainer, colors.errorContainer),
        'surface': (colors.onSurface, colors.surface),
        'secondary surface text': (colors.onSurfaceVariant, colors.surface),
        'page': (colors.onSurface, theme.scaffoldBackgroundColor),
        'secondary page text': (
          colors.onSurfaceVariant,
          theme.scaffoldBackgroundColor,
        ),
        'inverse': (colors.onInverseSurface, colors.inverseSurface),
      };

      for (final entry in textPairs.entries) {
        expect(
          _contrast(entry.value.$1, entry.value.$2),
          greaterThanOrEqualTo(4.5),
          reason: '${entry.key} must remain readable at body-text sizes',
        );
      }
    });

    test('interactive outlines remain visible on control surfaces', () {
      final theme = ZestTheme.build();
      final colors = theme.colorScheme;
      for (final surface in [
        colors.surface,
        theme.scaffoldBackgroundColor,
        colors.secondaryContainer,
        colors.tertiaryContainer,
      ]) {
        expect(
          _contrast(colors.outline, surface),
          greaterThanOrEqualTo(3),
          reason: 'Control boundaries need non-text contrast against $surface',
        );
      }
    });

    test('display and reading roles have distinct families and hierarchy', () {
      final text = ZestTheme.build().textTheme;
      expect(text.displayLarge!.fontFamily, 'Fraunces');
      expect(text.headlineMedium!.fontFamily, 'Fraunces');
      expect(text.titleLarge!.fontFamily, 'Fraunces');
      expect(text.bodyLarge!.fontFamily, 'DM Sans');
      expect(text.bodyMedium!.fontFamily, 'DM Sans');
      expect(text.labelLarge!.fontFamily, 'DM Sans');

      expect(
        text.displayLarge!.fontSize!,
        greaterThan(text.headlineMedium!.fontSize!),
      );
      expect(
        text.headlineMedium!.fontSize!,
        greaterThan(text.bodyLarge!.fontSize!),
      );
      expect(text.bodyMedium!.fontSize!, greaterThanOrEqualTo(16));
      expect(text.bodyMedium!.height!, greaterThanOrEqualTo(1.5));
      expect(text.labelLarge!.fontSize!, greaterThanOrEqualTo(14));
    });

    testWidgets('theme text preserves the platform text scale', (tester) async {
      final theme = ZestTheme.build();
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
              body: Text('Readable leaves', style: theme.textTheme.bodyMedium),
            ),
          ),
        ),
      );

      final richText = tester.widget<RichText>(
        find.descendant(
          of: find.text('Readable leaves'),
          matching: find.byType(RichText),
        ),
      );
      expect(
        richText.textScaler.scale(theme.textTheme.bodyMedium!.fontSize!),
        theme.textTheme.bodyMedium!.fontSize! * 2,
      );
      expect(tester.takeException(), isNull);
    });

    test('reduced motion removes control transitions and ink ripples', () {
      final normal = ZestTheme.build();
      final reduced = ZestTheme.build(reduceMotion: true);
      expect(normal.splashFactory, InkRipple.splashFactory);
      expect(reduced.splashFactory, NoSplash.splashFactory);

      final normalStyles = [
        normal.filledButtonTheme.style!,
        normal.textButtonTheme.style!,
        normal.iconButtonTheme.style!,
      ];
      final reducedStyles = [
        reduced.filledButtonTheme.style!,
        reduced.textButtonTheme.style!,
        reduced.iconButtonTheme.style!,
      ];
      for (final style in normalStyles) {
        expect(style.animationDuration!.inMicroseconds, greaterThan(0));
        expect(style.splashFactory, InkRipple.splashFactory);
      }
      for (final style in reducedStyles) {
        expect(style.animationDuration, Duration.zero);
        expect(style.splashFactory, NoSplash.splashFactory);
      }
    });
  });

  group('Zest motion accessibility policy', () {
    for (final flags in [
      (disableAnimations: false, accessibleNavigation: false),
      (disableAnimations: true, accessibleNavigation: false),
      (disableAnimations: false, accessibleNavigation: true),
      (disableAnimations: true, accessibleNavigation: true),
    ]) {
      testWidgets('respects platform flags $flags', (tester) async {
        const requestedDuration = Duration(milliseconds: 420);
        late bool reduced;
        late Duration duration;
        late AnimationStyle sheet;
        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(
              disableAnimations: flags.disableAnimations,
              accessibleNavigation: flags.accessibleNavigation,
            ),
            child: Builder(
              builder: (context) {
                reduced = ZestMotion.reduced(context);
                duration = ZestMotion.duration(context, requestedDuration);
                sheet = ZestMotion.sheetStyle(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        );

        final shouldReduce =
            flags.disableAnimations || flags.accessibleNavigation;
        expect(reduced, shouldReduce);
        expect(duration, shouldReduce ? Duration.zero : requestedDuration);
        if (shouldReduce) {
          expect(sheet.duration, Duration.zero);
          expect(sheet.reverseDuration, Duration.zero);
        } else {
          expect(sheet.duration!.inMicroseconds, greaterThan(0));
          expect(sheet.reverseDuration!.inMicroseconds, greaterThan(0));
          expect(sheet.reverseDuration!, lessThanOrEqualTo(sheet.duration!));
        }
      });
    }
  });
}
