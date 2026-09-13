import 'package:flutter_test/flutter_test.dart';
import 'package:zest/core/network/api_base_url.dart';

void main() {
  group('validateApiBaseUrl', () {
    test('accepts https to any host', () {
      expect(
        validateApiBaseUrl('https://example.com/api/cocktails/'),
        Uri.parse('https://example.com/api/cocktails/'),
      );
    });

    test('accepts http to loopback', () {
      expect(
        validateApiBaseUrl('http://127.0.0.1:3000/api/cocktails/'),
        Uri.parse('http://127.0.0.1:3000/api/cocktails/'),
      );
      expect(
        validateApiBaseUrl('http://localhost:3000/api/cocktails/'),
        isNotNull,
      );
    });

    test('rejects a URL without a trailing slash', () {
      expect(
        () => validateApiBaseUrl('https://example.com/api/cocktails'),
        throwsArgumentError,
      );
    });

    test('rejects credentials, query, and fragment', () {
      expect(
        () => validateApiBaseUrl('https://user:pass@example.com/api/'),
        throwsArgumentError,
      );
      expect(
        () => validateApiBaseUrl('https://example.com/api/?x=1'),
        throwsArgumentError,
      );
      expect(
        () => validateApiBaseUrl('https://example.com/api/#frag'),
        throwsArgumentError,
      );
    });

    test('rejects plain http to a public host', () {
      expect(
        () => validateApiBaseUrl('http://8.8.8.8/api/'),
        throwsArgumentError,
      );
    });

    group('private IPv4 boundaries', () {
      test('172.15.x is rejected', () {
        expect(
          () => validateApiBaseUrl('http://172.15.0.1/api/'),
          throwsArgumentError,
        );
      });

      test('172.16.x is accepted', () {
        expect(validateApiBaseUrl('http://172.16.0.1/api/'), isNotNull);
      });

      test('172.31.x is accepted', () {
        expect(validateApiBaseUrl('http://172.31.255.255/api/'), isNotNull);
      });

      test('172.32.x is rejected', () {
        expect(
          () => validateApiBaseUrl('http://172.32.0.1/api/'),
          throwsArgumentError,
        );
      });

      test('10/8 is accepted', () {
        expect(validateApiBaseUrl('http://10.0.0.5/api/'), isNotNull);
      });

      test('192.168/16 is accepted', () {
        expect(validateApiBaseUrl('http://192.168.1.20/api/'), isNotNull);
      });

      test('a public IP is rejected', () {
        expect(
          () => validateApiBaseUrl('http://93.184.216.34/api/'),
          throwsArgumentError,
        );
      });
    });
  });

  group('resolveAccountBaseUrl', () {
    test('resolves ../ against the catalog base', () {
      final catalog = Uri.parse('http://192.168.1.20:3000/api/cocktails/');
      expect(
        resolveAccountBaseUrl(catalog),
        Uri.parse('http://192.168.1.20:3000/api/'),
      );
    });
  });
}
