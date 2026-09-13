import 'package:flutter/material.dart';

import '../../../core/design/zest_tokens.dart';
import '../../../core/widgets/botanical_art.dart';
import 'onboarding_entrance.dart';

/// The page-4 demo: a calendar week with one cut-paper "memory" tile (never
/// a real photo) and a non-interactive "Add a photo" illustration. Synthetic
/// content only.
class OnboardingMemoryDemo extends StatelessWidget {
  const OnboardingMemoryDemo({super.key, required this.active});

  final bool active;

  static const _weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  /// The photo tile sits on Wednesday; today (with the grapefruit ring) is
  /// Tuesday, so the demo shows both a past memory and the present day.
  static const _photoIndex = 2;
  static const _todayIndex = 1;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Example of a saved memory on the collection calendar',
    child: ExcludeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: ZestSpace.sm,
            runSpacing: ZestSpace.xs,
            children: [
              Text(
                'This week',
                style: Theme.of(context).textTheme.titleSmall!.copyWith(
                  color: ZestPalette.nightInk,
                ),
              ),
              const _AddPhotoPill(),
            ],
          ),
          const SizedBox(height: ZestSpace.md),
          OnboardingEntrance(
            active: active,
            duration: ZestMotion.enter,
            builder: (context, t) => Row(
              children: [
                for (var i = 0; i < 7; i++) ...[
                  if (i > 0) const SizedBox(width: ZestSpace.xs),
                  Expanded(
                    child: _DayTile(
                      label: _weekdays[i],
                      dayNumber: 12 + i,
                      isToday: i == _todayIndex,
                      hasPhoto: i == _photoIndex,
                      entranceT: i == _photoIndex ? t : 1,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: ZestSpace.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(
                  Icons.lock_outline_rounded,
                  size: 14,
                  color: ZestPalette.nightMuted,
                ),
              ),
              const SizedBox(width: ZestSpace.xs),
              Flexible(
                child: Text(
                  'Photos stay on this device.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall!.copyWith(
                    color: ZestPalette.nightMuted,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _DayTile extends StatelessWidget {
  const _DayTile({
    required this.label,
    required this.dayNumber,
    required this.isToday,
    required this.hasPhoto,
    required this.entranceT,
  });

  final String label;
  final int dayNumber;
  final bool isToday;
  final bool hasPhoto;

  /// 0 → 1 drop-in for the photo tile only.
  final double entranceT;

  static const _radius = BorderRadius.all(Radius.circular(ZestSpace.sm));

  @override
  Widget build(BuildContext context) {
    final ring = isToday
        ? Border.all(color: ZestPalette.grapefruit, width: 2)
        : null;
    return Column(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall!.copyWith(
            color: ZestPalette.nightMuted,
          ),
        ),
        const SizedBox(height: ZestSpace.xs),
        AspectRatio(
          aspectRatio: 0.8,
          child: DecoratedBox(
            decoration: BoxDecoration(borderRadius: _radius, border: ring),
            child: hasPhoto
                ? Transform.translate(
                    offset: Offset(0, (1 - entranceT) * -12),
                    child: Opacity(
                      opacity: entranceT,
                      child: ClipRRect(
                        borderRadius: _radius,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            const ColoredBox(color: ZestPalette.moss),
                            const Center(
                              child: BotanicalArt(motif: BotanicalMotif.citrus, size: 26),
                            ),
                            ColoredBox(color: ZestPalette.leaf.withValues(alpha: 0.45)),
                            Center(child: _dayNumber(context)),
                          ],
                        ),
                      ),
                    ),
                  )
                : Center(child: _dayNumber(context, quiet: true)),
          ),
        ),
      ],
    );
  }

  Widget _dayNumber(BuildContext context, {bool quiet = false}) => Text(
    '$dayNumber',
    style: Theme.of(context).textTheme.labelMedium!.copyWith(
      color: quiet ? ZestPalette.nightMuted : Colors.white,
      fontWeight: FontWeight.w700,
    ),
  );
}

class _AddPhotoPill extends StatelessWidget {
  const _AddPhotoPill();

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: ZestPalette.moss,
      borderRadius: ZestShape.pill,
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: ZestSpace.md, vertical: ZestSpace.xs),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.add_photo_alternate_outlined, size: 14, color: ZestPalette.nightInk),
          const SizedBox(width: ZestSpace.xs),
          Flexible(
            child: Text(
              'Add a photo',
              style: Theme.of(context).textTheme.labelSmall!.copyWith(
                color: ZestPalette.nightInk,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
