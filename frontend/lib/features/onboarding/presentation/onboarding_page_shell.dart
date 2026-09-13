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

  static const _spriteSize = 72.0;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              NightBand(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: ZestSpace.page,
                    vertical: ZestSpace.xl,
                  ),
                  child: demo,
                ),
              ),
              // Straddles the band's torn edge so the character reads as a
              // supporting presence beside the demo, never inside it.
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
  }
}
