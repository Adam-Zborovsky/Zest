/// Where a launch or a session change sends the person.
///
/// The M7 roadmap enumerates the returning-user states:
/// - fresh user → onboarding;
/// - onboarding seen and signed in → app;
/// - Skip pressed, never signed in → login (Skip records "onboarding seen",
///   not "signed in");
/// - signed out after having signed in → login.
enum LaunchDestination { onboarding, login, app }

LaunchDestination resolveLaunch({
  required bool onboardingSeen,
  required bool signedIn,
}) {
  if (signedIn) return LaunchDestination.app;
  return onboardingSeen
      ? LaunchDestination.login
      : LaunchDestination.onboarding;
}

abstract final class SessionRoutes {
  static const home = '/';
  static const onboarding = '/onboarding';
  static const login = '/login';
}

/// The go_router redirect for a destination, or null to stay.
///
/// Signed-out people may move freely between onboarding and login (Skip goes
/// to login; login offers a tour replay), and every other location sends
/// them to their gate. Signed-in people never see either gate.
String? launchRedirect(LaunchDestination destination, Uri location) {
  final path = location.path;
  final atGate = path == SessionRoutes.onboarding || path == SessionRoutes.login;
  return switch (destination) {
    LaunchDestination.app => atGate ? SessionRoutes.home : null,
    LaunchDestination.login => atGate ? null : SessionRoutes.login,
    LaunchDestination.onboarding => atGate ? null : SessionRoutes.onboarding,
  };
}
