import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/account_repository.dart';

/// The signed-in account repository. Overridden in `main()` with a
/// [HttpAccountRepository] loaded before `runApp`; tests override this (or,
/// more often, `sessionControllerProvider`'s dependencies through
/// `sessionTestOverrides`) with `FakeAccountRepository`.
final accountRepositoryProvider = Provider<AccountRepository>(
  (ref) => throw UnimplementedError(
    'accountRepositoryProvider is overridden in main()',
  ),
);
