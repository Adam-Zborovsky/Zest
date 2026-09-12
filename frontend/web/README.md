# Web database assets

Drift's web support (`WasmDatabase`, opened by `openCatalogConnection()` in
`lib/features/catalog/data/catalog_connection.dart`) loads two assets from
this directory. They are committed binaries, obtained from the official
drift releases; do not edit or regenerate them by hand.

| File | Source | Version | SHA-256 |
| --- | --- | --- | --- |
| `sqlite3.wasm` | <https://github.com/simolus3/drift/releases/download/drift-2.35.0/sqlite3.wasm> | drift 2.35.0 (matches the `drift` package version in `pubspec.lock`) | `13D3F11D05B39BA0618A7115FB41640A5D48B6300F5D3F325F554B42BD6688A4` |
| `drift_worker.js` | <https://github.com/simolus3/drift/releases/download/drift-2.35.0/drift_worker.js> | drift 2.35.0 | `DF0066E75363A9BED59A14EEDBBDED421C1F5910F8379812DF164716AA2E6EED` |

When upgrading the `drift` package, download both files again from the
matching release tag (drift docs: <https://drift.simonbinder.eu/platforms/web/>)
and update this table.

Notes:

- Browsers require `sqlite3.wasm` to be served with `Content-Type:
  application/wasm`; `flutter run`/`flutter build` do this by default.
- Full-speed storage on the web additionally wants
  `Cross-Origin-Opener-Policy: same-origin` and
  `Cross-Origin-Embedder-Policy: require-corp`; without them drift falls
  back to a slower (still functional) storage mode. No such headers are
  configured yet — a deployment-time decision, not a code default.
