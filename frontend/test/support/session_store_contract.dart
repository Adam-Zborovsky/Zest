import 'package:flutter_test/flutter_test.dart';
import 'package:zest/features/onboarding/data/session_stores.dart';

/// A reusable contract suite exercising every invariant documented on
/// [OnboardingStore]. Run it against every implementation so screens built
/// against one behave the same way against the others.
///
/// [create] builds a fresh store for one test — "fresh" for the prefs
/// implementation means unseeded backing storage, matching a first launch.
/// [failNextWrite] arms the next write to throw [SessionStorageException].
/// [relaunch], when given, builds a new store instance over the *same*
/// backing [create] used (a real relaunch, for implementations that persist)
/// and adds a test asserting the seen flag survives it. Implementations with
/// no persistent backing (the in-memory fakes) omit it.
void runOnboardingStoreContract(
  String label, {
  required Future<OnboardingStore> Function() create,
  required void Function() failNextWrite,
  Future<OnboardingStore> Function()? relaunch,
}) {
  group(label, () {
    test('starts unseen', () async {
      expect((await create()).hasSeenOnboarding, isFalse);
    });

    test('markOnboardingSeen sets the flag and is idempotent', () async {
      final store = await create();
      await store.markOnboardingSeen();
      expect(store.hasSeenOnboarding, isTrue);

      await store.markOnboardingSeen();
      expect(store.hasSeenOnboarding, isTrue);
    });

    test('a failed write throws and leaves the flag unchanged', () async {
      final store = await create();
      failNextWrite();

      await expectLater(
        store.markOnboardingSeen(),
        throwsA(isA<SessionStorageException>()),
      );
      expect(store.hasSeenOnboarding, isFalse);
    });

    if (relaunch != null) {
      test(
        'a fresh store instance over the same backing sees a seen flag '
        'written earlier',
        () async {
          await (await create()).markOnboardingSeen();
          expect((await relaunch()).hasSeenOnboarding, isTrue);
        },
      );
    }
  });
}
