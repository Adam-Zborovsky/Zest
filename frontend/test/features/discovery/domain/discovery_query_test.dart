import 'package:flutter_test/flutter_test.dart';
import 'package:zest/features/discovery/domain/discovery_query.dart';

void main() {
  group('DiscoveryQuery', () {
    test('validates and maps every discovery mode', () {
      expect(
        DiscoveryQuery(mode: DiscoveryMode.name, value: '  mint fizz  ').uri,
        Uri(
          path: '/discover',
          queryParameters: {'mode': 'name', 'q': 'mint fizz'},
        ),
      );
      expect(
        DiscoveryQuery(mode: DiscoveryMode.ingredient, value: '  lime  ').uri,
        Uri(
          path: '/discover',
          queryParameters: {'mode': 'ingredient', 'q': 'lime'},
        ),
      );
      expect(
        DiscoveryQuery(mode: DiscoveryMode.letter, value: ' Q ').uri,
        Uri(path: '/discover', queryParameters: {'mode': 'letter', 'q': 'q'}),
      );
    });

    test('has value equality and parses valid deep links', () {
      final first = DiscoveryQuery(mode: DiscoveryMode.name, value: 'mint');
      final second = DiscoveryQuery(mode: DiscoveryMode.name, value: ' mint ');
      expect(first, second);
      expect(first.hashCode, second.hashCode);
      expect(
        DiscoveryQuery.fromUri(
          Uri.parse('/discover?unused=yes&mode=letter&q=R'),
        ),
        DiscoveryQuery(mode: DiscoveryMode.letter, value: 'r'),
      );
      expect(DiscoveryQuery.fromUri(Uri.parse('/discover?unused=yes')), isNull);
    });

    test('rejects invalid direct and deep-link values safely', () {
      expect(
        () => DiscoveryQuery(mode: DiscoveryMode.name, value: '  '),
        throwsArgumentError,
      );
      expect(
        () => DiscoveryQuery(mode: DiscoveryMode.ingredient, value: ''),
        throwsArgumentError,
      );
      expect(
        () => DiscoveryQuery(mode: DiscoveryMode.letter, value: '12'),
        throwsArgumentError,
      );
      for (final uri in [
        Uri.parse('/discover?mode=name'),
        Uri.parse('/discover?q=mint'),
        Uri.parse('/discover?mode=bad&q=mint'),
        Uri.parse('/discover?mode=letter&q=aa'),
        Uri.parse('/discover?mode=name&mode=letter&q=mint'),
      ]) {
        expect(() => DiscoveryQuery.fromUri(uri), throwsFormatException);
      }
    });
  });
}
