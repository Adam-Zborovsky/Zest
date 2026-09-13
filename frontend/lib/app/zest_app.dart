import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/design/zest_theme.dart';
import '../features/onboarding/application/session_providers.dart';
import 'design_gallery.dart';
import 'zest_router.dart';

class ZestApp extends ConsumerStatefulWidget {
  const ZestApp({super.key, this.showGallery = false, this.initialLocation});

  /// The temporary M1 gallery is off by default in profile/release builds.
  final bool showGallery;
  final String? initialLocation;

  @override
  ConsumerState<ZestApp> createState() => _ZestAppState();
}

class _ZestAppState extends ConsumerState<ZestApp> {
  bool _previewReducedMotion = false;
  // Initialized eagerly in initState, not as a late-final field initializer:
  // the gallery build path never reads `_router`, so a lazy initializer would
  // otherwise run for the first time inside dispose() — after the element is
  // deactivating, when `ref.read` is unsafe.
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = createZestRouter(
      initialLocation: widget.initialLocation,
      session: ref.read(sessionControllerProvider),
    );
  }

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MediaQuery.fromView(
    view: View.of(context),
    child: Builder(
      builder: (context) {
        final media = MediaQuery.of(context);
        final systemReduced =
            media.disableAnimations || media.accessibleNavigation;
        final reduced = systemReduced || _previewReducedMotion;
        if (!widget.showGallery || !kDebugMode)
          return MaterialApp.router(
            title: 'Zest',
            debugShowCheckedModeBanner: false,
            routerConfig: _router,
            theme: ZestTheme.build(reduceMotion: reduced),
            themeMode: ThemeMode.light,
            themeAnimationDuration: Duration.zero,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
              child: child!,
            ),
          );
        return MaterialApp(
          title: 'Zest',
          debugShowCheckedModeBanner: false,
          theme: ZestTheme.build(reduceMotion: reduced),
          themeMode: ThemeMode.light,
          themeAnimationDuration: Duration.zero,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
            child: child!,
          ),
          home: DesignGallery(
            reducedMotion: reduced,
            systemReducedMotion: systemReduced,
            onReducedMotionChanged: (value) =>
                setState(() => _previewReducedMotion = value),
          ),
        );
      },
    ),
  );
}
