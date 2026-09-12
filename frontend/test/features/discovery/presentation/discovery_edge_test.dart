import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zest/app/zest_app.dart';
import 'package:zest/features/discovery/application/discovery_providers.dart';
import 'package:zest/features/discovery/data/cocktail_db_client.dart';
import 'package:zest/features/discovery/presentation/discovery_widgets.dart';

import '../../../support/discovery_fixtures.dart';
import '../../../support/load_fonts.dart';

const _oneTransparentPixel = <int>[
  137,
  80,
  78,
  71,
  13,
  10,
  26,
  10,
  0,
  0,
  0,
  13,
  73,
  72,
  68,
  82,
  0,
  0,
  0,
  1,
  0,
  0,
  0,
  1,
  8,
  6,
  0,
  0,
  0,
  31,
  21,
  196,
  137,
  0,
  0,
  0,
  13,
  73,
  68,
  65,
  84,
  8,
  215,
  99,
  248,
  207,
  192,
  240,
  31,
  0,
  5,
  0,
  1,
  255,
  137,
  153,
  61,
  29,
  0,
  0,
  0,
  0,
  73,
  69,
  78,
  68,
  174,
  66,
  96,
  130,
];

class _ControlledImageProvider extends ImageProvider<_ControlledImageProvider> {
  const _ControlledImageProvider(this.image);

  final Future<ImageInfo> image;

  @override
  Future<_ControlledImageProvider> obtainKey(
    ImageConfiguration configuration,
  ) => SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(
    _ControlledImageProvider key,
    ImageDecoderCallback decode,
  ) => OneFrameImageStreamCompleter(image);
}

Future<ImageInfo> _syntheticImage() async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawColor(const Color(0xff719b5b), ui.BlendMode.src);
  return ImageInfo(image: await recorder.endRecording().toImage(1, 1));
}

Future<void> _pumpApp(
  WidgetTester tester, {
  required Future<http.Response> Function(http.Request) respond,
  String? location,
  ImageProvider Function(String)? imageProvider,
}) async {
  final transport = MockClient(respond);
  final client = CocktailDbClient(client: transport);
  addTearDown(() {
    client.close();
    transport.close();
  });
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        cocktailDbClientProvider.overrideWithValue(client),
        if (imageProvider != null)
          recipeImageProvider.overrideWithValue(imageProvider),
      ],
      child: ZestApp(initialLocation: location),
    ),
  );
  await tester.pumpAndSettle();
}

GoRouter _router(WidgetTester tester) =>
    GoRouter.of(tester.element(find.byType(Scaffold).last));

Finder _liveText(String text) => find.ancestor(
  of: find.text(text),
  matching: find.byWidgetPredicate(
    (widget) => widget is Semantics && widget.properties.liveRegion == true,
  ),
);

void main() {
  setUpAll(loadZestFonts);

  for (final location in [
    '/discover?mode=surprise&q=Paper',
    '/discover?mode=name',
    '/discover?mode=name&mode=ingredient&q=Paper',
  ]) {
    testWidgets('malformed discovery link $location is branded and offline', (
      tester,
    ) async {
      var requests = 0;
      await _pumpApp(
        tester,
        location: location,
        respond: (_) async {
          requests++;
          return discoveryResponse(null);
        },
      );
      expect(find.text('That search link is not valid'), findsOneWidget);
      expect(requests, 0);
    });
  }

  testWidgets(
    'a directly opened detail returns to its query without re-search',
    (tester) async {
      final requests = <Uri>[];
      await _pumpApp(
        tester,
        location: '/discover/recipe/99001?mode=ingredient&q=Imaginary%20leaf',
        respond: (request) async {
          requests.add(request.url);
          return discoveryResponse([discoveryRecipe()]);
        },
      );
      expect(
        requests.where((uri) => uri.queryParameters['i'] == '99001'),
        hasLength(1),
      );
      await tester.tap(find.byTooltip('Back to discovery'));
      await tester.pumpAndSettle();
      expect(_router(tester).state.uri.queryParameters, {
        'mode': 'ingredient',
        'q': 'Imaginary leaf',
      });
      expect(requests, hasLength(2));
    },
  );

  testWidgets('result controls have distinct accessible recipe names', (
    tester,
  ) async {
    await _pumpApp(
      tester,
      location: '/discover?mode=name&q=Paper',
      respond: (_) async => discoveryResponse(discoveryRecipes(2)),
    );
    final semantics = tester.ensureSemantics();
    expect(
      find.bySemanticsLabel('View recipe: Paper Garden 1'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('View recipe: Paper Garden 2'),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('result count and empty outcome are live regions, not controls', (
    tester,
  ) async {
    await _pumpApp(
      tester,
      location: '/discover?mode=name&q=Paper',
      respond: (request) async => discoveryResponse(
        request.url.queryParameters['s'] == 'None' ? null : discoveryRecipes(1),
      ),
    );
    expect(_liveText('1 recipe returned by TheCocktailDB.'), findsOneWidget);
    expect(
      find.widgetWithText(FilledButton, '1 recipe returned by TheCocktailDB.'),
      findsNothing,
    );

    _router(tester).go('/discover?mode=name&q=None');
    await tester.pumpAndSettle();
    expect(_liveText('No recipes found'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'No recipes found'), findsNothing);
  });

  testWidgets(
    'recipe images use injected valid source imagery and reject unsafe URLs',
    (tester) async {
      var providerCalls = 0;
      final completedImage = Completer<ImageInfo>();
      await _pumpApp(
        tester,
        location: '/discover/recipe/99001',
        imageProvider: (_) {
          providerCalls++;
          return _ControlledImageProvider(completedImage.future);
        },
        respond: (_) async => discoveryResponse([
          discoveryRecipe(
            thumbnailUrl: 'https://images.example.test/paper.png',
          ),
        ]),
      );
      expect(providerCalls, 1);
      completedImage.complete(await _syntheticImage());
      await tester.pumpAndSettle();
      expect(find.text('Image: TheCocktailDB'), findsOneWidget);
      expect(find.text('No source image'), findsNothing);
      expect(find.text('Source image unavailable'), findsNothing);

      providerCalls = 0;
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            recipeImageProvider.overrideWithValue((_) {
              providerCalls++;
              return MemoryImage(Uint8List.fromList(_oneTransparentPixel));
            }),
          ],
          child: const MaterialApp(
            home: RecipeImage(
              url: 'https://user:password@images.example.test/paper.png',
              name: 'Unsafe',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(providerCalls, 0);
      expect(find.text('No source image'), findsOneWidget);
    },
  );

  testWidgets(
    'image loading and decode failure retain authored fallbacks at 320px 3x',
    (tester) async {
      tester.view.physicalSize = const Size(960, 2160);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final failedImage = Completer<ImageInfo>();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            recipeImageProvider.overrideWithValue(
              (_) => _ControlledImageProvider(failedImage.future),
            ),
          ],
          child: const MaterialApp(
            home: RecipeImage(
              url: 'https://images.example.test/failing.png',
              name: 'Failing',
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Loading source image'), findsOneWidget);
      failedImage.completeError(StateError('Synthetic image failure'));
      await tester.pumpAndSettle();
      expect(find.text('Source image unavailable'), findsOneWidget);
    },
  );

  for (final feature in [
    const FakeAccessibilityFeatures(disableAnimations: true),
    const FakeAccessibilityFeatures(accessibleNavigation: true),
  ]) {
    testWidgets('router transition is zero duration with $feature', (
      tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue = feature;
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      // Router-transition test: pin discovery explicitly rather than ride
      // the old `/` redirect (since M5, `/` is home).
      await _pumpApp(
        tester,
        location: '/discover',
        respond: (_) async => discoveryResponse(null),
      );
      final page = ModalRoute.of(
        tester.element(find.byType(Scaffold).last),
      )!.settings;
      if (page is! CustomTransitionPage<void>) {
        fail('Expected a CustomTransitionPage, got ${page.runtimeType}.');
      }
      expect(page.transitionDuration, Duration.zero);
      expect(page.reverseTransitionDuration, Duration.zero);
    });
  }
}
