import '../../../support/in_memory_session.dart';
import '../../../support/session_store_contract.dart';

void main() {
  InMemoryOnboardingStore? onboarding;
  runOnboardingStoreContract(
    'InMemoryOnboardingStore',
    create: () async => onboarding = InMemoryOnboardingStore(),
    failNextWrite: () => onboarding!.failNextWrite = true,
  );

  InMemoryAuthRepository? auth;
  runAuthRepositoryContract(
    'InMemoryAuthRepository',
    create: () async {
      var counter = 0;
      return auth = InMemoryAuthRepository(
        clock: () => DateTime.utc(2026, 9, 13),
        newId: () => 'in-memory-${counter++}',
      );
    },
    failNextWrite: () => auth!.failNextWrite = true,
  );
}
