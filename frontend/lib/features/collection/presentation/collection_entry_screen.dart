import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/zest_tokens.dart';
import '../../../core/widgets/botanical_art.dart';
import '../../../core/widgets/botanical_paper.dart';
import '../../../core/widgets/zest_button.dart';
import '../../../core/widgets/zest_inline_error.dart';
import '../../../core/widgets/zest_card.dart';
import '../../../core/widgets/zest_sheet.dart';
import '../../../core/widgets/zest_states.dart';
import '../../constellation/domain/ingredient_kind.dart';
import '../../constellation/presentation/ingredient_glyph.dart';
import '../../discovery/application/discovery_providers.dart';
import '../../discovery/domain/recipe.dart';
import '../../discovery/presentation/discovery_widgets.dart';
import '../application/collection_providers.dart';
import '../data/image_picker_memory_photo_picker.dart';
import '../data/memory_photo_picker.dart';
import '../domain/collection_entry.dart';
import '../domain/memory_photo.dart';

/// One collection entry: a saved recipe snapshot or a personal variation,
/// plus its private memory photo.
class CollectionEntryScreen extends ConsumerWidget {
  const CollectionEntryScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(collectionEntryProvider(id))
      .when(
        skipLoadingOnRefresh: false,
        data: (entry) => entry == null
            ? const DiscoveryFrame(back: true, child: _EntryNotFound())
            : DiscoveryFrame(
                back: true,
                eyebrow: entry.isVariation ? 'Your variation' : 'Saved recipe',
                title: entry.isVariation
                    ? 'Your variation of ${entry.source.name}'
                    : entry.displayName,
                child: _EntryContent(entry: entry),
              ),
        loading: () => const DiscoveryFrame(
          back: true,
          child: ZestLoadingState(label: 'Opening your entry…'),
        ),
        error: (error, stack) => DiscoveryFrame(
          back: true,
          child: ZestErrorState(
            title: 'This entry is out of reach',
            message: 'Something went wrong opening it.',
            onRetry: () => ref.invalidate(collectionEntryProvider(id)),
          ),
        ),
      );
}

class _EntryNotFound extends StatelessWidget {
  const _EntryNotFound();

  @override
  Widget build(BuildContext context) => ZestEmptyState(
    announce: true,
    title: 'Entry not found',
    message: 'This entry does not exist in your collection anymore.',
    actionLabel: 'Back to your collection',
    onAction: () => context.go('/collection'),
  );
}

class _EntryContent extends StatelessWidget {
  const _EntryContent({required this.entry});
  final CollectionEntry entry;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PhotoSection(entry: entry),
        const SizedBox(height: ZestSpace.xl),
        _EntryDate(entry: entry),
        const SizedBox(height: ZestSpace.xl),
        if (entry.isVariation) ...[
          Text('Named "${entry.variation!.name}"', style: textTheme.titleLarge),
          const SizedBox(height: ZestSpace.md),
        ],
        ZestButton(
          key: const ValueKey('entry-view-source'),
          label: 'View source recipe',
          icon: Icons.open_in_new_rounded,
          kind: ZestButtonKind.secondary,
          expand: false,
          onPressed: () =>
              context.push('/discover/recipe/${entry.sourceRecipeId}'),
        ),
        const SizedBox(height: ZestSpace.xxl),
        entry.isVariation
            ? _VariationBody(details: entry.variation!)
            : _SavedBody(recipe: entry.source),
        const SizedBox(height: ZestSpace.xxl),
        const TwineDivider(),
        const SizedBox(height: ZestSpace.lg),
        if (entry.isVariation) ...[
          ZestButton(
            key: const ValueKey('entry-edit'),
            label: 'Edit variation',
            icon: Icons.edit_rounded,
            kind: ZestButtonKind.secondary,
            onPressed: () => context.push('/collection/${entry.id}/edit'),
          ),
          const SizedBox(height: ZestSpace.sm),
        ],
        _DeleteButton(entry: entry),
      ],
    );
  }
}

/// The calendar day an entry sits on, with a way to move it to another day.
class _EntryDate extends ConsumerStatefulWidget {
  const _EntryDate({required this.entry});
  final CollectionEntry entry;

  @override
  ConsumerState<_EntryDate> createState() => _EntryDateState();
}

class _EntryDateState extends ConsumerState<_EntryDate> {
  bool _busy = false;
  String? _error;

  Future<void> _change() async {
    final today = collectionDay(ref.read(nowProvider)());
    final current = widget.entry.day;
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2000),
      lastDate: current.isAfter(today) ? current : today,
      helpText: 'Move this drink to a day',
    );
    if (picked == null || !mounted || collectionDay(picked) == current) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(collectionRepositoryProvider)
          .moveToDay(widget.entry.id, picked);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Zest could not change the date. Try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          const ExcludeSemantics(
            child: Icon(Icons.event_rounded, color: ZestPalette.leaf),
          ),
          const SizedBox(width: ZestSpace.sm),
          Expanded(
            child: Text(
              MaterialLocalizations.of(
                context,
              ).formatFullDate(widget.entry.day),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ],
      ),
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: ZestButton(
          key: const ValueKey('entry-change-date'),
          label: 'Change date',
          icon: Icons.edit_calendar_rounded,
          kind: ZestButtonKind.quiet,
          expand: false,
          onPressed: _busy ? null : _change,
        ),
      ),
      if (_error != null) ...[
        const SizedBox(height: ZestSpace.sm),
        ZestInlineError(_error!),
      ],
    ],
  );
}

class _SavedBody extends StatelessWidget {
  const _SavedBody({required this.recipe});
  final Recipe recipe;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Wrap(
        spacing: ZestSpace.sm,
        runSpacing: ZestSpace.sm,
        children: [
          PaperTag(
            label: _metadata('Type', recipe.alcoholic),
            icon: Icons.local_bar_outlined,
          ),
          PaperTag(
            label: _metadata('Glass', recipe.glass),
            icon: Icons.wine_bar_outlined,
          ),
          PaperTag(
            label: _metadata('Category', recipe.category),
            icon: Icons.bookmark_border_rounded,
          ),
        ],
      ),
      const SizedBox(height: ZestSpace.xl),
      ZestCard(
        recipe: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const DiscoveryHeading('Ingredients'),
            const SizedBox(height: ZestSpace.xs),
            Text(
              'Measures as given by the source, when you saved this recipe.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall!.copyWith(color: ZestPalette.secondaryInk),
            ),
            const SizedBox(height: ZestSpace.md),
            if (recipe.ingredients.isEmpty)
              const Text(
                'The source had not listed ingredients for this recipe.',
              ),
            for (var i = 0; i < recipe.ingredients.length; i++) ...[
              if (i > 0) const TwineDivider(),
              _SourceIngredientRow(
                name: recipe.ingredients[i].name,
                measure: recipe.ingredients[i].measure.display,
                kind: ingredientKindOf(recipe.ingredients[i].normalizedName),
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: ZestSpace.xxl),
      const DiscoveryHeading('How to make it'),
      const SizedBox(height: ZestSpace.lg),
      Text(
        recipe.instructions?.trim().isNotEmpty == true
            ? recipe.instructions!
            : 'The source had not provided instructions for this recipe.',
      ),
    ],
  );

  String _metadata(String label, String? value) =>
      '$label: ${value == null || value.trim().isEmpty ? 'Not provided' : value.trim()}';
}

class _SourceIngredientRow extends StatelessWidget {
  const _SourceIngredientRow({
    required this.name,
    required this.measure,
    required this.kind,
  });
  final String name;
  final String? measure;
  final IngredientKind kind;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: ZestSpace.sm),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IngredientGlyph(kind: kind, size: 38),
        const SizedBox(width: ZestSpace.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: ZestSpace.xs),
              measure == null
                  ? const PaperTag(label: 'Measure not provided', dashed: true)
                  : PaperTag(label: measure!),
            ],
          ),
        ),
      ],
    ),
  );
}

/// A variation's ingredients are the person's own free text: never matched
/// to a catalog identity, so they get a neutral dot marker rather than the
/// colored [IngredientGlyph] system used for the source's real ingredients —
/// showing a catalog glyph here would misleadingly imply the wording was
/// verified against the source data.
class _VariationBody extends StatelessWidget {
  const _VariationBody({required this.details});
  final VariationDetails details;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ZestCard(
          recipe: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const DiscoveryHeading('Your ingredients'),
              const SizedBox(height: ZestSpace.xs),
              Text(
                'Your own wording — not matched to catalog ingredients.',
                style: textTheme.bodySmall!.copyWith(
                  color: ZestPalette.secondaryInk,
                ),
              ),
              const SizedBox(height: ZestSpace.md),
              if (details.ingredients.isEmpty)
                const Text('No ingredients listed.'),
              for (var i = 0; i < details.ingredients.length; i++) ...[
                if (i > 0) const TwineDivider(),
                _VariationIngredientRow(ingredient: details.ingredients[i]),
              ],
            ],
          ),
        ),
        const SizedBox(height: ZestSpace.xxl),
        const DiscoveryHeading('Your method'),
        const SizedBox(height: ZestSpace.lg),
        Text(
          details.method.isEmpty ? 'No method written yet.' : details.method,
        ),
        if (details.notes.isNotEmpty) ...[
          const SizedBox(height: ZestSpace.xxl),
          const DiscoveryHeading('Notes'),
          const SizedBox(height: ZestSpace.lg),
          Text(details.notes),
        ],
      ],
    );
  }
}

class _VariationIngredientRow extends StatelessWidget {
  const _VariationIngredientRow({required this.ingredient});
  final VariationIngredient ingredient;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: ZestSpace.sm),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: ExcludeSemantics(
            child: Icon(Icons.circle, size: 10, color: ZestPalette.outline),
          ),
        ),
        const SizedBox(width: ZestSpace.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ingredient.name,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (ingredient.measure.isNotEmpty) ...[
                const SizedBox(height: ZestSpace.xs),
                PaperTag(label: ingredient.measure),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

class _DeleteButton extends ConsumerStatefulWidget {
  const _DeleteButton({required this.entry});
  final CollectionEntry entry;

  @override
  ConsumerState<_DeleteButton> createState() => _DeleteButtonState();
}

class _DeleteButtonState extends ConsumerState<_DeleteButton> {
  bool _busy = false;
  String? _error;

  CollectionEntry get entry => widget.entry;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      ZestButton(
        key: const ValueKey('entry-delete'),
        label: entry.isVariation
            ? 'Delete variation'
            : 'Remove from collection',
        icon: Icons.delete_outline_rounded,
        kind: ZestButtonKind.danger,
        onPressed: _busy ? null : _confirmDelete,
      ),
      if (_error != null) ...[
        const SizedBox(height: ZestSpace.md),
        ZestInlineError(_error!),
      ],
    ],
  );

  Future<void> _confirmDelete() async {
    final confirmed = await showZestSheet<bool>(
      context: context,
      title: entry.isVariation
          ? 'Delete this variation?'
          : 'Remove from collection?',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            entry.isVariation
                ? 'This deletes your variation and any photo you added. '
                      'This cannot be undone.'
                : 'This also deletes any photo you added to this entry. '
                      'This cannot be undone.',
          ),
          const SizedBox(height: ZestSpace.lg),
          ZestButton(
            key: const ValueKey('entry-delete-confirm'),
            label: entry.isVariation ? 'Delete' : 'Remove',
            kind: ZestButtonKind.danger,
            onPressed: () => Navigator.of(context).pop(true),
          ),
          const SizedBox(height: ZestSpace.sm),
          ZestButton(
            label: 'Cancel',
            kind: ZestButtonKind.quiet,
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(collectionRepositoryProvider).delete(entry.id);
      if (mounted) context.go('/collection');
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = entry.isVariation
              ? 'Zest could not delete this variation. Try again.'
              : 'Zest could not remove this entry. Try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _PhotoSection extends ConsumerStatefulWidget {
  const _PhotoSection({required this.entry});
  final CollectionEntry entry;

  @override
  ConsumerState<_PhotoSection> createState() => _PhotoSectionState();
}

class _PhotoSectionState extends ConsumerState<_PhotoSection> {
  String? _error;
  bool _busy = false;

  Future<void> _pick(PhotoSource source) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final picker = ref.read(memoryPhotoPickerProvider);
      final photo = await picker.pick(source);
      if (photo == null) return; // Cancelled: no change.
      await ref
          .read(collectionRepositoryProvider)
          .setPhoto(widget.entry.id, photo);
    } on PhotoRejected catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on PhotoPickerUnavailable catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      // Storing the picked photo failed (for example a storage error).
      if (mounted) {
        setState(
          () => _error =
              'Zest could not keep this photo on this device. Try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openAddSheet() async {
    final picker = ref.read(memoryPhotoPickerProvider);
    final choice = await showZestSheet<PhotoSource>(
      context: context,
      title: 'Add a photo',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ZestButton(
            key: const ValueKey('photo-choose-gallery'),
            label: 'Choose from your photos',
            icon: Icons.photo_library_outlined,
            onPressed: () => Navigator.of(context).pop(PhotoSource.gallery),
          ),
          if (picker.supportsCamera) ...[
            const SizedBox(height: ZestSpace.sm),
            ZestButton(
              key: const ValueKey('photo-take-camera'),
              label: 'Take a photo',
              icon: Icons.photo_camera_outlined,
              kind: ZestButtonKind.secondary,
              onPressed: () => Navigator.of(context).pop(PhotoSource.camera),
            ),
          ],
        ],
      ),
    );
    if (choice != null && mounted) await _pick(choice);
  }

  Future<void> _confirmRemove() async {
    final confirmed = await showZestSheet<bool>(
      context: context,
      title: 'Remove this photo?',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'This removes your private photo from this entry. '
            'This cannot be undone.',
          ),
          const SizedBox(height: ZestSpace.lg),
          ZestButton(
            key: const ValueKey('photo-remove-confirm'),
            label: 'Remove',
            kind: ZestButtonKind.danger,
            onPressed: () => Navigator.of(context).pop(true),
          ),
          const SizedBox(height: ZestSpace.sm),
          ZestButton(
            label: 'Cancel',
            kind: ZestButtonKind.quiet,
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(collectionRepositoryProvider).removePhoto(widget.entry.id);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Zest could not remove this photo. Try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final photo = ref.watch(memoryPhotoProvider(widget.entry.id)).value;
    final radius = ZestShape.recipe.resolve(Directionality.of(context));
    return ZestCard(
      recipe: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (photo != null) ...[
            ClipRRect(
              borderRadius: radius,
              child: Image.memory(
                photo.bytes,
                height: 220,
                width: double.infinity,
                fit: BoxFit.cover,
                semanticLabel: 'Your photo of ${widget.entry.displayName}',
                // A stored photo that fails to decode (a corrupted write)
                // still gets an honest, designed state, not a blank or a
                // crash.
                errorBuilder: (context, error, stack) => SizedBox(
                  height: 220,
                  width: double.infinity,
                  child: ColoredBox(
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    child: Center(
                      child: Semantics(
                        label: 'Your photo could not be shown',
                        child: const ExcludeSemantics(
                          child: BotanicalArt(
                            motif: BotanicalMotif.emptyGlass,
                            size: 88,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: ZestSpace.sm),
            const PaperTag(label: 'Your photo — private to this device'),
            const SizedBox(height: ZestSpace.md),
            Row(
              children: [
                Expanded(
                  child: ZestButton(
                    key: const ValueKey('photo-replace'),
                    label: 'Replace photo',
                    kind: ZestButtonKind.secondary,
                    onPressed: _busy ? null : _openAddSheet,
                  ),
                ),
                const SizedBox(width: ZestSpace.sm),
                Expanded(
                  child: ZestButton(
                    key: const ValueKey('photo-remove'),
                    label: 'Remove photo',
                    kind: ZestButtonKind.danger,
                    onPressed: _busy ? null : _confirmRemove,
                  ),
                ),
              ],
            ),
          ] else ...[
            // No photo of the person's own yet: show the cocktail's picture
            // from the recipe source, as the calendar does, with its source
            // credit, so it is never mistaken for the person's photo. With no
            // source image either, RecipeImage shows its labeled artwork.
            RecipeImage(
              url: widget.entry.source.thumbnailUrl,
              name: widget.entry.source.name,
            ),
            const SizedBox(height: ZestSpace.md),
            ZestButton(
              key: const ValueKey('photo-add'),
              label: 'Add a photo',
              icon: Icons.add_a_photo_outlined,
              onPressed: _busy ? null : _openAddSheet,
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: ZestSpace.md),
            Semantics(
              liveRegion: true,
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
