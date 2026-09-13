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

  /// The photo tile sits on Wednesday, a second day (Friday) shows the
  /// several-drinks bubble treatment, and today (with the grapefruit ring)
  /// is Tuesday — the demo shows a past memory, a busier day, and the
  /// present day, matching the real collection calendar.
  static const _photoIndex = 2;
  static const _bubbleIndex = 4;
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
                      kind: switch (i) {
                        _photoIndex => _TileKind.photo,
                        _bubbleIndex => _TileKind.bubbles,
                        _ => _TileKind.plain,
                      },
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

/// What a demo day tile shows, mirroring the real collection calendar: a
/// plain day, a single cut-paper memory, or several drinks as stacked
/// circles.
enum _TileKind { plain, photo, bubbles }

class _DayTile extends StatelessWidget {
  const _DayTile({
    required this.label,
    required this.dayNumber,
    required this.isToday,
    required this.kind,
    required this.entranceT,
  });

  final String label;
  final int dayNumber;
  final bool isToday;
  final _TileKind kind;

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
          child: Stack(
            fit: StackFit.expand,
            children: [
              switch (kind) {
                _TileKind.photo => _PhotoTile(
                  entranceT: entranceT,
                  dayNumber: dayNumber,
                ),
                _TileKind.bubbles => const _BubblesTile(),
                _TileKind.plain => Center(
                  child: _dayNumber(context, dayNumber, quiet: true),
                ),
              },
              if (ring != null)
                IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(borderRadius: _radius, border: ring),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

Text _dayNumber(BuildContext context, int dayNumber, {bool quiet = false}) => Text(
  '$dayNumber',
  style: Theme.of(context).textTheme.labelMedium!.copyWith(
    color: quiet ? ZestPalette.nightMuted : Colors.white,
    fontWeight: FontWeight.w700,
  ),
);

/// A rounded tile with cut-paper cocktail art under a 45% leaf tint and the
/// white date number, matching `CollectionScreen`'s single-drink day cell —
/// never a real photo.
class _PhotoTile extends StatelessWidget {
  const _PhotoTile({required this.entranceT, required this.dayNumber});

  final double entranceT;
  final int dayNumber;

  static const _radius = BorderRadius.all(Radius.circular(ZestSpace.sm));

  @override
  Widget build(BuildContext context) => Transform.translate(
    offset: Offset(0, (1 - entranceT) * -12),
    child: Opacity(
      opacity: entranceT,
      child: ClipRRect(
        borderRadius: _radius,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: ZestPalette.celery),
            const Center(
              child: FractionallySizedBox(
                widthFactor: 0.66,
                heightFactor: 0.66,
                child: FittedBox(
                  child: BotanicalArt(motif: BotanicalMotif.garnish, size: 48),
                ),
              ),
            ),
            ColoredBox(color: ZestPalette.leaf.withValues(alpha: 0.45)),
            Center(child: _dayNumber(context, dayNumber)),
          ],
        ),
      ),
    ),
  );
}

/// Several drinks in one day: two overlapping floating circles, the smaller
/// tucked under the largest like stacked stickers, matching the real
/// `_BubbleDay` layout with synthetic cut-paper fills instead of photos.
class _BubblesTile extends StatelessWidget {
  const _BubblesTile();

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = constraints.maxWidth;
      Widget bubble(double cx, double cy, double diameter, Color fill, BotanicalMotif motif) {
        final d = diameter * size;
        return Positioned(
          left: (cx - diameter / 2) * size,
          top: (cy - diameter / 2) * size,
          width: d,
          height: d,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              border: Border.fromBorderSide(
                BorderSide(color: ZestPalette.peach, width: 1.5),
              ),
            ),
            child: ClipOval(
              child: ColoredBox(
                color: fill,
                child: Center(
                  child: FractionallySizedBox(
                    widthFactor: 0.6,
                    heightFactor: 0.6,
                    child: FittedBox(child: BotanicalArt(motif: motif, size: 32)),
                  ),
                ),
              ),
            ),
          ),
        );
      }

      return Stack(
        children: [
          // Smaller bubble first, tucked under the larger one drawn after.
          bubble(0.80, 0.20, 0.40, ZestPalette.disabledSurface, BotanicalMotif.citrus),
          bubble(0.42, 0.60, 0.78, ZestPalette.celery, BotanicalMotif.garnish),
        ],
      );
    },
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
