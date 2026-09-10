import 'package:flutter_test/flutter_test.dart';
import 'package:zest/main.dart';

void main() {
  testWidgets('shows the Zest starter screen', (tester) async {
    await tester.pumpWidget(const ZestApp());

    expect(find.text('Zest'), findsOneWidget);
    expect(
      find.text('A cocktail companion, beginning with a bright foundation.'),
      findsOneWidget,
    );
  });
}
