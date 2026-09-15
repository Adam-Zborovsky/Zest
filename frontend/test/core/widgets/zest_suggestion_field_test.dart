import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zest/core/design/zest_theme.dart';
import 'package:zest/core/widgets/zest_suggestion_field.dart';

import '../../support/load_fonts.dart';

/// Synthetic options: plain strings are enough to exercise a generic
/// [ZestSuggestionField<T>] without any catalog dependency.
const _fruits = ['Gin', 'Gin Fizz', 'Ginger Beer', 'Vodka', 'Rum'];

/// A caption used to exercise the default option row's trailing text.
String _captionFor(String option) => '${option.length} letters';

/// Pumps [field] inside a themed app at a known, generous viewport so tap
/// coordinates and layout assertions are reliable regardless of the test
/// runner's own default surface size.
Future<void> _pump(
  WidgetTester tester,
  Widget field, {
  Size viewSize = const Size(420, 900),
  double textScale = 1,
}) async {
  tester.view.physicalSize = viewSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: ZestTheme.build(),
      debugShowCheckedModeBanner: false,
      // MaterialApp derives its own MediaQuery from the real view, so text
      // scale must be injected through `builder`, not an ancestor MediaQuery.
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: Align(
          alignment: Alignment.topCenter,
          child: Padding(padding: const EdgeInsets.all(16), child: field),
        ),
      ),
    ),
  );
}

ZestSuggestionField<String> _field({
  Key? key,
  TextEditingController? controller,
  FocusNode? focusNode,
  List<String> options = _fruits,
  ValueChanged<String>? onSelected,
  ValueChanged<String>? onFieldSubmitted,
  bool replaceTextOnSelect = true,
  int maxVisible = 8,
  ZestSuggestionFieldStyle style = ZestSuggestionFieldStyle.plain,
  Duration announceDebounce = const Duration(milliseconds: 300),
  String? Function(String)? captionFor,
  Widget Function(BuildContext, String, bool)? optionBuilder,
  FormFieldValidator<String>? validator,
}) => ZestSuggestionField<String>(
  key: key,
  controller: controller,
  focusNode: focusNode,
  label: 'Find an ingredient',
  hintText: 'For example, gin',
  validator: validator,
  suggestionsFor: (query) => [
    for (final option in options)
      if (option.toLowerCase().contains(query.trim().toLowerCase())) option,
  ],
  labelFor: (option) => option,
  semanticLabelFor: (option) => '$option, ${_captionFor(option)}',
  captionFor: captionFor,
  optionBuilder: optionBuilder,
  onSelected: onSelected ?? (_) {},
  onFieldSubmitted: onFieldSubmitted,
  replaceTextOnSelect: replaceTextOnSelect,
  maxVisible: maxVisible,
  style: style,
  announceDebounce: announceDebounce,
);

// Finding #9: the suggestion-count live region is visually hidden — no
// `Text` descendant to find — so its announcement is read from the
// `Semantics` node's own `label` instead of the render tree.
Finder _liveText(String text) => find.byWidgetPredicate(
  (widget) =>
      widget is Semantics &&
      widget.properties.liveRegion == true &&
      widget.properties.label == text,
);

void main() {
  setUpAll(loadZestFonts);

  group('opening and closing', () {
    testWidgets('opens on typing with matches, closes for empty query', (
      tester,
    ) async {
      await _pump(tester, _field());
      expect(find.text('Gin Fizz'), findsNothing);

      await tester.enterText(find.byType(TextFormField), 'gin');
      await tester.pump();
      expect(find.text('Gin Fizz'), findsOneWidget);
      expect(find.text('Ginger Beer'), findsOneWidget);
      expect(find.text('Vodka'), findsNothing);

      await tester.enterText(find.byType(TextFormField), '');
      await tester.pump();
      expect(find.text('Gin Fizz'), findsNothing);
    });

    testWidgets('stays closed when nothing matches', (tester) async {
      await _pump(tester, _field());
      await tester.enterText(find.byType(TextFormField), 'zzz');
      await tester.pump();
      expect(find.text('Gin Fizz'), findsNothing);
      expect(find.text('Vodka'), findsNothing);
    });

    testWidgets('Escape dismisses without clearing the text', (tester) async {
      await _pump(tester, _field());
      await tester.enterText(find.byType(TextFormField), 'gin');
      await tester.pump();
      expect(find.text('Gin Fizz'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(find.text('Gin Fizz'), findsNothing);
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField))
            .controller!
            .text,
        'gin',
      );
    });

    testWidgets('tapping outside dismisses the options', (tester) async {
      await _pump(tester, _field());
      await tester.enterText(find.byType(TextFormField), 'gin');
      await tester.pump();
      expect(find.text('Gin Fizz'), findsOneWidget);

      // Well below the field and its options panel, but still inside the
      // 900-tall viewport `_pump` sets up.
      await tester.tapAt(const Offset(10, 800));
      await tester.pump();
      expect(find.text('Gin Fizz'), findsNothing);
    });
  });

  group('keyboard', () {
    testWidgets(
      'Up/Down moves the highlight and clamps at the first/last option',
      (tester) async {
        await _pump(tester, _field());
        await tester.enterText(find.byType(TextFormField), 'gin');
        await tester.pump();

        Semantics highlightedRow() => tester
            .widgetList<Semantics>(find.byType(Semantics))
            .firstWhere((s) => s.properties.selected == true);

        // Nothing highlighted yet: no option carries selected:true.
        expect(
          tester
              .widgetList<Semantics>(find.byType(Semantics))
              .where((s) => s.properties.selected == true),
          isEmpty,
        );

        // The first Down both marks the highlight as touched and moves the
        // framework's own tracked index on from 0 ('Gin'), landing on
        // 'Gin Fizz'.
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump();
        expect(highlightedRow().properties.label, contains('Gin Fizz,'));

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump();
        expect(highlightedRow().properties.label, contains('Ginger Beer,'));

        // Clamp: one more Down stays on the last option.
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump();
        expect(highlightedRow().properties.label, contains('Ginger Beer,'));

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pump();
        expect(highlightedRow().properties.label, contains('Gin Fizz,'));

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pump();
        // Clamp at the first option too.
        expect(highlightedRow().properties.label, contains('Gin,'));

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pump();
        expect(highlightedRow().properties.label, contains('Gin,'));
      },
    );

    testWidgets('Enter commits the highlighted option', (tester) async {
      String? selected;
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      await _pump(
        tester,
        _field(focusNode: focusNode, onSelected: (v) => selected = v),
      );
      await tester.enterText(find.byType(TextFormField), 'gin');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();

      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();

      expect(selected, 'Gin Fizz');
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField))
            .controller!
            .text,
        'Gin Fizz',
      );
      // The panel closed after selection: no other option row survives.
      expect(find.text('Ginger Beer'), findsNothing);
      expect(focusNode.hasFocus, isTrue); // focus stayed in the field
    });

    testWidgets(
      'Enter with no explicit highlight falls through to onFieldSubmitted',
      (tester) async {
        String? selected;
        String? submitted;
        await _pump(
          tester,
          _field(
            onSelected: (v) => selected = v,
            onFieldSubmitted: (v) => submitted = v,
          ),
        );
        await tester.enterText(find.byType(TextFormField), 'gin');
        await tester.pump();

        await tester.testTextInput.receiveAction(TextInputAction.search);
        await tester.pump();

        expect(selected, isNull);
        expect(submitted, 'gin');
      },
    );

    testWidgets('a fresh keystroke resets the highlight for the new options', (
      tester,
    ) async {
      String? selected;
      String? submitted;
      await _pump(
        tester,
        _field(
          onSelected: (v) => selected = v,
          onFieldSubmitted: (v) => submitted = v,
        ),
      );
      await tester.enterText(find.byType(TextFormField), 'gin');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();

      // Typing again should require a fresh Up/Down before Enter selects.
      await tester.enterText(find.byType(TextFormField), 'ginger');
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();

      expect(selected, isNull);
      expect(submitted, 'ginger');
    });
  });

  group('pointer', () {
    testWidgets('tapping an option selects it', (tester) async {
      String? selected;
      await _pump(tester, _field(onSelected: (v) => selected = v));
      await tester.enterText(find.byType(TextFormField), 'gin');
      await tester.pump();

      await tester.tap(find.text('Gin Fizz'));
      await tester.pump();

      expect(selected, 'Gin Fizz');
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField))
            .controller!
            .text,
        'Gin Fizz',
      );
    });

    testWidgets('replaceTextOnSelect false keeps the typed text', (
      tester,
    ) async {
      String? selected;
      await _pump(
        tester,
        _field(onSelected: (v) => selected = v, replaceTextOnSelect: false),
      );
      await tester.enterText(find.byType(TextFormField), 'gin');
      await tester.pump();

      await tester.tap(find.text('Gin Fizz'));
      await tester.pump();

      expect(selected, 'Gin Fizz');
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField))
            .controller!
            .text,
        'gin',
      );
    });
  });

  group('form integration', () {
    testWidgets('validates and submits inside a Form', (tester) async {
      final formKey = GlobalKey<FormState>();
      String? submitted;
      await _pump(
        tester,
        Form(
          key: formKey,
          child: _field(
            onFieldSubmitted: (v) => submitted = v,
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Enter a name to start your search.'
                : null,
          ),
        ),
      );

      expect(formKey.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.text('Enter a name to start your search.'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField), 'gin');
      await tester.pump();
      expect(formKey.currentState!.validate(), isTrue);

      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();
      expect(submitted, 'gin');
    });
  });

  group('semantics and announcements', () {
    testWidgets('options expose button semantics with the given labels', (
      tester,
    ) async {
      await _pump(tester, _field());
      await tester.enterText(find.byType(TextFormField), 'gin');
      await tester.pump();

      final row = tester
          .widgetList<Semantics>(find.byType(Semantics))
          .firstWhere(
            (s) => s.properties.label?.startsWith('Gin Fizz,') ?? false,
          );
      expect(row.properties.button, isTrue);
      expect(row.properties.label, 'Gin Fizz, 8 letters');
    });

    testWidgets('announces the suggestion count after the debounce', (
      tester,
    ) async {
      await _pump(
        tester,
        _field(announceDebounce: const Duration(milliseconds: 50)),
      );
      await tester.enterText(find.byType(TextFormField), 'gin');
      await tester.pump();
      // Before the debounce elapses, nothing has been announced yet.
      expect(_liveText('3 suggestions'), findsNothing);

      await tester.pump(const Duration(milliseconds: 60));
      expect(_liveText('3 suggestions'), findsOneWidget);
    });

    testWidgets(
      'rapid keystrokes only announce once, after the person stops',
      (tester) async {
        await _pump(
          tester,
          _field(announceDebounce: const Duration(milliseconds: 100)),
        );
        await tester.enterText(find.byType(TextFormField), 'g');
        await tester.pump(const Duration(milliseconds: 40));
        await tester.enterText(find.byType(TextFormField), 'gi');
        await tester.pump(const Duration(milliseconds: 40));
        await tester.enterText(find.byType(TextFormField), 'gin');
        await tester.pump(const Duration(milliseconds: 40));
        // Still within the debounce window of the final keystroke.
        expect(_liveText('3 suggestions'), findsNothing);

        await tester.pump(const Duration(milliseconds: 70));
        expect(_liveText('3 suggestions'), findsOneWidget);
      },
    );

    testWidgets(
      'announces "No suggestions" once a non-empty query yields none',
      (tester) async {
        await _pump(
          tester,
          _field(announceDebounce: const Duration(milliseconds: 30)),
        );
        await tester.enterText(find.byType(TextFormField), 'zzz');
        await tester.pump(const Duration(milliseconds: 40));
        expect(_liveText('No suggestions'), findsOneWidget);
      },
    );

    testWidgets('an empty query never announces', (tester) async {
      await _pump(
        tester,
        _field(announceDebounce: const Duration(milliseconds: 30)),
      );
      await tester.enterText(find.byType(TextFormField), 'gin');
      await tester.pump(const Duration(milliseconds: 40));
      await tester.enterText(find.byType(TextFormField), '');
      await tester.pump(const Duration(milliseconds: 40));
      expect(_liveText('3 suggestions'), findsNothing);
      expect(_liveText('No suggestions'), findsNothing);
    });

    testWidgets('selecting an option clears the suggestion-count '
        'announcement immediately', (tester) async {
      await _pump(
        tester,
        _field(announceDebounce: const Duration(milliseconds: 20)),
      );
      await tester.enterText(find.byType(TextFormField), 'gin');
      await tester.pump(const Duration(milliseconds: 30));
      expect(_liveText('3 suggestions'), findsOneWidget);

      await tester.tap(find.text('Gin').last);
      await tester.pump();
      expect(_liveText('3 suggestions'), findsNothing);
    });

    testWidgets(
      'a selection\'s own programmatic text rewrite never announces a '
      'stale suggestion count',
      (tester) async {
        await _pump(
          tester,
          _field(announceDebounce: const Duration(milliseconds: 20)),
        );
        await tester.enterText(find.byType(TextFormField), 'gin');
        await tester.pump(const Duration(milliseconds: 30));
        expect(_liveText('3 suggestions'), findsOneWidget);

        // Selecting rewrites the field's text to 'Gin' — itself still a
        // match for 'gin' — programmatically. That rewrite must never
        // schedule (or leave standing) an announcement of its own.
        await tester.tap(find.text('Gin').last);
        await tester.pump(const Duration(milliseconds: 30));
        expect(_liveText('3 suggestions'), findsNothing);
        expect(_liveText('1 suggestion'), findsNothing);
      },
    );

    testWidgets(
      'Escape clears the suggestion-count announcement',
      (tester) async {
        await _pump(
          tester,
          _field(announceDebounce: const Duration(milliseconds: 20)),
        );
        await tester.enterText(find.byType(TextFormField), 'gin');
        await tester.pump(const Duration(milliseconds: 30));
        expect(_liveText('3 suggestions'), findsOneWidget);

        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pump();
        expect(_liveText('3 suggestions'), findsNothing);
      },
    );

    testWidgets(
      'a user-driven highlight change politely announces the option',
      (tester) async {
        final announcements = <String>[];
        tester.binding.defaultBinaryMessenger.setMockMessageHandler(
          SystemChannels.accessibility.name,
          (message) async {
            final decoded = SystemChannels.accessibility.codec.decodeMessage(
              message,
            );
            if (decoded is Map && decoded['type'] == 'announce') {
              final data = decoded['data'];
              if (data is Map && data['message'] is String) {
                announcements.add(data['message'] as String);
              }
            }
            return null;
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMessageHandler(
            SystemChannels.accessibility.name,
            null,
          ),
        );

        await _pump(tester, _field());
        await tester.enterText(find.byType(TextFormField), 'gin');
        await tester.pump();

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();

        expect(announcements, contains('Gin Fizz, 8 letters'));
      },
    );
  });

  group('layout resilience', () {
    testWidgets('320 px width at 2x text scale does not overflow', (
      tester,
    ) async {
      await _pump(
        tester,
        _field(captionFor: _captionFor),
        viewSize: const Size(320, 700),
        textScale: 2,
      );
      await tester.enterText(find.byType(TextFormField), 'gin');
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('a long option list scrolls instead of overflowing', (
      tester,
    ) async {
      final many = [
        for (var i = 0; i < 12; i++) 'Option ${i.toString().padLeft(2, '0')}',
      ];
      await _pump(tester, _field(options: many), viewSize: const Size(420, 500));
      await tester.enterText(find.byType(TextFormField), 'option');
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('Option 00'), findsOneWidget);
    });
  });

  group('reduced motion', () {
    testWidgets('the options panel appears with no transient animation', (
      tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await _pump(tester, _field());
      await tester.enterText(find.byType(TextFormField), 'gin');
      await tester.pump();
      // With reduced motion there is no TweenAnimationBuilder wrapping the
      // panel, so the first frame already paints at full opacity.
      final opacityWidgets = tester.widgetList<Opacity>(find.byType(Opacity));
      expect(opacityWidgets.where((o) => o.opacity < 1.0), isEmpty);
    });
  });

  testWidgets('golden: open options panel', (tester) async {
    // The options panel renders through RawAutocomplete's own Overlay entry,
    // outside the field's local subtree, so the RepaintBoundary must wrap
    // the whole app (as the app's own visual-regression tests do) rather
    // than just the field, or the captured image would show only the field.
    const capture = ValueKey('suggestion-field-capture');
    tester.view.physicalSize = const Size(420, 420);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      RepaintBoundary(
        key: capture,
        child: MaterialApp(
          theme: ZestTheme.build(),
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            backgroundColor: const Color(0xFFF3F5DF),
            body: Padding(
              padding: const EdgeInsets.all(24),
              child: _field(captionFor: _captionFor),
            ),
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextFormField), 'gin');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    // Let the panel's open fade/scale (ZestMotion.feedback, 140 ms) finish
    // before capturing, or the golden would freeze it mid-fade.
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byKey(capture),
      matchesGoldenFile('goldens/zest-suggestion-field-open.png'),
    );
  });
}
