import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/zest_tokens.dart';
import '../../../core/widgets/botanical_paper.dart';
import '../../../core/widgets/zest_button.dart';
import '../../../core/widgets/zest_card.dart';
import '../../../core/widgets/zest_sheet.dart';
import '../../../core/widgets/zest_states.dart';
import '../../discovery/application/discovery_providers.dart';
import '../../discovery/presentation/discovery_widgets.dart';
import '../../discovery/presentation/recipe_detail_screen.dart'
    show InvalidDiscoveryLink;
import '../application/collection_providers.dart';
import '../domain/collection_entry.dart';

/// The shared new/edit variation editor. A new variation is prefilled from
/// its source recipe (name, ingredients with measures, and method exactly
/// as the source gives them) via [VariationDetails.fromSource]; editing
/// loads the entry's own saved variation details. The source snapshot
/// itself is never edited here.
class VariationEditorScreen extends ConsumerWidget {
  const VariationEditorScreen.newVariation({
    super.key,
    required String sourceRecipeId,
  }) : _sourceRecipeId = sourceRecipeId,
       _entryId = null;

  const VariationEditorScreen.editVariation({
    super.key,
    required String entryId,
  }) : _entryId = entryId,
       _sourceRecipeId = null;

  final String? _sourceRecipeId;
  final String? _entryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sourceRecipeId = _sourceRecipeId;
    if (sourceRecipeId != null) {
      if (!RegExp(r'^\d+$').hasMatch(sourceRecipeId)) {
        return const InvalidDiscoveryLink(
          title: 'That recipe link is not valid',
        );
      }
      return ref
          .watch(recipeDetailProvider(sourceRecipeId))
          .when(
            skipLoadingOnRefresh: false,
            data: (recipe) => recipe == null
                ? DiscoveryFrame(
                    back: true,
                    child: ZestEmptyState(
                      announce: true,
                      title: 'Recipe not found',
                      message:
                          'The source has no recipe at this address, so a '
                          'variation cannot be started.',
                      actionLabel: 'Back to discovery',
                      onAction: () => context.go('/discover'),
                    ),
                  )
                : _VariationForm(
                    key: ValueKey('new-${recipe.id}'),
                    eyebrow: 'New variation',
                    heading: 'Your variation of ${recipe.name}',
                    initial: VariationDetails.fromSource(recipe),
                    onSave: (details) => ref
                        .read(collectionRepositoryProvider)
                        .createVariation(recipe, details),
                  ),
            loading: () => const DiscoveryFrame(
              back: true,
              child: ZestLoadingState(label: 'Opening the recipe…'),
            ),
            error: (error, stack) => DiscoveryFrame(
              back: true,
              child: DiscoveryFailure(
                error: error,
                onRetry: () =>
                    ref.invalidate(recipeDetailProvider(sourceRecipeId)),
              ),
            ),
          );
    }
    final entryId = _entryId!;
    return ref
        .watch(collectionEntryProvider(entryId))
        .when(
          skipLoadingOnRefresh: false,
          data: (entry) => entry == null || !entry.isVariation
              ? DiscoveryFrame(
                  back: true,
                  child: ZestEmptyState(
                    announce: true,
                    title: 'Entry not found',
                    message:
                        'This variation does not exist in your collection '
                        'anymore.',
                    actionLabel: 'Back to your collection',
                    onAction: () => context.go('/collection'),
                  ),
                )
              : _VariationForm(
                  key: ValueKey('edit-$entryId'),
                  eyebrow: 'Edit variation',
                  heading: 'Your variation of ${entry.source.name}',
                  initial: entry.variation!,
                  onSave: (details) => ref
                      .read(collectionRepositoryProvider)
                      .updateVariation(entryId, details),
                ),
          loading: () => const DiscoveryFrame(
            back: true,
            child: ZestLoadingState(label: 'Opening your variation…'),
          ),
          error: (error, stack) => DiscoveryFrame(
            back: true,
            child: ZestErrorState(
              title: 'This entry is out of reach',
              message: 'Something went wrong opening it.',
              onRetry: () => ref.invalidate(collectionEntryProvider(entryId)),
            ),
          ),
        );
  }
}

class _VariationForm extends ConsumerStatefulWidget {
  const _VariationForm({
    super.key,
    required this.eyebrow,
    required this.heading,
    required this.initial,
    required this.onSave,
  });

  final String eyebrow;
  final String heading;
  final VariationDetails initial;
  final Future<CollectionEntry> Function(VariationDetails details) onSave;

  @override
  ConsumerState<_VariationForm> createState() => _VariationFormState();
}

class _IngredientRowControllers {
  _IngredientRowControllers({
    required this.id,
    required this.name,
    required this.measure,
  });
  final int id;
  final TextEditingController name;
  final TextEditingController measure;

  void dispose() {
    name.dispose();
    measure.dispose();
  }
}

class _VariationFormState extends ConsumerState<_VariationForm> {
  late final TextEditingController _name;
  late final TextEditingController _method;
  late final TextEditingController _notes;
  final _rows = <_IngredientRowControllers>[];
  final _rowErrors = <int, String>{};
  int _nextRowId = 0;
  bool _dirty = false;
  bool _saving = false;
  String? _nameError;
  String? _formError;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initial.name)
      ..addListener(_markDirty);
    _method = TextEditingController(text: widget.initial.method)
      ..addListener(_markDirty);
    _notes = TextEditingController(text: widget.initial.notes)
      ..addListener(_markDirty);
    for (final ingredient in widget.initial.ingredients) {
      _rows.add(
        _IngredientRowControllers(
          id: _nextRowId++,
          name: TextEditingController(text: ingredient.name)
            ..addListener(_markDirty),
          measure: TextEditingController(text: ingredient.measure)
            ..addListener(_markDirty),
        ),
      );
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _method.dispose();
    _notes.dispose();
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  void _addRow() {
    if (_rows.length >= VariationDetails.maxIngredients) {
      setState(() => _formError = 'A variation has too many ingredients.');
      return;
    }
    setState(() {
      _formError = null;
      _dirty = true;
      _rows.add(
        _IngredientRowControllers(
          id: _nextRowId++,
          name: TextEditingController()..addListener(_markDirty),
          measure: TextEditingController()..addListener(_markDirty),
        ),
      );
    });
  }

  void _removeRow(int id) {
    setState(() {
      _dirty = true;
      final row = _rows.firstWhere((row) => row.id == id);
      row.dispose();
      _rows.removeWhere((row) => row.id == id);
      _rowErrors.remove(id);
    });
  }

  Future<bool> _confirmDiscard() async {
    final discard = await showZestSheet<bool>(
      context: context,
      title: 'Discard your changes?',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Your edits have not been saved. Leaving now discards them.',
          ),
          const SizedBox(height: ZestSpace.lg),
          ZestButton(
            key: const ValueKey('editor-discard-confirm'),
            label: 'Discard changes',
            kind: ZestButtonKind.danger,
            onPressed: () => Navigator.of(context).pop(true),
          ),
          const SizedBox(height: ZestSpace.sm),
          ZestButton(
            label: 'Keep editing',
            kind: ZestButtonKind.quiet,
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ],
      ),
    );
    return discard ?? false;
  }

  Future<void> _save() async {
    setState(() {
      _nameError = null;
      _formError = null;
      _rowErrors.clear();
    });
    final ingredients = <VariationIngredient>[];
    final rowErrors = <int, String>{};
    for (final row in _rows) {
      final name = row.name.text.trim();
      final measure = row.measure.text.trim();
      if (name.isEmpty && measure.isEmpty) continue;
      try {
        ingredients.add(VariationIngredient(name: name, measure: measure));
      } on FormatException catch (error) {
        rowErrors[row.id] = error.message;
      }
    }
    if (rowErrors.isNotEmpty) {
      setState(() => _rowErrors.addAll(rowErrors));
      return;
    }
    final VariationDetails details;
    try {
      details = VariationDetails(
        name: _name.text,
        ingredients: ingredients,
        method: _method.text,
        notes: _notes.text,
      );
    } on FormatException catch (error) {
      setState(() => _nameError = error.message);
      return;
    }
    setState(() => _saving = true);
    try {
      final entry = await widget.onSave(details);
      _dirty = false;
      if (!mounted) return;
      context.pushReplacement('/collection/${entry.id}');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// The frame's explicit back button calls `context.pop()` directly, which
  /// bypasses [PopScope] (that guard only intercepts system back gestures),
  /// so this path confirms discard itself before popping.
  Future<void> _handleBack() async {
    if (!_dirty) {
      context.pop();
      return;
    }
    if (await _confirmDiscard() && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (!await _confirmDiscard()) return;
        if (mounted) Navigator.of(context).pop();
      },
      child: DiscoveryFrame(
        back: true,
        onBack: _handleBack,
        eyebrow: widget.eyebrow,
        title: widget.heading,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ZestCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const DiscoveryHeading('Name'),
                  const SizedBox(height: ZestSpace.sm),
                  TextField(
                    key: const ValueKey('variation-name'),
                    controller: _name,
                    maxLength: VariationDetails.maxNameLength,
                    decoration: InputDecoration(
                      labelText: 'Variation name',
                      errorText: _nameError,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: ZestSpace.xl),
            ZestCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const DiscoveryHeading('Ingredients'),
                  const SizedBox(height: ZestSpace.xs),
                  Text(
                    'Up to ${VariationDetails.maxIngredients} ingredients, in '
                    'your own wording.',
                    style: textTheme.bodySmall!.copyWith(
                      color: ZestPalette.secondaryInk,
                    ),
                  ),
                  const SizedBox(height: ZestSpace.md),
                  for (var i = 0; i < _rows.length; i++) ...[
                    if (i > 0) const TwineDivider(),
                    _IngredientFieldRow(
                      key: ValueKey('ingredient-row-${_rows[i].id}'),
                      index: i,
                      row: _rows[i],
                      error: _rowErrors[_rows[i].id],
                      onRemove: () => _removeRow(_rows[i].id),
                    ),
                  ],
                  const SizedBox(height: ZestSpace.md),
                  ZestButton(
                    key: const ValueKey('variation-add-ingredient'),
                    label: 'Add ingredient',
                    icon: Icons.add_rounded,
                    kind: ZestButtonKind.secondary,
                    expand: false,
                    onPressed: _addRow,
                  ),
                  if (_formError != null) ...[
                    const SizedBox(height: ZestSpace.md),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        _formError!,
                        style: TextStyle(color: colors.error),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: ZestSpace.xl),
            ZestCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const DiscoveryHeading('Method'),
                  const SizedBox(height: ZestSpace.sm),
                  TextField(
                    key: const ValueKey('variation-method'),
                    controller: _method,
                    minLines: 4,
                    maxLines: 12,
                    maxLength: VariationDetails.maxMethodLength,
                    buildCounter: _noCounter,
                    decoration: const InputDecoration(
                      labelText: 'How you make it',
                      alignLabelWithHint: true,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: ZestSpace.xl),
            ZestCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const DiscoveryHeading('Notes'),
                  const SizedBox(height: ZestSpace.sm),
                  TextField(
                    key: const ValueKey('variation-notes'),
                    controller: _notes,
                    minLines: 3,
                    maxLines: 8,
                    maxLength: VariationDetails.maxNotesLength,
                    buildCounter: _noCounter,
                    decoration: const InputDecoration(
                      labelText: 'Optional notes',
                      alignLabelWithHint: true,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: ZestSpace.xl),
            ZestButton(
              key: const ValueKey('variation-save'),
              label: _saving ? 'Saving…' : 'Save variation',
              icon: Icons.check_rounded,
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}

Widget? _noCounter(
  BuildContext context, {
  required int currentLength,
  required bool isFocused,
  int? maxLength,
}) => null;

class _IngredientFieldRow extends StatelessWidget {
  const _IngredientFieldRow({
    super.key,
    required this.index,
    required this.row,
    required this.onRemove,
    this.error,
  });

  final int index;
  final _IngredientRowControllers row;
  final VoidCallback onRemove;
  final String? error;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final nameField = TextField(
        key: ValueKey('variation-ingredient-name-$index'),
        controller: row.name,
        maxLength: VariationIngredient.maxNameLength,
        buildCounter: _noCounter,
        decoration: InputDecoration(labelText: 'Ingredient', errorText: error),
      );
      final measureField = TextField(
        key: ValueKey('variation-ingredient-measure-$index'),
        controller: row.measure,
        maxLength: VariationIngredient.maxMeasureLength,
        buildCounter: _noCounter,
        decoration: const InputDecoration(labelText: 'Measure'),
      );
      final removeButton = IconButton(
        key: ValueKey('variation-remove-ingredient-$index'),
        tooltip: 'Remove ingredient ${index + 1}',
        onPressed: onRemove,
        icon: const Icon(Icons.close_rounded),
      );
      if (constraints.maxWidth < 360) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: ZestSpace.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              nameField,
              const SizedBox(height: ZestSpace.sm),
              Row(
                children: [
                  Expanded(child: measureField),
                  removeButton,
                ],
              ),
            ],
          ),
        );
      }
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: ZestSpace.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 3, child: nameField),
            const SizedBox(width: ZestSpace.sm),
            Expanded(flex: 2, child: measureField),
            removeButton,
          ],
        ),
      );
    },
  );
}
