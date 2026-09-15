import 'dart:async';

import 'package:zest/core/design/zest_tokens.dart';

/// Runs before every test file under test/. The constellation float loops
/// forever by design, which would keep `pumpAndSettle` from ever settling,
/// so the suite runs without ambient motion; tests that exercise the float
/// turn it back on locally.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  ZestMotion.ambientMotion = false;
  await testMain();
}
