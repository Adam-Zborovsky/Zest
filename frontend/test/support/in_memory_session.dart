import 'package:zest/features/account/application/account_providers.dart';
import 'package:zest/features/account/data/account_repository.dart';
import 'package:zest/features/account/domain/account.dart';
import 'package:zest/features/collection/sync/sync_contract.dart';
import 'package:zest/features/collection/sync/sync_providers.dart';
import 'package:zest/features/onboarding/application/session_providers.dart';
import 'package:zest/features/onboarding/data/session_stores.dart';

import 'fake_account_repository.dart';

class InMemoryOnboardingStore implements OnboardingStore {
  InMemoryOnboardingStore({bool seen = false}) : _seen = seen;

  bool _seen;

  /// When true, the next write throws [SessionStorageException] and resets.
  bool failNextWrite = false;

  @override
  bool get hasSeenOnboarding => _seen;

  @override
  Future<void> markOnboardingSeen() async {
    if (failNextWrite) {
      failNextWrite = false;
      throw const SessionStorageException('Synthetic onboarding write failure');
    }
    _seen = true;
  }
}

/// A [CollectionSync] that never runs a pass and never syncs. The default
/// for widget and app tests, which do not exercise sync behavior directly
/// (see `test/features/collection/sync` for that).
final class NoOpCollectionSync implements CollectionSync {
  @override
  SyncStatus get status => const SyncStatus(SyncPhase.idle);

  @override
  Stream<SyncStatus> watchStatus() => Stream.value(status);

  @override
  Future<void> syncNow() async {}

  @override
  void scheduleAfterLocalWrite() {}

  @override
  Future<void> pushBeforeSignOut() async {}
}

/// Session overrides for any test that pumps `ZestApp`. The defaults put the
/// person inside the app, so tests written before M8 keep landing on home.
///
/// Typed `List<dynamic>` for the same Riverpod 3 reason as
/// `collectionTestOverrides`.
List<dynamic> sessionTestOverrides({
  bool onboardingSeen = true,
  bool signedIn = true,
  OnboardingStore? onboarding,
  AccountRepository? account,
  CollectionSync? sync,
  Account? signedInAccount,
}) => [
  onboardingStoreProvider.overrideWithValue(
    onboarding ?? InMemoryOnboardingStore(seen: onboardingSeen),
  ),
  accountRepositoryProvider.overrideWithValue(
    account ??
        FakeAccountRepository(
          current: signedIn ? (signedInAccount ?? syntheticAccount()) : null,
        ),
  ),
  collectionSyncProvider.overrideWithValue(sync ?? NoOpCollectionSync()),
];
