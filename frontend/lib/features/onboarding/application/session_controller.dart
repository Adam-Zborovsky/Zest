import 'package:flutter/foundation.dart';

import '../data/session_stores.dart';
import '../domain/launch_destination.dart';
import '../domain/local_profile.dart';

/// The one object routing and the onboarding and login screens share. It is
/// the router's `refreshListenable`: every successful session change notifies,
/// and go_router re-runs [launchRedirect].
class SessionController extends ChangeNotifier {
  SessionController({
    required OnboardingStore onboarding,
    required AuthRepository auth,
  }) : _onboarding = onboarding,
       _auth = auth;

  final OnboardingStore _onboarding;
  final AuthRepository _auth;

  LaunchDestination get destination => resolveLaunch(
    onboardingSeen: _onboarding.hasSeenOnboarding,
    signedIn: _auth.currentProfile != null,
  );

  bool get hasSeenOnboarding => _onboarding.hasSeenOnboarding;

  LocalProfile? get profile => _auth.currentProfile;

  /// Prefills the login name after a sign-out.
  LocalProfile? get lastProfile => _auth.lastProfile;

  /// Called by Skip and by finishing the last onboarding page.
  Future<void> markOnboardingSeen() async {
    if (_onboarding.hasSeenOnboarding) return;
    await _onboarding.markOnboardingSeen();
    notifyListeners();
  }

  /// Signing in also records onboarding as seen, so a later sign-out lands on
  /// login rather than replaying onboarding — even for someone who reached
  /// login by a direct link.
  Future<LocalProfile> continueOnDevice({required String? displayName}) async {
    await _onboarding.markOnboardingSeen();
    final profile = await _auth.continueOnDevice(displayName: displayName);
    notifyListeners();
    return profile;
  }

  Future<void> signOut() async {
    await _auth.signOut();
    notifyListeners();
  }
}
