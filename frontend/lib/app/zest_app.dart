import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/design/zest_theme.dart';
import '../core/design/zest_tokens.dart';
import '../core/widgets/botanical_art.dart';
import 'design_gallery.dart';

class ZestApp extends StatefulWidget {
  const ZestApp({super.key, this.showGallery = kDebugMode});

  /// The temporary M1 gallery is off by default in profile/release builds.
  final bool showGallery;

  @override
  State<ZestApp> createState() => _ZestAppState();
}

class _ZestAppState extends State<ZestApp> {
  bool _previewReducedMotion = false;

  @override
  Widget build(BuildContext context) => MediaQuery.fromView(
    view: View.of(context),
    child: Builder(
      builder: (context) {
        final media = MediaQuery.of(context);
        final systemReduced =
            media.disableAnimations || media.accessibleNavigation;
        final reduced = systemReduced || _previewReducedMotion;
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
          home: widget.showGallery
              ? DesignGallery(
                  reducedMotion: reduced,
                  systemReducedMotion: systemReduced,
                  onReducedMotionChanged: (value) =>
                      setState(() => _previewReducedMotion = value),
                )
              : const _ZestFoundation(),
        );
      },
    ),
  );
}

class _ZestFoundation extends StatelessWidget {
  const _ZestFoundation();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(ZestSpace.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const BotanicalArt(size: 112),
              const SizedBox(height: ZestSpace.lg),
              Text('Zest', style: Theme.of(context).textTheme.displayLarge),
              const SizedBox(height: ZestSpace.sm),
              const Text('A cocktail companion.', textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    ),
  );
}
