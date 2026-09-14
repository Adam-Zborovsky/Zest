import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as raw;
import 'package:zest/features/collection/data/collection_database.dart';
import 'package:zest/features/home_bar/data/drift_home_bar_repository.dart';
import 'package:zest/features/home_bar/domain/home_bar_item.dart';

void main() {
  test('schema 4 migrates to the isolated home-bar tables', () async {
    final directory = await Directory.systemTemp.createTemp('zest-m10-schema');
    addTearDown(() => directory.delete(recursive: true));
    final path = '${directory.path}${Platform.pathSeparator}collection.sqlite';
    final legacy = raw.sqlite3.open(path);
    legacy.execute(
      'CREATE TABLE sync_state (id INTEGER NOT NULL PRIMARY KEY, owner_user_id TEXT NULL, last_revision INTEGER NOT NULL DEFAULT 0);',
    );
    legacy.userVersion = 4;
    legacy.close();

    final database = CollectionDatabase(NativeDatabase(File(path)));
    addTearDown(database.close);
    final repository = DriftHomeBarRepository(
      database: database,
      now: () => DateTime.utc(2026, 9, 14),
    );

    final item = await repository.addToBar('Gin');
    expect(item.location, HomeBarLocation.stocked);
    expect(await repository.ownerUserId(), isNull);
    expect(await repository.lastRevision(), 0);
  });
}
