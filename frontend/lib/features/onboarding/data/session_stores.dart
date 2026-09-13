import '../domain/local_profile.dart';

/// A session write could not be stored. Screens state it inline and keep the
/// person where they are, as the collection screens do for storage failures.
class SessionStorageException implements Exception {
  const SessionStorageException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => 'SessionStorageException: $message';
}

/// Persists whether onboarding was completed or skipped.
///
/// Reads are synchronous: implementations load before the first frame so the
/// router never renders a wrong page while waiting.
abstract interface class OnboardingStore {
  bool get hasSeenOnboarding;

  /// Idempotent. Throws [SessionStorageException] when the write fails, in
  /// which case [hasSeenOnboarding] is unchanged.
  Future<void> markOnboardingSeen();
}

/// The auth seam. M7 ships a local-first implementation; a cloud provider
/// replaces it without changing screens or routing.
///
/// Invariants every implementation keeps:
/// - [currentProfile] is non-null exactly while signed in.
/// - [lastProfile] survives [signOut], so continuing again keeps the same id.
/// - [continueOnDevice] reuses [lastProfile]'s id and creation time when one
///   exists; otherwise it creates a new profile. The given name replaces the
///   stored one, including clearing it when blank.
/// - [signOut] never deletes the profile or any collection data.
/// - A failed write throws [SessionStorageException] and changes no state.
abstract interface class AuthRepository {
  LocalProfile? get currentProfile;

  LocalProfile? get lastProfile;

  /// Throws [ArgumentError] for a name longer than
  /// [LocalProfile.maxNameLength].
  Future<LocalProfile> continueOnDevice({required String? displayName});

  Future<void> signOut();
}
