import '../../../support/collection_repository_contract.dart';
import '../../../support/in_memory_collection_repository.dart';

void main() {
  InMemoryCollectionRepository? repository;

  runCollectionRepositoryContract('InMemoryCollectionRepository', (now) {
    var counter = 0;
    final repo = InMemoryCollectionRepository(
      now: now,
      nextId: () => 'in-memory-${counter++}',
    );
    repository = repo;
    return repo;
  }, onTearDown: () async => repository?.dispose());
}
