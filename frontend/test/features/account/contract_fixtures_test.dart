import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zest/features/account/domain/account.dart';
import 'package:zest/features/collection/domain/collection_entry.dart';
import 'package:zest/features/collection/sync/sync_contract.dart';

/// The synthetic wire examples in `contract/accounts/` are shared with the
/// backend test suite, so both sides agree on one shape.
Map<String, Object?> fixture(String name) =>
    jsonDecode(File('../contract/accounts/$name').readAsStringSync())
        as Map<String, Object?>;

void main() {
  test('account session fixture parses into an Account', () {
    final json = fixture('account-session.json');
    final account = Account.fromJson(json['user']! as Map<String, Object?>);
    expect(account.email, 'sam@example.test');
    expect(Account.fromJson(account.toJson()), account);
    final session = json['session']! as Map<String, Object?>;
    expect(session['token'], isA<String>());
    expect(DateTime.tryParse(session['expiresAt']! as String), isNotNull);
  });

  test('saved, variation, and tombstone records parse and round-trip', () {
    final saved = EntryRecord.fromJson(fixture('entry-saved.json'));
    expect(saved.kind, CollectionEntryKind.saved);
    expect(saved.revision, 5);
    expect(saved.variation, isNull);

    final variation = EntryRecord.fromJson(fixture('entry-variation.json'));
    expect(variation.kind, CollectionEntryKind.variation);
    expect(variation.hasPhoto, isTrue);
    expect(
      VariationDetails.fromJson(
        Map<String, dynamic>.from(variation.variation!),
      ).name,
      'My Testbench Twist',
    );

    final tombstone = EntryRecord.fromJson(fixture('entry-deleted.json'));
    expect(tombstone.deleted, isTrue);
    expect(tombstone.source, isNull);

    for (final record in [saved, variation, tombstone]) {
      final sent = record.toJson();
      expect(sent.containsKey('revision'), isFalse);
      final again = EntryRecord.fromJson({...sent, 'revision': record.revision});
      expect(again.toJson(), sent);
    }
  });

  test('sync page fixture parses in ascending revision order', () {
    final page = SyncPage.fromJson(fixture('sync-page.json'));
    expect(page.revision, 7);
    expect(page.hasMore, isFalse);
    expect([for (final e in page.entries) e.revision], [5, 7]);
  });

  test('error fixture keeps the shared error shape', () {
    final error = fixture('error-rate-limited.json')['error']!
        as Map<String, Object?>;
    expect(error['code'], 'rate_limited');
    expect(error['message'], isA<String>());
  });

  test('records reject malformed wire data', () {
    final valid = fixture('entry-saved.json');
    for (final broken in <Map<String, Object?>>[
      {...valid, 'id': 'not-hex'},
      {...valid, 'kind': 'cocktail'},
      {...valid, 'day': '2026-02-30'},
      {...valid, 'source': null},
      {...valid, 'variation': {'name': 'x'}},
      {...valid, 'updatedAt': 'yesterday'},
    ]) {
      expect(() => EntryRecord.fromJson(broken), throwsFormatException);
    }
  });

  test('AccountRules match the documented email and password bounds', () {
    expect(AccountRules.normalizeEmail('  Sam@Example.TEST '), 'sam@example.test');
    for (final bad in ['', 'sam', '@example.test', 'sam@', 'a@b@c', 'sam @x.test']) {
      expect(AccountRules.normalizeEmail(bad), isNull, reason: bad);
    }
    expect(AccountRules.normalizeEmail('${'a' * 250}@x.io'), isNull);
    expect(AccountRules.isAcceptablePassword('x' * 9), isFalse);
    expect(AccountRules.isAcceptablePassword('x' * 10), isTrue);
    expect(AccountRules.isAcceptablePassword('x' * 128), isTrue);
    expect(AccountRules.isAcceptablePassword('x' * 129), isFalse);
    // Code points, not UTF-16 units: ten emoji are ten characters.
    expect(AccountRules.isAcceptablePassword('🍋' * 10), isTrue);
  });
}
