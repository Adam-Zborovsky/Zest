import 'package:flutter/material.dart';

import '../../../core/design/zest_tokens.dart';
import '../../../core/widgets/botanical_paper.dart';
import '../../../core/widgets/lime_sprite.dart';

/// One onboarding page: a night-field demo with the lime character peeking
/// over its torn edge, then a Fraunces heading and intro copy on the fennel
/// page. Scrolls so 320-logical-pixel widths with 2x text never overflow.
class OnboardingPageShell extends StatelessWidget {
  const OnboardingPageShell({
    super.key,
    required this.heading,
    required this.intro,
    required this.demo,
    required this.spritePose,
  });

  final String heading;
  final String intro;
  final Widget demo;
  final LimeSpritePose spritePose;

  // About 96 logical pixels so the character reads as a character, per
  // docs/ONBOARDING.md.
  static const _spriteSize = 96.0;

  /// The night band and its demo take roughly 55-60% of the page's
  /// available height, matching the Stitch references, instead of leaving
  /// the lower fennel section mostly empty.
  static const _bandHeightFraction = 0.68;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final bandMinHeight = constraints.maxHeight * _bandHeightFraction;
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(minHeight: bandMinHeight),
                    child: NightBand(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: ZestSpace.page,
                          vertical: ZestSpace.xl,
                        ),
                        child: Center(child: demo),
                      ),
                    ),
                  ),
                  // Straddles the band's torn edge so the character reads as
                  // a supporting presence beside the demo, never inside it.
                  Positioned(
                    right: ZestSpace.page,
                    bottom: -_spriteSize * 0.4,
                    child: LimeSprite(pose: spritePose, size: _spriteSize),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  ZestSpace.page,
                  ZestSpace.xl,
                  ZestSpace.page,
                  ZestSpace.md,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(heading, style: textTheme.headlineMedium),
                    ),
                    const SizedBox(height: ZestSpace.sm),
                    Text(
                      intro,
                      style: textTheme.bodyLarge!.copyWith(
                        color: ZestPalette.secondaryInk,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
