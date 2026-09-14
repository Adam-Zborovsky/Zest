import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:zest/app/zest_app.dart';
import 'package:zest/features/discovery/application/discovery_providers.dart';
import 'package:zest/features/discovery/data/cocktail_db_client.dart';
import 'package:zest/features/home_bar/application/home_bar_providers.dart';

import '../../../support/collection_test_overrides.dart';
import '../../../support/discovery_fixtures.dart';
import '../../../support/in_memory_home_bar_repository.dart';
import '../../../support/in_memory_session.dart';
import '../../../support/load_fonts.dart';

void main() {
  setUpAll(loadZestFonts);

  for (final specimen in [
    (
      name: 'discovery-mobile',
      location: '/discover',
      size: const Size(412, 915),
    ),
    (
      name: 'discovery-results',
      location: '/discover?mode=name&q=Paper',
      size: const Size(412, 1250),
    ),
    (
      name: 'recipe-detail',
      location: '/discover/recipe/99001',
      size: const Size(412, 1350),
    ),
  ]) {
    testWidgets('${specimen.name} Botanical Play render', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = specimen.size;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final transport = MockClient(
        (_) async => discoveryResponse(discoveryRecipes(1)),
      );
      final client = CocktailDbClient(client: transport);
      final homeBar = InMemoryHomeBarRepository();
      addTearDown(() {
        client.close();
        transport.close();
      });
      addTearDown(homeBar.dispose);
      const capture = ValueKey('m3-capture');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            cocktailDbClientProvider.overrideWithValue(client),
            homeBarRepositoryProvider.overrideWithValue(homeBar),
            ...collectionTestOverrides(),
            ...sessionTestOverrides(),
          ],
          child: RepaintBoundary(
            key: capture,
            child: ZestApp(initialLocation: specimen.location),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byKey(capture),
        matchesGoldenFile('goldens/${specimen.name}.png'),
      );
      final semantics = tester.ensureSemantics();
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      semantics.dispose();
    });
  }
}
