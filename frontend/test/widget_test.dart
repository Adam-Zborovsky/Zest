import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zest/app/zest_app.dart';

import 'support/catalog_wiring.dart';
import 'support/collection_test_overrides.dart';
import 'support/in_memory_session.dart';

void main() {
  testWidgets('default shell opens home with the constellation lead without '
      'a network request', (tester) async {
    // Home reads the on-device catalog; tests inject the in-memory store.
    final database = openInMemoryCatalog();
    addTearDown(database.close);
    final source = FakeCatalogLetterSource(letters: {});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...catalogTestOverrides(database: database, source: source),
          ...collectionTestOverrides(),
          ...sessionTestOverrides(),
        ],
        child: const ZestApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Zest'), findsOneWidget);
    expect(find.text('The Ingredient Constellation'), findsOneWidget);
    expect(find.text('Find recipes'), findsOneWidget);
  });
}
