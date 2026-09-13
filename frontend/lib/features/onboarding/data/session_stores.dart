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
