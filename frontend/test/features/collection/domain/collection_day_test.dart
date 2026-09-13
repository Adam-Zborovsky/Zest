import 'package:flutter_test/flutter_test.dart';
import 'package:zest/features/collection/domain/collection_entry.dart';
import 'package:zest/features/collection/presentation/collection_screen.dart';

void main() {
  test('collectionDay drops the time of day', () {
    expect(
      collectionDay(DateTime(2026, 9, 13, 23, 59, 59)),
      DateTime(2026, 9, 13),
    );
  });

  test('day keys round-trip and reject malformed or impossible dates', () {
    expect(collectionDayKey(DateTime(2026, 9, 3)), '2026-09-03');
    expect(parseCollectionDayKey('2026-09-03'), DateTime(2026, 9, 3));
    expect(() => parseCollectionDayKey('13/09/2026'), throwsFormatException);
    expect(() => parseCollectionDayKey('2026-02-30'), throwsFormatException);
    expect(() => parseCollectionDayKey(''), throwsFormatException);
  });

  test('calendar months are newest first and always include this month', () {
    final months = calendarMonths([
      DateTime(2026, 7, 4),
      DateTime(2026, 9, 1),
      DateTime(2026, 7, 20),
    ], DateTime(2026, 9, 13));
    expect(months, [DateTime(2026, 9), DateTime(2026, 7)]);
    expect(calendarMonths(const [], DateTime(2026, 9, 13)), [
      DateTime(2026, 9),
    ]);
  });

  test(
    'calendar thumbnails use the small source rendition over HTTPS only',
    () {
      expect(
        calendarThumbnailUrl(
          'https://www.thecocktaildb.com/images/media/drink/a.jpg',
        ),
        'https://www.thecocktaildb.com/images/media/drink/a.jpg/small',
      );
      expect(
        calendarThumbnailUrl('https://example.test/a.jpg/small'),
        'https://example.test/a.jpg/small',
      );
      expect(calendarThumbnailUrl('http://example.test/a.jpg'), isNull);
      expect(calendarThumbnailUrl(null), isNull);
      expect(calendarThumbnailUrl(''), isNull);
    },
  );
}
