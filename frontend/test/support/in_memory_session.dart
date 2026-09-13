import 'package:zest/features/onboarding/application/session_providers.dart';
import 'package:zest/features/onboarding/data/session_stores.dart';
import 'package:zest/features/onboarding/domain/local_profile.dart';

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

class InMemoryAuthRepository implements AuthRepository {
  InMemoryAuthRepository({
    LocalProfile? current,
    LocalProfile? last,
    DateTime Function()? clock,
    String Function()? newId,
  }) : _current = current,
       _last = last ?? current,
       _clock = clock ?? DateTime.now,
       _newId = newId ?? _sequentialIds();

  LocalProfile? _current;
  LocalProfile? _last;
  final DateTime Function() _clock;
  final String Function() _newId;

  /// When true, the next write throws [SessionStorageException] and resets.
  bool failNextWrite = false;

  @override
  LocalProfile? get currentProfile => _current;

  @override
  LocalProfile? get lastProfile => _last;

  @override
  Future<LocalProfile> continueOnDevice({required String? displayName}) async {
    final name = LocalProfile.normalizeDisplayName(displayName);
    _throwIfFailing();
    final previous = _last;
    final profile = previous == null
        ? LocalProfile(id: _newId(), displayName: name, createdAt: _clock())
        : previous.withDisplayName(name);
    _current = profile;
    _last = profile;
    return profile;
  }

  @override
  Future<void> signOut() async {
    _throwIfFailing();
    _current = null;
  }

  void _throwIfFailing() {
    if (!failNextWrite) return;
    failNextWrite = false;
    throw const SessionStorageException('Synthetic auth write failure');
  }

  static String Function() _sequentialIds() {
    var next = 0;
    return () => 'profile-${++next}';
  }
}

/// A synthetic signed-in profile for tests that start inside the app.
LocalProfile syntheticProfile({String? displayName = 'Sam'}) => LocalProfile(
  id: 'profile-test',
  displayName: displayName,
  createdAt: DateTime.utc(2026, 9, 1),
);

/// Session overrides for any test that pumps `ZestApp`. The defaults put the
/// person inside the app, so tests written before M7 keep landing on home.
///
/// Typed `List<dynamic>` for the same Riverpod 3 reason as
/// `collectionTestOverrides`.
List<dynamic> sessionTestOverrides({
  bool onboardingSeen = true,
  bool signedIn = true,
  OnboardingStore? onboarding,
  AuthRepository? auth,
}) => [
  onboardingStoreProvider.overrideWithValue(
    onboarding ?? InMemoryOnboardingStore(seen: onboardingSeen),
  ),
  authRepositoryProvider.overrideWithValue(
    auth ??
        InMemoryAuthRepository(current: signedIn ? syntheticProfile() : null),
  ),
];
