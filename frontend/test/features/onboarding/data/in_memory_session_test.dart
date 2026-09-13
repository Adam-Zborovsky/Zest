import '../../../support/in_memory_session.dart';
import '../../../support/session_store_contract.dart';

void main() {
  InMemoryOnboardingStore? onboarding;
  runOnboardingStoreContract(
    'InMemoryOnboardingStore',
    create: () async => onboarding = InMemoryOnboardingStore(),
    failNextWrite: () => onboarding!.failNextWrite = true,
  );
}
