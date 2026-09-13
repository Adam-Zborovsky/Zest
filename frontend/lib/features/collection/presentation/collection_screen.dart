import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/zest_tokens.dart';
import '../../../core/widgets/botanical_art.dart';
import '../../../core/widgets/zest_button.dart';
import '../../../core/widgets/zest_card.dart';
import '../../../core/widgets/zest_states.dart';
import '../../../core/widgets/botanical_paper.dart';
import '../../discovery/presentation/discovery_widgets.dart';
import '../application/collection_providers.dart';
import '../domain/collection_entry.dart';

/// The private collection: saved recipes and personal variations, newest
/// first. Never shows provider photography as the person's own photo — only
/// a saved memory photo or a designed no-photo treatment.
class CollectionScreen extends ConsumerWidget {
  const CollectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(collectionEntriesProvider)
      .when(
        skipLoadingOnRefresh: false,
        data: (entries) => DiscoveryFrame(
          back: true,
          eyebrow: 'Your collection',
          title: 'What you keep,\n',
          titleAccent: 'and what you make your own.',
          intro:
              'Saved recipes and personal variations, private to this device.',
          child: entries.isEmpty
              ? const _EmptyCollection()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final entry in entries) ...[
                      _CollectionEntryCard(entry: entry),
                      const SizedBox(height: ZestSpace.lg),
                    ],
                  ],
                ),
        ),
        loading: () => const DiscoveryFrame(
          back: true,
          eyebrow: 'Your collection',
          child: ZestLoadingState(label: 'Opening your collection…'),
        ),
        error: (error, stack) => DiscoveryFrame(
          back: true,
          eyebrow: 'Your collection',
          child: ZestErrorState(
            title: 'Your collection is out of reach',
            message:
                'Something went wrong opening your saved recipes and variations.',
            onRetry: () => ref.invalidate(collectionEntriesProvider),
          ),
        ),
      );
}

class _EmptyCollection extends StatelessWidget {
  const _EmptyCollection();

  @override
  Widget build(BuildContext context) => ZestEmptyState(
    title: 'Nothing saved yet',
    message:
        'Open a recipe and choose "Save to collection", or make a personal '
        'variation, to see it here.',
    actionLabel: 'Find recipes to save',
    onAction: () => context.go('/discover'),
  );
}

class _CollectionEntryCard extends StatelessWidget {
  const _CollectionEntryCard({required this.entry});
  final CollectionEntry entry;

  @override
  Widget build(BuildContext context) => ZestCard(
    recipe: true,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _EntryThumbnail(entry: entry),
        const SizedBox(height: ZestSpace.lg),
        DiscoveryHeading(entry.displayName),
        const SizedBox(height: ZestSpace.sm),
        PaperTag(
          label: entry.isVariation
              ? 'Your variation of ${entry.source.name}'
              : 'Saved recipe',
          icon: entry.isVariation
              ? Icons.edit_note_rounded
              : Icons.bookmark_rounded,
        ),
        const SizedBox(height: ZestSpace.md),
        ZestButton(
          key: ValueKey('collection-${entry.id}'),
          label: 'Open',
          semanticLabel: 'Open ${entry.displayName}',
          kind: ZestButtonKind.secondary,
          expand: false,
          onPressed: () => context.push('/collection/${entry.id}'),
        ),
      ],
    ),
  );
}

class _EntryThumbnail extends ConsumerWidget {
  const _EntryThumbnail({required this.entry});
  final CollectionEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photo = ref.watch(memoryPhotoProvider(entry.id)).value;
    final radius = ZestShape.recipe.resolve(Directionality.of(context));
    if (photo == null) {
      return ClipRRect(
        borderRadius: radius,
        child: _placeholder(context, 'No photo added'),
      );
    }
    return ClipRRect(
      borderRadius: radius,
      child: Image.memory(
        photo.bytes,
        height: 140,
        width: double.infinity,
        fit: BoxFit.cover,
        semanticLabel: 'Your photo of ${entry.displayName}',
        // A stored photo that fails to decode (a corrupted write) still
        // gets an honest, designed state rather than a blank or a crash.
        errorBuilder: (context, error, stack) =>
            _placeholder(context, 'Your photo could not be shown'),
      ),
    );
  }

  Widget _placeholder(BuildContext context, String label) => SizedBox(
    height: 140,
    width: double.infinity,
    child: ColoredBox(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Center(
        child: Semantics(
          label: label,
          child: const ExcludeSemantics(
            child: BotanicalArt(motif: BotanicalMotif.emptyGlass, size: 72),
          ),
        ),
      ),
    ),
  );
}
