import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/design/zest_theme.dart';
import '../core/widgets/zest_notice.dart';
import '../features/catalog/application/catalog_update_controller.dart';
import '../features/catalog/domain/catalog_update_state.dart';
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
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  // docs/M11.md "Update behavior": a resume 6+ hours after the last
  // successful check triggers a background check that stages (never
  // auto-applies) a found update.
  AppLifecycleListener? _lifecycleListener;

  // Manual (not build-scoped) subscription: the update notice must be
  // offered no matter which route is current, not only while Home happens
  // to be mounted (docs/M11.md, independent review finding #3/#7).
  ProviderSubscription<CatalogUpdateState>? _updateSubscription;

  @override
  void initState() {
    super.initState();
    _router = createZestRouter(
      initialLocation: widget.initialLocation,
      session: ref.read(sessionControllerProvider),
      navigatorKey: _navigatorKey,
    );
    _lifecycleListener = AppLifecycleListener(
      onResume: () => ref
          .read(catalogUpdateControllerProvider.notifier)
          .checkAfterResume(),
    );
    _updateSubscription = ref.listenManual(
      catalogUpdateControllerProvider,
      _onCatalogUpdateState,
    );
    // Runs the launch check once here, at the app shell, rather than from
    // whichever screen happens to be first: a cold deep link straight to
    // e.g. `/discover` must still trigger it (finding #3).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(catalogUpdateControllerProvider.notifier).checkOnLaunch();
    });
  }

  @override
  void dispose() {
    _updateSubscription?.close();
    _lifecycleListener?.dispose();
    _router.dispose();
    super.dispose();
  }

  /// The update notice: shown only on a real, non-silent version change —
  /// never for a 304/no-op, and never for the first automatic download.
  void _onCatalogUpdateState(
    CatalogUpdateState? previous,
    CatalogUpdateState next,
  ) {
    if (next.silent || next.diff == null || next.diff!.isNoOp) return;
    // The Navigator's own context is an ancestor of its Overlay, not a
    // descendant, so `Overlay.of` must not be searched from it — reach the
    // overlay directly instead (see `showZestNotice`'s doc comment).
    final overlayState = _navigatorKey.currentState?.overlay;
    if (overlayState == null) return;
    if (next.status == CatalogUpdateStatus.updated &&
        previous?.status != CatalogUpdateStatus.updated) {
      showZestNotice(
        overlayState,
        message: catalogUpdateNoticeText(next.diff!),
      );
    } else if (next.status == CatalogUpdateStatus.staged &&
        previous?.status != CatalogUpdateStatus.staged) {
      showZestNotice(
        overlayState,
        message: catalogUpdateStagedNoticeText(next.diff!),
        actionLabel: 'Update',
        onAction: () =>
            ref.read(catalogUpdateControllerProvider.notifier).applyStaged(),
      );
    }
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
