import 'package:flutter_test/flutter_test.dart';
import 'package:zest/app/zest_app.dart';

void main() {
  testWidgets('gallery-disabled shell keeps the Zest foundation', (
    tester,
  ) async {
    await tester.pumpWidget(const ZestApp(showGallery: false));

    expect(find.text('Zest'), findsOneWidget);
    expect(find.text('A cocktail companion.'), findsOneWidget);
  });
}
