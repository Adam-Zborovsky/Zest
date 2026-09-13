import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/zest_tokens.dart';
import '../../../core/widgets/lime_sprite.dart';
import '../../../core/widgets/zest_button.dart';
import '../../../core/widgets/zest_inline_error.dart';
import '../application/session_providers.dart';
import '../data/session_stores.dart';
import '../domain/launch_destination.dart';
import 'onboarding_bar_demo.dart';
import 'onboarding_constellation_demo.dart';
import 'onboarding_memory_demo.dart';
import 'onboarding_page_shell.dart';
import 'onboarding_variation_demo.dart';

class _Page {
  const _Page(this.heading, this.intro, this.demo, this.spritePose);
  final String heading;
  final String intro;
  final Widget Function(bool active) demo;
  final LimeSpritePose spritePose;
}

final _pages = [
  _Page(
    'Explore what goes together',
    'Tap an ingredient to see which ones share recipes with it.',
    (active) => OnboardingConstellationDemo(active: active),
    LimeSpritePose.point,
  ),
  _Page(
    'See what you can make',
    'Pick what you have on hand. Zest sorts recipes into ready, a swap away, '
        'and missing an essential.',
    (active) => OnboardingBarDemo(active: active),
    LimeSpritePose.bottle,
  ),
  _Page(
    'Make it your own',
    'Save a recipe, then tweak a measure. Your version sits beside the '
        'original — the original recipe stays unchanged.',
    (active) => OnboardingVariationDemo(active: active),
    LimeSpritePose.pencil,
  ),
  _Page(
    'Keep a memory',
    'Add one photo to a saved drink whenever you like. Zest only asks for '
        'your camera when you do.',
    (active) => OnboardingMemoryDemo(active: active),
    LimeSpritePose.photo,
  ),
];

/// The swipeable four-page introduction, then login as the fifth step.
/// Replaces the M7 contract shell; the class name and const no-argument
/// constructor are the contract other tracks depend on.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  int _page = 0;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _announce(0));
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _announce(int index) {
    final view = View.maybeOf(context);
    if (view == null) return;
    SemanticsService.sendAnnouncement(
      view,
      'Page ${index + 1} of 5. ${_pages[index].heading}',
      TextDirection.ltr,
    );
  }

  void _goToPage(int index) {
    if (index < 0 || index >= _pages.length) return;
    if (ZestMotion.reduced(context)) {
      _pageController.jumpToPage(index);
    } else {
      // Fire-and-forget: no control waits for the page-turn animation.
      unawaited(
        _pageController.animateToPage(
          index,
          duration: ZestMotion.enter,
          curve: ZestMotion.easeOut,
        ),
      );
    }
  }

  Future<void> _finish() async {
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(sessionControllerProvider).markOnboardingSeen();
      if (!mounted) return;
      context.go(SessionRoutes.login);
    } on SessionStorageException catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = error.message;
      });
    }
  }

  void _handleNext() {
    if (_page == _pages.length - 1) {
      unawaited(_finish());
    } else {
      _goToPage(_page + 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lastPage = _page == _pages.length - 1;
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(
              onSkip: _submitting ? null : () => unawaited(_finish()),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() => _page = index);
                  _announce(index);
                },
                children: [
                  for (var i = 0; i < _pages.length; i++)
                    OnboardingPageShell(
                      heading: _pages[i].heading,
                      intro: _pages[i].intro,
                      demo: _pages[i].demo(_page == i),
                      spritePose: _pages[i].spritePose,
                    ),
                ],
              ),
            ),
            _BottomBar(
              page: _page,
              total: _pages.length + 1,
              error: _error,
              onBack: _page == 0 ? null : () => _goToPage(_page - 1),
              onNext: _submitting ? null : _handleNext,
              nextLabel: lastPage ? 'Continue' : 'Next',
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onSkip});

  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: ZestPalette.night,
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: ZestSpace.page,
        vertical: ZestSpace.md,
      ),
      child: Row(
        children: [
          const _Wordmark(),
          const Spacer(),
          TextButton(
            key: const ValueKey('onboarding-skip'),
            onPressed: onSkip,
            style: TextButton.styleFrom(foregroundColor: ZestPalette.nightInk),
            child: const Text('Skip'),
          ),
        ],
      ),
    ),
  );
}

class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    // The brand lockup is a fixed-size decorative mark, not reading content,
    // so it stays put at large text sizes instead of pushing the functional
    // Skip control off the 320-logical-pixel-wide top bar.
    child: MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: ZestPalette.peach,
              shape: BoxShape.circle,
            ),
            child: Text(
              'Z',
              style: Theme.of(context).textTheme.titleLarge!.copyWith(
                color: ZestPalette.leaf,
              ),
            ),
          ),
          const SizedBox(width: ZestSpace.sm),
          Text(
            'Zest',
            style: Theme.of(context).textTheme.titleLarge!.copyWith(
              color: ZestPalette.nightInk,
            ),
          ),
        ],
      ),
    ),
  );
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.page,
    required this.total,
    required this.error,
    required this.onBack,
    required this.onNext,
    required this.nextLabel,
  });

  final int page;
  final int total;
  final String? error;
  final VoidCallback? onBack;
  final VoidCallback? onNext;
  final String nextLabel;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Theme.of(context).colorScheme.surface,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(
        ZestSpace.page,
        ZestSpace.md,
        ZestSpace.page,
        ZestSpace.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (error != null) ...[
            ZestInlineError(error!),
            const SizedBox(height: ZestSpace.sm),
          ],
          Text(
            '${page + 1} of $total',
            style: Theme.of(context).textTheme.labelMedium!.copyWith(
              color: ZestPalette.secondaryInk,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: ZestSpace.sm),
          _ProgressDots(page: page, total: total),
          const SizedBox(height: ZestSpace.lg),
          Row(
            children: [
              Expanded(
                child: ZestButton(
                  key: const ValueKey('onboarding-back'),
                  label: 'Back',
                  kind: ZestButtonKind.secondary,
                  onPressed: onBack,
                ),
              ),
              const SizedBox(width: ZestSpace.md),
              Expanded(
                flex: 2,
                child: ZestButton(
                  key: const ValueKey('onboarding-next'),
                  label: nextLabel,
                  onPressed: onNext,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _ProgressDots extends StatelessWidget {
  const _ProgressDots({required this.page, required this.total});

  final int page;
  final int total;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Row(
      children: [
        for (var i = 0; i < total; i++) ...[
          if (i > 0) const SizedBox(width: ZestSpace.xs),
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: i <= page ? ZestPalette.leaf : ZestPalette.disabledSurface,
                borderRadius: ZestShape.pill,
              ),
              child: const SizedBox(height: 6),
            ),
          ),
        ],
      ],
    ),
  );
}
