import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zest/app/zest_app.dart';

void main() {
  testWidgets('default shell opens discovery without a network request', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: ZestApp()));
    await tester.pumpAndSettle();

    expect(find.text('Zest'), findsOneWidget);
    expect(find.text('Discover'), findsOneWidget);
    expect(find.text('Find recipes'), findsOneWidget);
  });
}
