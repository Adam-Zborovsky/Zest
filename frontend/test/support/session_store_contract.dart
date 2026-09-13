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

/// A reusable contract suite exercising every invariant documented on
/// [AuthRepository]. See [runOnboardingStoreContract] for what [create],
/// [failNextWrite] and [relaunch] mean here.
///
/// [seedMalformedProfile], when given, writes unparsable data directly into
/// the backing storage for both the current and last profile before a test
/// calls [create], asserting that malformed stored JSON reads back as an
/// absent profile rather than throwing. Only meaningful for implementations
/// that serialize profiles to storage.
void runAuthRepositoryContract(
  String label, {
  required Future<AuthRepository> Function() create,
  required void Function() failNextWrite,
  Future<AuthRepository> Function()? relaunch,
  Future<void> Function()? seedMalformedProfile,
}) {
  group(label, () {
    test('starts signed out with no last profile', () async {
      final auth = await create();
      expect(auth.currentProfile, isNull);
      expect(auth.lastProfile, isNull);
    });

    test('continueOnDevice signs in with a new profile', () async {
      final auth = await create();
      final profile = await auth.continueOnDevice(displayName: 'Sam');

      expect(profile.displayName, 'Sam');
      expect(auth.currentProfile, profile);
      expect(auth.lastProfile, profile);
    });

    test(
      'continueOnDevice rejects an overlong name before writing anything',
      () async {
        final auth = await create();

        expect(
          () => auth.continueOnDevice(displayName: 'x' * 41),
          throwsArgumentError,
        );
        expect(auth.currentProfile, isNull);
        expect(auth.lastProfile, isNull);
      },
    );

    test('signOut clears currentProfile but keeps lastProfile', () async {
      final auth = await create();
      final profile = await auth.continueOnDevice(displayName: 'Sam');
      await auth.signOut();

      expect(auth.currentProfile, isNull);
      expect(auth.lastProfile, profile);
    });

    test(
      'continuing again after sign-out reuses the id and createdAt, and '
      'replaces the name, including clearing it',
      () async {
        final auth = await create();
        final first = await auth.continueOnDevice(displayName: 'Sam');
        await auth.signOut();

        final again = await auth.continueOnDevice(displayName: '  ');
        expect(again.id, first.id);
        expect(again.createdAt, first.createdAt);
        expect(again.displayName, isNull);
      },
    );

    test(
      'a failed continueOnDevice throws and leaves state unchanged',
      () async {
        final auth = await create();
        failNextWrite();

        await expectLater(
          auth.continueOnDevice(displayName: 'Sam'),
          throwsA(isA<SessionStorageException>()),
        );
        expect(auth.currentProfile, isNull);
        expect(auth.lastProfile, isNull);
      },
    );

    test('a failed signOut throws and leaves currentProfile set', () async {
      final auth = await create();
      final profile = await auth.continueOnDevice(displayName: 'Sam');
      failNextWrite();

      await expectLater(
        auth.signOut(),
        throwsA(isA<SessionStorageException>()),
      );
      expect(auth.currentProfile, profile);
    });

    if (relaunch != null) {
      test(
        'a fresh instance over the same backing sees the signed-in profile',
        () async {
          final auth = await create();
          final profile = await auth.continueOnDevice(displayName: 'Sam');

          final reopened = await relaunch();
          expect(reopened.currentProfile, profile);
          expect(reopened.lastProfile, profile);
        },
      );

      test(
        'a fresh instance over the same backing sees a signed-out state '
        'with the last profile preserved',
        () async {
          final auth = await create();
          final profile = await auth.continueOnDevice(displayName: 'Sam');
          await auth.signOut();

          final reopened = await relaunch();
          expect(reopened.currentProfile, isNull);
          expect(reopened.lastProfile, profile);
        },
      );
    }

    if (seedMalformedProfile != null) {
      test(
        'malformed stored current/last profile JSON reads back as absent',
        () async {
          await seedMalformedProfile();
          final auth = await create();

          expect(auth.currentProfile, isNull);
          expect(auth.lastProfile, isNull);
        },
      );
    }
  });
}
