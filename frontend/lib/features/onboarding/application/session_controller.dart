import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../account/data/account_repository.dart';
import '../../account/domain/account.dart';
import '../../collection/sync/sync_contract.dart';
import '../data/session_stores.dart';
import '../domain/launch_destination.dart';

/// The one object routing and the onboarding and login screens share. It is
/// the router's `refreshListenable`: every successful session change notifies,
/// and go_router re-runs [launchRedirect].
///
/// M8 wraps [AccountRepository] instead of M7's local-only `AuthRepository`;
/// "Continue on this device" is gone, replaced by [register] and [signIn].
/// [signOut] attempts one final sync push first (see `docs/ACCOUNTS.md`).
class SessionController extends ChangeNotifier {
  SessionController({
    required OnboardingStore onboarding,
    required AccountRepository account,
    required CollectionSync sync,
  }) : _onboarding = onboarding,
       _account = account,
       _sync = sync;

  final OnboardingStore _onboarding;
  final AccountRepository _account;
  final CollectionSync _sync;

  LaunchDestination get destination => resolveLaunch(
    onboardingSeen: _onboarding.hasSeenOnboarding,
    signedIn: _account.currentAccount != null,
  );

  bool get hasSeenOnboarding => _onboarding.hasSeenOnboarding;

  Account? get account => _account.currentAccount;

  /// Called by Skip and by finishing the last onboarding page.
  Future<void> markOnboardingSeen() async {
    if (_onboarding.hasSeenOnboarding) return;
    await _onboarding.markOnboardingSeen();
    notifyListeners();
  }

  /// Signing in also records onboarding as seen, so a later sign-out lands on
  /// login rather than replaying onboarding — even for someone who reached
  /// login by a direct link.
  Future<Account> register({
    required String email,
    required String password,
  }) => _authenticate(() => _account.register(email: email, password: password));

  Future<Account> signIn({required String email, required String password}) =>
      _authenticate(() => _account.signIn(email: email, password: password));

  Future<Account> _authenticate(Future<Account> Function() action) async {
    await _onboarding.markOnboardingSeen();
    final account = await action();
    notifyListeners();
    // Fire-and-forget: SyncEngine reports failure through its own status
    // stream, never by throwing into a sign-in/register call.
    unawaited(_sync.syncNow());
    return account;
  }

  Future<void> signOut() async {
    // One final push attempt to minimize data loss from wiping unsynced
    // rows if a different account signs in on this device next; failure is
    // silent and CollectionSync.pushBeforeSignOut never throws (see its doc
    // comment on the contract and SyncEngine's implementation).
    await _sync.pushBeforeSignOut();
    await _account.signOut();
    notifyListeners();
  }

  /// Called when an authenticated call answers 401; clears the session
  /// without a network call, then notifies so the router moves to login.
  Future<void> expireSession() async {
    await _account.expireSession();
    notifyListeners();
  }
}
