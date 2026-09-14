import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/zest_tokens.dart';
import '../../../core/widgets/botanical_art.dart';
import '../../../core/widgets/zest_sheet.dart';
import '../../../core/widgets/zest_states.dart';
import '../../discovery/application/discovery_providers.dart';
import '../../discovery/presentation/discovery_widgets.dart';
import '../application/collection_providers.dart';
import '../domain/collection_entry.dart';

/// The private collection as a drink calendar. Every saved drink and
/// variation sits on its day: a day with one drink shows that drink's photo
/// behind a white date number; a day with several shows floating bubbles,
/// with the date on the largest. A memory photo wins; without one, the
/// cocktail's own picture from the recipe source is used.
class CollectionScreen extends ConsumerWidget {
  const CollectionScreen({super.key});

  static const _eyebrow = 'Your collection';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = collectionDay(ref.watch(nowProvider)());
    return ref
        .watch(collectionEntriesProvider)
        .when(
          skipLoadingOnRefresh: false,
          data: (entries) {
            final byDay = groupEntriesByDay(entries);
            return DiscoveryFrame(
              back: true,
              eyebrow: _eyebrow,
              title: 'Every pour,\n',
              titleAccent: 'day by day.',
              intro:
                  'Your saved drinks and variations on a calendar, private to '
                  'this device. Tap a day to open what you had.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (entries.isEmpty) ...[
                    const _EmptyCollection(),
                    const SizedBox(height: ZestSpace.xxl),
                  ],
                  for (final month in calendarMonths(byDay.keys, today)) ...[
                    CollectionMonth(month: month, byDay: byDay, today: today),
                    const SizedBox(height: ZestSpace.xxl),
                  ],
                  if (entries.any(_showsProviderImage))
                    Text(
                      'Days without a photo of your own show a small image '
                      'from TheCocktailDB.',
                      style: Theme.of(context).textTheme.bodySmall!.copyWith(
                        color: ZestPalette.secondaryInk,
                      ),
                    ),
                ],
              ),
            );
          },
          loading: () => const DiscoveryFrame(
            back: true,
            eyebrow: _eyebrow,
            child: ZestLoadingState(label: 'Opening your calendar…'),
          ),
          error: (error, stack) => DiscoveryFrame(
            back: true,
            eyebrow: _eyebrow,
            child: ZestErrorState(
              title: 'Your calendar is out of reach',
              message:
                  'Something went wrong opening your saved drinks and '
                  'variations.',
              onRetry: () => ref.invalidate(collectionEntriesProvider),
            ),
          ),
        );
  }
}

/// Entries grouped by calendar day, each day keeping the repository order
/// (most recently updated first).
Map<DateTime, List<CollectionEntry>> groupEntriesByDay(
  List<CollectionEntry> entries,
) {
  final byDay = <DateTime, List<CollectionEntry>>{};
  for (final entry in entries) {
    byDay.putIfAbsent(entry.day, () => []).add(entry);
  }
  return byDay;
}

/// The months to show, newest first: always the current month, plus every
/// month that holds at least one drink.
List<DateTime> calendarMonths(Iterable<DateTime> days, DateTime today) {
  final months = <DateTime>{DateTime(today.year, today.month)};
  for (final day in days) {
    months.add(DateTime(day.year, day.month));
  }
  return months.toList()..sort((a, b) => b.compareTo(a));
}

/// The small 200-pixel rendition of a TheCocktailDB drink image (the
/// documented `/small` suffix), or null when the source has no valid HTTPS
/// image. Calendar cells are tiny, so the full image is never downloaded.
String? calendarThumbnailUrl(String? url) {
  final uri = Uri.tryParse(url?.trim() ?? '');
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty) {
    return null;
  }
  final text = uri.toString();
  return text.endsWith('/small') ? text : '$text/small';
}

/// True when [entry]'s tile shows TheCocktailDB's picture rather than the
/// person's own memory photo — the same condition [EntryArtwork] uses to
/// choose what to render, so the tile's semantics never claim a photo that
/// is not actually a photo of the person's own.
bool _showsProviderImage(CollectionEntry entry) =>
    !entry.hasPhoto && calendarThumbnailUrl(entry.source.thumbnailUrl) != null;

class _EmptyCollection extends StatelessWidget {
  const _EmptyCollection();

  @override
  Widget build(BuildContext context) => ZestEmptyState(
    title: 'Nothing saved yet',
    message:
        'Open a recipe and choose "Save to today", or make a personal '
        'variation, to see it on your calendar.',
    actionLabel: 'Find recipes to save',
    onAction: () => context.go('/discover'),
  );
}

/// One month: its name, the weekday initials, and a seven-column day grid
/// starting on the locale's first day of the week.
class CollectionMonth extends StatelessWidget {
  const CollectionMonth({
    super.key,
    required this.month,
    required this.byDay,
    required this.today,
  });

  final DateTime month;
  final Map<DateTime, List<CollectionEntry>> byDay;
  final DateTime today;

  static const _gap = ZestSpace.xs;

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final firstWeekday = localizations.firstDayOfWeekIndex;
    final leading =
        (DateTime(month.year, month.month).weekday % 7 - firstWeekday + 7) % 7;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            localizations.formatMonthYear(month),
            style: textTheme.headlineSmall,
          ),
        ),
        const SizedBox(height: ZestSpace.md),
        LayoutBuilder(
          builder: (context, constraints) {
            final size = ((constraints.maxWidth - _gap * 6) / 7)
                .floorToDouble();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExcludeSemantics(
                  child: Wrap(
                    spacing: _gap,
                    children: [
                      for (var i = 0; i < 7; i++)
                        SizedBox(
                          width: size,
                          child: Text(
                            localizations.narrowWeekdays[(firstWeekday + i) %
                                7],
                            textAlign: TextAlign.center,
                            style: textTheme.labelSmall!.copyWith(
                              color: ZestPalette.secondaryInk,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: ZestSpace.sm),
                Wrap(
                  spacing: _gap,
                  runSpacing: _gap,
                  children: [
                    for (var i = 0; i < leading; i++)
                      SizedBox.square(dimension: size),
                    for (var date = 1; date <= daysInMonth; date++)
                      SizedBox.square(
                        dimension: size,
                        child: CalendarDayCell(
                          day: DateTime(month.year, month.month, date),
                          entries:
                              byDay[DateTime(month.year, month.month, date)] ??
                              const [],
                          today: today,
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// One calendar day. Empty days show a quiet number; days with drinks are
/// buttons announcing the full date and the number of drinks.
class CalendarDayCell extends StatelessWidget {
  const CalendarDayCell({
    super.key,
    required this.day,
    required this.entries,
    required this.today,
  });

  final DateTime day;
  final List<CollectionEntry> entries;
  final DateTime today;

  static const _radius = BorderRadius.all(Radius.circular(ZestSpace.md));

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    final isToday = day == today;
    final count = entries.length;
    final date = localizations.formatFullDate(day);
    final todayRing = isToday
        ? const BoxDecoration(
            borderRadius: _radius,
            border: Border.fromBorderSide(
              BorderSide(color: ZestPalette.grapefruit, width: 2.5),
            ),
          )
        : null;
    final key = ValueKey('calendar-day-${collectionDayKey(day)}');
    if (count == 0) {
      return Semantics(
        key: key,
        label: '$date${isToday ? ', today' : ''}, no drinks',
        excludeSemantics: true,
        child: DecoratedBox(
          decoration: todayRing ?? const BoxDecoration(),
          child: Center(
            child: Text(
              '${day.day}',
              style: Theme.of(context).textTheme.labelMedium!.copyWith(
                color: day.isAfter(today)
                    ? ZestPalette.disabledInk
                    : ZestPalette.secondaryInk,
              ),
            ),
          ),
        ),
      );
    }
    final providerImageCount = entries.where(_showsProviderImage).length;
    final imageNote = providerImageCount == 0
        ? ''
        : count == 1
        ? ', image from TheCocktailDB'
        : providerImageCount == 1
        ? ', includes an image from TheCocktailDB'
        : ', includes images from TheCocktailDB';
    return Semantics(
      key: key,
      button: true,
      label:
          '$date${isToday ? ', today' : ''}, '
          '${count == 1 ? '1 drink' : '$count drinks'}$imageNote',
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: _radius,
          onTap: () => openCalendarDay(context, day, entries),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (count == 1)
                ClipRRect(
                  borderRadius: _radius,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      EntryArtwork(entry: entries.single),
                      const ColoredBox(color: _scrim),
                      Center(child: _DayNumber(day: day)),
                    ],
                  ),
                )
              else
                _BubbleDay(day: day, entries: entries),
              if (todayRing != null)
                IgnorePointer(child: DecoratedBox(decoration: todayRing)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Leaf green at 45%: enough to keep the white date number legible over any
/// photo while the picture still reads through.
const _scrim = Color(0x73193F32);

/// Bubble positions as (center x, center y, diameter), in fractions of the
/// cell. The first bubble is the largest, nearly filling the cell, and
/// carries the date. The others sit in the corners and tuck slightly under
/// it, like stacked stickers, so they stay big enough to read as photos in a
/// phone-width cell. Every bubble stays inside the cell.
const _twoBubbles = [(0.40, 0.60, 0.80), (0.79, 0.21, 0.42)];
const _threeBubbles = [
  (0.42, 0.60, 0.78),
  (0.80, 0.20, 0.40),
  (0.15, 0.15, 0.30),
];
const _fourBubbles = [
  (0.44, 0.58, 0.76),
  (0.81, 0.19, 0.38),
  (0.15, 0.15, 0.30),
  (0.86, 0.86, 0.28),
];

class _BubbleDay extends StatelessWidget {
  const _BubbleDay({required this.day, required this.entries});

  final DateTime day;
  final List<CollectionEntry> entries;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = constraints.maxWidth;
      final layout = switch (entries.length) {
        2 => _twoBubbles,
        3 => _threeBubbles,
        _ => _fourBubbles,
      };
      final shown = entries.take(layout.length).toList();
      Widget bubble(int index) {
        final (cx, cy, diameter) = layout[index];
        final carriesDate = index == 0;
        return Positioned(
          left: (cx - diameter / 2) * size,
          top: (cy - diameter / 2) * size,
          width: diameter * size,
          height: diameter * size,
          child: Container(
            foregroundDecoration: const BoxDecoration(
              shape: BoxShape.circle,
              border: Border.fromBorderSide(
                BorderSide(color: ZestPalette.peach, width: 1.5),
              ),
            ),
            child: ClipOval(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  EntryArtwork(entry: shown[index]),
                  if (carriesDate) ...[
                    const ColoredBox(color: _scrim),
                    Center(child: _DayNumber(day: day)),
                  ],
                ],
              ),
            ),
          ),
        );
      }

      return Stack(
        children: [
          for (var i = shown.length - 1; i >= 1; i--) bubble(i),
          bubble(0),
        ],
      );
    },
  );
}

class _DayNumber extends StatelessWidget {
  const _DayNumber({required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context) => Text(
    '${day.day}',
    style: Theme.of(context).textTheme.titleSmall!.copyWith(
      color: Colors.white,
      fontWeight: FontWeight.w700,
      height: 1,
      shadows: const [Shadow(color: Color(0x99000000), blurRadius: 3)],
    ),
  );
}

/// The picture for one entry: the person's memory photo when there is one,
/// otherwise the cocktail's small source image, otherwise designed
/// artwork. Decorative — the surrounding control carries the meaning.
class EntryArtwork extends ConsumerWidget {
  const EntryArtwork({super.key, required this.entry});

  final CollectionEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const fallback = ColoredBox(
      color: ZestPalette.celery,
      child: Center(
        child: FractionallySizedBox(
          widthFactor: 0.62,
          heightFactor: 0.62,
          child: FittedBox(
            child: BotanicalArt(motif: BotanicalMotif.emptyGlass, size: 48),
          ),
        ),
      ),
    );
    final photo = entry.hasPhoto
        ? ref.watch(memoryPhotoProvider(entry.id)).value
        : null;
    if (photo != null) {
      return Image.memory(
        photo.bytes,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        excludeFromSemantics: true,
        errorBuilder: (context, error, stack) => fallback,
      );
    }
    final url = calendarThumbnailUrl(entry.source.thumbnailUrl);
    if (url != null) {
      return Image(
        image: ref.watch(recipeImageProvider)(url),
        fit: BoxFit.cover,
        excludeFromSemantics: true,
        errorBuilder: (context, error, stack) => fallback,
      );
    }
    return fallback;
  }
}

/// Opens a day: one drink goes straight to its entry; several open a sheet
/// listing that day's drinks.
Future<void> openCalendarDay(
  BuildContext context,
  DateTime day,
  List<CollectionEntry> entries,
) async {
  if (entries.length == 1) {
    context.push('/collection/${entries.single.id}');
    return;
  }
  final localizations = MaterialLocalizations.of(context);
  final chosen = await showZestSheet<String>(
    context: context,
    title: localizations.formatMediumDate(day),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${entries.length} drinks on this day.',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium!.copyWith(color: ZestPalette.secondaryInk),
        ),
        const SizedBox(height: ZestSpace.md),
        for (final entry in entries) _DaySheetRow(entry: entry),
      ],
    ),
  );
  if (chosen != null && context.mounted) {
    context.push('/collection/$chosen');
  }
}

class _DaySheetRow extends StatelessWidget {
  const _DaySheetRow({required this.entry});

  final CollectionEntry entry;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      key: ValueKey('collection-${entry.id}'),
      borderRadius: ZestShape.control,
      onTap: () => Navigator.of(context).pop(entry.id),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: ZestSpace.sm),
        child: Row(
          children: [
            SizedBox.square(
              dimension: 52,
              child: ClipOval(child: EntryArtwork(entry: entry)),
            ),
            const SizedBox(width: ZestSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.displayName, style: textTheme.titleMedium),
                  Text(
                    entry.isVariation
                        ? 'Your variation of ${entry.source.name}'
                        : 'Saved recipe',
                    style: textTheme.bodySmall!.copyWith(
                      color: ZestPalette.secondaryInk,
                    ),
                  ),
                ],
              ),
            ),
            const ExcludeSemantics(
              child: Icon(
                Icons.chevron_right_rounded,
                color: ZestPalette.secondaryInk,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
