import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

/// The app-facing database connection, mirroring `openCatalogConnection`: a
/// NativeDatabase-backed file in the application support directory on
/// native platforms, and a WasmDatabase on the web loading `sqlite3.wasm`
/// and `drift_worker.js` from the app's own origin (see `web/README.md` for
/// their pinned provenance). Tests inject their own executor instead and
/// never call this. Kept as its own database (name `collection`), separate
/// from the re-syncable catalog, so catalog changes can never touch
/// personal data.
QueryExecutor openCollectionConnection() {
  return driftDatabase(
    name: 'collection',
    native: const DriftNativeOptions(
      databaseDirectory: getApplicationSupportDirectory,
    ),
    web: DriftWebOptions(
      sqlite3Wasm: Uri.parse('sqlite3.wasm'),
      driftWorker: Uri.parse('drift_worker.js'),
    ),
  );
}
