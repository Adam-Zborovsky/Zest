import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/zest_tokens.dart';
import '../../../core/widgets/botanical_art.dart';
import '../../../core/widgets/zest_button.dart';
import '../../../core/widgets/zest_card.dart';
import '../../../core/widgets/zest_sheet.dart';
import '../../../core/widgets/zest_states.dart';
import '../application/catalog_providers.dart';
import '../application/catalog_update_controller.dart';
import '../domain/catalog_update_state.dart';
import '../domain/coverage_report.dart';

/// The identified collection label required wherever counts appear:
/// "TheCocktailDB catalog, N recipes, updated <date>." Never claims
/// provider completeness — it just names what is on this device.
String coverageLine(BuildContext context, CoverageReport report) {
  final recipes =
      '${report.recipeCount} ${report.recipeCount == 1 ? 'recipe' : 'recipes'}';
  final publishedAt = report.publishedAt;
  if (publishedAt == null) return 'TheCocktailDB catalog, $recipes.';
  final date = MaterialLocalizations.of(
    context,
  ).formatMediumDate(publishedAt.toLocal());
  return 'TheCocktailDB catalog, $recipes, updated $date.';
}

/// The shared-catalog status card: shows automatic-download progress on a
/// first launch, a branded retry on failure with no catalog yet, and
/// otherwise a quiet identified coverage line — "TheCocktailDB catalog, N
/// recipes, updated <date>." Background checks, applies, and staged updates
/// are silent here; they surface through `showZestNotice` instead
/// (`docs/M11.md` "Update behavior"). Used by Home and by Discover's own
/// empty-catalog gate (moved to `lib/features/catalog/presentation` per the
/// M11 independent review, finding #19 — this is catalog-owned UI, not
/// constellation-specific).
class CatalogStatusCard extends ConsumerWidget {
  const CatalogStatusCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coverageAsync = ref.watch(catalogCoverageProvider);
    final updateState = ref.watch(catalogUpdateControllerProvider);
    final coverage = coverageAsync.value;
    final hasSnapshot = coverage?.hasSnapshot ?? false;

    if (!hasSnapshot && updateState.status == CatalogUpdateStatus.downloading) {
      return ZestCard(
        child: Row(
          children: [
            const BotanicalArt(motif: BotanicalMotif.citrus, size: 44),
            const SizedBox(width: ZestSpace.md),
            Expanded(
              child: Semantics(
                header: true,
                liveRegion: true,
                child: Text(
                  'Downloading the recipe catalog…',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (!hasSnapshot && updateState.status == CatalogUpdateStatus.failed) {
      return ZestErrorState(
        key: const ValueKey('catalog-download-failed'),
        title: "Couldn't download the catalog",
        message: _failureMessage(updateState.failure),
        actionLabel: 'Retry',
        onRetry: () =>
            ref.read(catalogUpdateControllerProvider.notifier).checkNow(),
      );
    }

    if (!hasSnapshot && coverageAsync.isLoading) {
      return const ZestLoadingState(label: 'Opening your recipe catalog…');
    }

    if (coverageAsync.hasError) {
      return ZestErrorState(
        title: 'The catalog could not open',
        message: 'The local recipe catalog could not be read. Try again.',
        onRetry: () => ref.invalidate(catalogCoverageProvider),
      );
    }

    if (!hasSnapshot || coverage == null) {
      // A safe fallback for the rare case nothing has downloaded and no
      // download is currently running (e.g. the very first frame, before
      // `checkOnLaunch` completes its first async gap).
      return ZestCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                'Your recipe collection',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: ZestSpace.sm),
            const Text('Nothing is loaded yet.'),
            const SizedBox(height: ZestSpace.lg),
            ZestButton(
              key: const ValueKey('catalog-download'),
              label: 'Download catalog',
              icon: Icons.download_rounded,
              onPressed: () =>
                  ref.read(catalogUpdateControllerProvider.notifier).checkNow(),
            ),
          ],
        ),
      );
    }

    return _CatalogCollectionNote(report: coverage);
  }

  String _failureMessage(CatalogUpdateFailureKind? kind) => switch (kind) {
    CatalogUpdateFailureKind.offline =>
      "You're offline. Connect and try again.",
    CatalogUpdateFailureKind.timeout =>
      'The recipe source took too long to answer. Try again.',
    CatalogUpdateFailureKind.unavailable =>
      'The recipe source is unavailable right now. Try again shortly.',
    CatalogUpdateFailureKind.rateLimited =>
      'The recipe source asked Zest to wait. Try again shortly.',
    _ => 'The recipe source could not be reached. Try again.',
  };
}

/// The resting collection state: the identified coverage line and a details
/// button whose sheet names the source and states it is not a completeness
/// claim.
class _CatalogCollectionNote extends StatelessWidget {
  const _CatalogCollectionNote({required this.report});

  final CoverageReport report;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        const BotanicalArt(motif: BotanicalMotif.citrus, size: 44),
        const SizedBox(width: ZestSpace.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text('Your recipe catalog', style: textTheme.titleMedium),
              ),
              Text(
                coverageLine(context, report),
                style: textTheme.bodySmall!.copyWith(
                  color: ZestPalette.secondaryInk,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          key: const ValueKey('collection-details'),
          tooltip: 'About this catalog',
          icon: const Icon(Icons.info_outline_rounded),
          onPressed: () => showZestSheet<void>(
            context: context,
            title: 'About this catalog',
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(coverageLine(context, report)),
                const SizedBox(height: ZestSpace.sm),
                const Text(
                  'This is TheCocktailDB catalog as last downloaded to this '
                  'device — not necessarily every drink the provider has '
                  'ever published.',
                  style: TextStyle(color: ZestPalette.secondaryInk),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
