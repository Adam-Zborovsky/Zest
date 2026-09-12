import 'package:flutter_test/flutter_test.dart';
import 'package:zest/features/discovery/domain/instruction_steps.dart';

void main() {
  test('splits only newline paragraphs and preserves sentence punctuation', () {
    final steps = instructionSteps(
      '1. Stir with a bar spoon, e.g. gently.\n\n2. Serve. Do not shake.',
    );
    expect(steps, [
      '1. Stir with a bar spoon, e.g. gently.',
      '2. Serve. Do not shake.',
    ]);
    expect(() => steps.add('invented'), throwsUnsupportedError);
  });

  test('returns no steps for null or blank source text', () {
    expect(instructionSteps(null), isEmpty);
    expect(instructionSteps(' \r\n '), isEmpty);
  });
}
