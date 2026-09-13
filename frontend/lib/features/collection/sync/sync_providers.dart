import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'sync_contract.dart';

/// The base URL for the account/sync HTTP API, resolved from
/// `ZEST_API_BASE_URL` in `main()`. Overridden in tests that construct a
/// real [HttpSyncApi]; most tests instead override [collectionSyncProvider]
/// directly with a no-op fake.
final syncBaseUrlProvider = Provider<Uri>(
  (ref) => throw UnimplementedError('syncBaseUrlProvider is overridden in main()'),
);

final syncHttpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

/// The sync engine driving the local collection database against the
/// server. Overridden in `main()` with a real [SyncEngine]; tests override
/// this with a no-op [CollectionSync] via `sessionTestOverrides`.
final collectionSyncProvider = Provider<CollectionSync>(
  (ref) => throw UnimplementedError(
    'collectionSyncProvider is overridden in main()',
  ),
);

/// Watches [collectionSyncProvider]'s status stream, for the profile sheet.
final syncStatusProvider = StreamProvider<SyncStatus>(
  (ref) => ref.watch(collectionSyncProvider).watchStatus(),
);
