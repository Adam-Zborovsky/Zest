import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design/zest_tokens.dart';

/// Visual treatment for [ZestSuggestionField]'s input surface.
///
/// `plain` matches the ordinary peach input used by Discover and the
/// home-bar picker. `hardShadow` adds the cut-paper hard shadow used by the
/// constellation's home search field. Both share the same Botanical Play
/// options panel.
enum ZestSuggestionFieldStyle { plain, hardShadow }

/// A type-ahead text field built on [RawAutocomplete], styled for Botanical
/// Play. `core` stays independent of any feature: callers supply the option
/// list, labels, and selection handling — this file has no catalog import.
///
/// Behavior this widget owns (Flutter's own [RawAutocomplete] options view
/// has open issues with keyboard highlight and screen-reader affordances on
/// some platforms, so it is not reused here):
///
///  * The options panel opens while the field has focus and the current
///    query yields at least one suggestion; it stays closed for an empty
///    query or when nothing matches.
///  * Up/Down moves the keyboard highlight and **clamps** at the first and
///    last option (it does not wrap around) — this matches
///    [RawAutocomplete]'s own tracked index, which this widget reads via
///    [AutocompleteHighlightedOption] rather than re-implementing.
///  * Enter commits the highlighted option. If the person has not pressed
///    Up/Down since the last keystroke, nothing is considered highlighted
///    and Enter instead calls [onFieldSubmitted], so free-text submission
///    (for example Discover's "Find recipes") keeps working.
///  * Escape closes the options without clearing the field's text; tapping
///    outside the field and panel also closes them. Focus never leaves the
///    field during any of this.
///  * A polite live region announces the suggestion count ("5 suggestions")
///    a short debounce after the person stops typing, and "No suggestions"
///    once a non-empty query yields none — never on every keystroke.
///  * Reduced motion ([ZestMotion.reduced]) removes the panel's open
///    animation entirely; otherwise it fades and scales in over
///    [ZestMotion.feedback] (140 ms).
class ZestSuggestionField<T extends Object> extends StatefulWidget {
  const ZestSuggestionField({
    super.key,
    this.controller,
    this.focusNode,
    required this.label,
    this.hintText,
    this.prefixIcon = Icons.search_rounded,
    this.textInputAction = TextInputAction.search,
    this.validator,
    this.onFieldSubmitted,
    this.autofocus = false,
    required this.suggestionsFor,
    required this.labelFor,
    required this.semanticLabelFor,
    this.captionFor,
    this.optionBuilder,
    required this.onSelected,
    this.replaceTextOnSelect = true,
    this.maxVisible = 8,
    this.style = ZestSuggestionFieldStyle.plain,
    this.announceDebounce = const Duration(milliseconds: 300),
  }) : assert(maxVisible > 0, 'maxVisible must be positive');

  /// Externally ownable, as Discover and other existing search fields
  /// already own their controller. Created and disposed internally when
  /// left null.
  final TextEditingController? controller;

  /// Externally ownable for the same reason as [controller].
  final FocusNode? focusNode;

  /// The field's accessible name, and its visible label is left to the
  /// caller (existing screens render their own heading above the field).
  final String label;
  final String? hintText;
  final IconData? prefixIcon;
  final TextInputAction textInputAction;

  /// Runs inside a [Form] via [TextFormField.validator].
  final FormFieldValidator<String>? validator;

  /// Free-text submission: called on Enter when no option is highlighted,
  /// and via the field's own submit action otherwise. Discover's mode
  /// stays driven by this, not by [onSelected].
  final ValueChanged<String>? onFieldSubmitted;
  final bool autofocus;

  /// Synchronous: the search index this backs lives entirely in memory.
  final List<T> Function(String query) suggestionsFor;

  /// Display text for an option, both in the options panel and (when
  /// [replaceTextOnSelect] is true) written back into the field on select.
  final String Function(T) labelFor;

  /// The full accessible name for one option's row, e.g.
  /// "Gin, ingredient, 42 recipes".
  final String Function(T) semanticLabelFor;

  /// An optional trailing caption shown next to [labelFor] in the default
  /// row (for example a recipe count). Ignored when [optionBuilder] is set.
  final String? Function(T)? captionFor;

  /// Overrides the default label/caption row. Receives the current keyboard
  /// highlight state so a custom row can render it.
  final Widget Function(BuildContext context, T option, bool highlighted)?
  optionBuilder;

  final ValueChanged<T> onSelected;

  /// Whether picking an option replaces the field's text with [labelFor].
  /// False keeps whatever the person typed (for a free-text ingredient row
  /// that also offers catalog suggestions, for example).
  final bool replaceTextOnSelect;

  /// Caps how many of [suggestionsFor]'s results are shown and reachable.
  final int maxVisible;

  final ZestSuggestionFieldStyle style;

  /// How long to wait after the last keystroke before announcing the
  /// suggestion count. Injectable so tests don't need to wait 300 ms.
  final Duration announceDebounce;

  @override
  State<ZestSuggestionField<T>> createState() =>
      _ZestSuggestionFieldState<T>();
}

class _ZestSuggestionFieldState<T extends Object>
    extends State<ZestSuggestionField<T>> {
  TextEditingController? _internalController;
  FocusNode? _internalFocusNode;
  Timer? _announceTimer;
  String? _announcement;

  /// True once the person has pressed Up/Down since the options were last
  /// (re)opened for the current text. Enter only commits an option while
  /// this is true; see the class doc for why.
  bool _highlightTouched = false;

  TextEditingController get _controller =>
      widget.controller ?? (_internalController ??= TextEditingController());

  FocusNode get _focusNode =>
      widget.focusNode ?? (_internalFocusNode ??= FocusNode());

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _announceTimer?.cancel();
    _internalController?.dispose();
    _internalFocusNode?.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus && _highlightTouched) {
      setState(() => _highlightTouched = false);
    }
  }

  Iterable<T> _optionsFor(TextEditingValue value) {
    final query = value.text;
    final results = query.trim().isEmpty
        ? <T>[]
        : widget.suggestionsFor(
            query,
          ).take(widget.maxVisible).toList(growable: false);
    if (_highlightTouched) {
      // Scheduled for after this build: optionsBuilder runs mid-flight
      // inside RawAutocomplete's own field-change handling, where calling
      // setState synchronously would be unsafe.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _highlightTouched) {
          setState(() => _highlightTouched = false);
        }
      });
    }
    _scheduleAnnouncement(query, results.length);
    return results;
  }

  /// The only place [_highlightTouched] becomes true: a literal Up/Down key
  /// press observed on its way to [RawAutocomplete]'s own Shortcuts (which
  /// still performs the actual highlight move). Watching for the resulting
  /// index change instead would also fire when the index is silently
  /// re-clamped after a keystroke shrinks the option list — not a real
  /// highlight touch.
  KeyEventResult _observeArrowKeys(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        (event.logicalKey == LogicalKeyboardKey.arrowUp ||
            event.logicalKey == LogicalKeyboardKey.arrowDown) &&
        !_highlightTouched) {
      setState(() => _highlightTouched = true);
    }
    return KeyEventResult.ignored;
  }

  void _scheduleAnnouncement(String query, int count) {
    _announceTimer?.cancel();
    if (query.trim().isEmpty) {
      _announceTimer = null;
      if (_announcement != null) setState(() => _announcement = null);
      return;
    }
    _announceTimer = Timer(widget.announceDebounce, () {
      if (!mounted) return;
      setState(() {
        _announcement = count == 0
            ? 'No suggestions'
            : '$count suggestion${count == 1 ? '' : 's'}';
      });
    });
  }

  String _displayStringFor(T option) =>
      widget.replaceTextOnSelect ? widget.labelFor(option) : _controller.text;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RawAutocomplete<T>(
          textEditingController: _controller,
          focusNode: _focusNode,
          optionsBuilder: _optionsFor,
          displayStringForOption: _displayStringFor,
          onSelected: widget.onSelected,
          optionsViewOpenDirection: OptionsViewOpenDirection.mostSpace,
          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
            Widget field = Focus(
              onKeyEvent: _observeArrowKeys,
              child: Semantics(
                label: widget.label,
                child: TextFormField(
                  controller: controller,
                  focusNode: focusNode,
                  autofocus: widget.autofocus,
                  textInputAction: widget.textInputAction,
                  textCapitalization: TextCapitalization.none,
                  validator: widget.validator,
                  onTapOutside: (_) => focusNode.unfocus(),
                  // Suppresses EditableText's default "unfocus on submit"
                  // behavior for done/search/etc. — focus is this widget's
                  // to keep; a caller that wants to dismiss the keyboard
                  // after a real search (as Discover does) does so itself.
                  onEditingComplete: () {},
                  onFieldSubmitted: (text) {
                    if (_highlightTouched) {
                      onFieldSubmitted();
                    } else {
                      widget.onFieldSubmitted?.call(text);
                    }
                  },
                  decoration: InputDecoration(
                    hintText: widget.hintText,
                    hintMaxLines: 3,
                    errorMaxLines: 4,
                    prefixIcon: widget.prefixIcon == null
                        ? null
                        : Icon(widget.prefixIcon),
                  ),
                ),
              ),
            );
            if (widget.style == ZestSuggestionFieldStyle.hardShadow) {
              field = DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: ZestShape.control,
                  boxShadow: ZestShadow.hard(ZestPalette.leaf),
                ),
                child: field,
              );
            }
            return field;
          },
          optionsViewBuilder: (context, onSelected, options) =>
              _OptionsPanel<T>(
                options: options.toList(growable: false),
                touched: _highlightTouched,
                style: widget.style,
                labelFor: widget.labelFor,
                semanticLabelFor: widget.semanticLabelFor,
                captionFor: widget.captionFor,
                optionBuilder: widget.optionBuilder,
                onSelected: onSelected,
              ),
        ),
        _AnnouncementRegion(text: _announcement),
      ],
    );
  }
}

/// A stable, empty-when-idle live region: screen readers pick up the label
/// change without any visible layout jump while there is nothing to say.
class _AnnouncementRegion extends StatelessWidget {
  const _AnnouncementRegion({required this.text});

  final String? text;

  @override
  Widget build(BuildContext context) {
    final value = text;
    return Semantics(
      liveRegion: true,
      child: value == null
          ? const SizedBox.shrink()
          : Padding(
              padding: const EdgeInsets.only(top: ZestSpace.xs),
              child: Text(
                value,
                style: Theme.of(context).textTheme.bodySmall!.copyWith(
                  color: ZestPalette.secondaryInk,
                ),
              ),
            ),
    );
  }
}

/// The options panel: peach cut-paper card, capped at ~5.5 rows before it
/// scrolls, positioned and sized by [RawAutocomplete] itself. Reads
/// [AutocompleteHighlightedOption] for the keyboard highlight index — the
/// actual bug this widget exists to work around is Flutter's default
/// options view not reliably reflecting that index — but only renders (and
/// scrolls to) a highlight once [touched] is true, so nothing reads as
/// selected before the person has pressed Up/Down.
class _OptionsPanel<T extends Object> extends StatelessWidget {
  const _OptionsPanel({
    required this.options,
    required this.touched,
    required this.style,
    required this.labelFor,
    required this.semanticLabelFor,
    required this.captionFor,
    required this.optionBuilder,
    required this.onSelected,
  });

  // An approximate single-line row height; captions/optionBuilder rows may
  // render taller, in which case fewer than 5.5 rows show before scrolling.
  static const _rowHeight = 52.0;

  final List<T> options;
  final bool touched;
  final ZestSuggestionFieldStyle style;
  final String Function(T) labelFor;
  final String Function(T) semanticLabelFor;
  final String? Function(T)? captionFor;
  final Widget Function(BuildContext, T, bool)? optionBuilder;
  final AutocompleteOnSelected<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final highlighted = touched
        ? AutocompleteHighlightedOption.of(context)
        : -1;
    final reduced = ZestMotion.reduced(context);
    Widget panel = Material(
      color: ZestPalette.peach,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: ZestShape.control,
        side: BorderSide(color: ZestPalette.leaf, width: 1.5),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: _rowHeight * 5.5),
        child: ListView.builder(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          itemCount: options.length,
          itemBuilder: (context, index) {
            final option = options[index];
            final isHighlighted = index == highlighted;
            return Builder(
              builder: (rowContext) {
                if (isHighlighted) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (rowContext.mounted) {
                      Scrollable.ensureVisible(
                        rowContext,
                        alignment: 0.5,
                        duration: reduced ? Duration.zero : ZestMotion.feedback,
                      );
                    }
                  });
                }
                return _OptionRow<T>(
                  option: option,
                  highlighted: isHighlighted,
                  labelFor: labelFor,
                  semanticLabelFor: semanticLabelFor,
                  captionFor: captionFor,
                  optionBuilder: optionBuilder,
                  onTap: () => onSelected(option),
                );
              },
            );
          },
        ),
      ),
    );

    if (style == ZestSuggestionFieldStyle.hardShadow) {
      panel = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: ZestShape.control,
          boxShadow: ZestShadow.hard(ZestPalette.leaf, offset: 3),
        ),
        child: panel,
      );
    }

    if (reduced) return panel;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: ZestMotion.feedback,
      curve: ZestMotion.easeOut,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.scale(
          scale: 0.97 + 0.03 * t,
          alignment: Alignment.topCenter,
          child: child,
        ),
      ),
      child: panel,
    );
  }
}

class _OptionRow<T extends Object> extends StatelessWidget {
  const _OptionRow({
    required this.option,
    required this.highlighted,
    required this.labelFor,
    required this.semanticLabelFor,
    required this.captionFor,
    required this.optionBuilder,
    required this.onTap,
  });

  final T option;
  final bool highlighted;
  final String Function(T) labelFor;
  final String Function(T) semanticLabelFor;
  final String? Function(T)? captionFor;
  final Widget Function(BuildContext, T, bool)? optionBuilder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final content = optionBuilder != null
        ? optionBuilder!(context, option, highlighted)
        : _defaultRow(context);
    return Semantics(
      button: true,
      selected: highlighted,
      label: semanticLabelFor(option),
      child: Material(
        color: highlighted ? ZestPalette.celery : Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: ZestSpace.touchTarget),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: ZestSpace.lg,
                vertical: ZestSpace.sm,
              ),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: content,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _defaultRow(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final caption = captionFor?.call(option);
    return Row(
      children: [
        Expanded(
          child: Text(
            labelFor(option),
            style: textTheme.bodyLarge!.copyWith(
              color: ZestPalette.leaf,
              fontWeight: highlighted ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
        if (caption != null) ...[
          const SizedBox(width: ZestSpace.sm),
          Text(
            caption,
            style: textTheme.bodySmall!.copyWith(
              color: ZestPalette.secondaryInk,
            ),
          ),
        ],
      ],
    );
  }
}
