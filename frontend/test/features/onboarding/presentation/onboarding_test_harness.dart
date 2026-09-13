import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:zest/core/design/zest_theme.dart';
import 'package:zest/features/onboarding/presentation/login_screen.dart';
import 'package:zest/features/onboarding/presentation/onboarding_screen.dart';

/// A small router with only the two routes the onboarding flow touches, so
/// these tests exercise the real [OnboardingScreen] and the real
/// `context.go` navigation without pulling in the rest of the app's
/// providers. Mirrors the pattern `test/support/collection_test_overrides.dart`
/// documents for spreading a `List<dynamic>` of Riverpod 3 overrides.
GoRouter onboardingTestRouter() => GoRouter(
  initialLocation: '/onboarding',
  routes: [
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
  ],
);

/// Pumps the onboarding flow behind a minimal `MaterialApp.router`, with the
/// given session overrides and an optional forced reduced-motion state.
Future<GoRouter> pumpOnboardingApp(
  WidgetTester tester, {
  required List<dynamic> overrides,
  bool reducedMotion = false,
  TextScaler? textScaler,
  Key? captureKey,
}) async {
  final router = onboardingTestRouter();
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [...overrides],
      child: MaterialApp.router(
        routerConfig: router,
        theme: ZestTheme.build(reduceMotion: reducedMotion),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: reducedMotion,
            textScaler: textScaler ?? MediaQuery.of(context).textScaler,
          ),
          child: captureKey == null
              ? child!
              : RepaintBoundary(key: captureKey, child: child!),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}
