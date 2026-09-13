import 'package:flutter/material.dart';

import '../../../core/design/zest_tokens.dart';
import '../../../core/widgets/botanical_paper.dart';
import 'onboarding_entrance.dart';

/// The page-2 demo: a synthetic shelf of selected ingredients, plus the
/// three result strips (ready, works with a reviewed swap, missing an
/// essential) in the bar screen's visual language. Entirely synthetic —
/// no bar providers, no invented substitutions outside `docs/DATA.md`.
class OnboardingBarDemo extends StatelessWidget {
  const OnboardingBarDemo({super.key, required this.active});

  final bool active;

  static const _shelf = [('Gin', true), ('Lime', true), ('Sugar', true), ('Mint', false)];

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Example of matching a shelf of ingredients to recipes',
    child: ExcludeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: ZestSpace.sm,
            runSpacing: ZestSpace.sm,
            children: [
              for (final (name, have) in _shelf)
                PaperTag(
                  label: name,
                  color: have ? ZestPalette.celery : Colors.transparent,
                  icon: have ? Icons.check_rounded : Icons.add_rounded,
                  dashed: !have,
                ),
            ],
          ),
          const SizedBox(height: ZestSpace.lg),
          OnboardingEntrance(
            active: active,
            duration: ZestMotion.enter,
            builder: (context, t) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _strip(
                  context,
                  t: t,
                  index: 0,
                  icon: Icons.check_circle_outline_rounded,
                  tint: ZestPalette.celery,
                  title: 'Gimlet',
                  detail: 'Ready to make — every essential is on the shelf.',
                ),
                const SizedBox(height: ZestSpace.sm),
                _strip(
                  context,
                  t: t,
                  index: 1,
                  icon: Icons.swap_horiz_rounded,
                  tint: ZestPalette.grapefruit.withValues(alpha: 0.4),
                  title: 'Southside Fizz',
                  detail: 'Works with a swap — soda water for sparkling water.',
                ),
                const SizedBox(height: ZestSpace.sm),
                _strip(
                  context,
                  t: t,
                  index: 2,
                  icon: Icons.shopping_basket_outlined,
                  tint: ZestPalette.errorSurface,
                  title: 'Mojito',
                  detail: 'Missing 1 essential: mint.',
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _strip(
    BuildContext context, {
    required double t,
    required int index,
    required IconData icon,
    required Color tint,
    required String title,
    required String detail,
  }) {
    // Each strip checks in a beat after the last, staggered within the one
    // entrance — never a separate loop.
    final local = ((t - index * 0.15) / 0.7).clamp(0.0, 1.0);
    return Opacity(
      opacity: local,
      child: Transform.translate(
        offset: Offset(0, (1 - local) * 10),
        child: DecoratedBox(
          decoration: BoxDecoration(color: tint, borderRadius: ZestShape.control),
          child: Padding(
            padding: const EdgeInsets.all(ZestSpace.md),
            child: Row(
              children: [
                Icon(icon, size: 20, color: ZestPalette.leaf),
                const SizedBox(width: ZestSpace.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleSmall!.copyWith(
                          color: ZestPalette.leaf,
                        ),
                      ),
                      Text(
                        detail,
                        style: Theme.of(context).textTheme.bodySmall!.copyWith(
                          color: ZestPalette.secondaryInk,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
