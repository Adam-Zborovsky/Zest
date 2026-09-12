import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

/// The app-facing database connection, per the documented cross-platform
/// pattern: a NativeDatabase-backed file in the application support directory
/// on native platforms, and a WasmDatabase on the web (which requires
/// `web/sqlite3.wasm` and `web/drift_worker.js` — see `web/README.md` for
/// their pinned provenance). Tests inject their own executor instead and
/// never call this.
QueryExecutor openCatalogConnection() {
  return driftDatabase(
    name: 'catalog',
    native: const DriftNativeOptions(
      databaseDirectory: getApplicationSupportDirectory,
    ),
  );
}
