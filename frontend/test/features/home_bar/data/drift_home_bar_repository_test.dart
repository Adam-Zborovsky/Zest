import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zest/features/collection/data/collection_database.dart';
import 'package:zest/features/home_bar/data/drift_home_bar_repository.dart';
import 'package:zest/features/home_bar/domain/home_bar_item.dart';

CollectionDatabase _openDb() => CollectionDatabase(
  DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
);

void main() {
  test(
    'one identity moves between locations, tombstones, and restores',
    () async {
      var clock = DateTime.utc(2026, 9, 14, 12);
      final db = _openDb();
      addTearDown(db.close);
      final repository = DriftHomeBarRepository(database: db, now: () => clock);

      final stocked = await repository.addToBar('Mint Leaves');
      expect(stocked.ingredientId, 'mint leaf');
      expect(stocked.location, HomeBarLocation.stocked);
      final repeated = await repository.addToBar('mint leaf');
      expect(repeated.updatedAt, stocked.updatedAt);

      final shopping = await repository.addToShopping('Mint Leaves');
      expect(shopping.location, HomeBarLocation.shopping);
      expect(shopping.updatedAt.isAfter(stocked.updatedAt), isTrue);
      expect(await repository.watchItems().first, [shopping]);

      await repository.remove('mint leaf');
      expect(await repository.watchItems().first, isEmpty);
      final deleted = (await repository.localRecord('mint leaf'))!;
      expect(deleted.item.deleted, isTrue);
      expect(deleted.dirty, isTrue);

      clock = clock.subtract(const Duration(days: 1));
      final restored = await repository.addToBar('Mint Leaves');
      expect(restored.deleted, isFalse);
      expect(restored.location, HomeBarLocation.stocked);
      expect(restored.updatedAt.isAfter(deleted.item.updatedAt), isTrue);
    },
  );

  test('validates backend text limits before creating a dirty row', () async {
    final db = _openDb();
    addTearDown(db.close);
    final repository = DriftHomeBarRepository(database: db);

    expect(() => repository.addToBar('a' * 121), throwsArgumentError);
    expect(() => repository.addToShopping('Gin\u0000'), throwsArgumentError);
    expect(await repository.dirtyRecords(), isEmpty);
  });
}
