import 'package:flutter/material.dart';

import '../design/zest_tokens.dart';
import 'botanical_art.dart';
import 'zest_button.dart';
import 'zest_card.dart';

class ZestEmptyState extends StatelessWidget {
  const ZestEmptyState({
    super.key,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) => ZestCard(
    child: Column(
      children: [
        const BotanicalArt(motif: BotanicalMotif.emptyGlass, size: 64),
        const SizedBox(height: ZestSpace.md),
        Semantics(
          header: true,
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ),
        const SizedBox(height: ZestSpace.xs),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: ZestSpace.lg),
        ZestButton(
          label: actionLabel,
          onPressed: onAction,
          kind: ZestButtonKind.secondary,
          expand: false,
        ),
      ],
    ),
  );
}

class ZestLoadingState extends StatelessWidget {
  const ZestLoadingState({super.key, this.label = 'Finding recipes…'});
  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    label: label,
    child: ExcludeSemantics(
      child: ZestCard(
        child: Row(
          children: [
            const BotanicalArt(motif: BotanicalMotif.citrus, size: 36),
            const SizedBox(width: ZestSpace.md),
            Expanded(
              child: Text(label, style: Theme.of(context).textTheme.titleLarge),
            ),
          ],
        ),
      ),
    ),
  );
}

class ZestErrorState extends StatelessWidget {
  const ZestErrorState({
    super.key,
    required this.title,
    required this.message,
    required this.onRetry,
    this.actionLabel = 'Try again',
  });

  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ZestCard(
      color: colors.errorContainer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            liveRegion: true,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.error_outline_rounded, color: colors.error),
                const SizedBox(width: ZestSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge!.copyWith(
                          color: colors.onErrorContainer,
                        ),
                      ),
                      const SizedBox(height: ZestSpace.xs),
                      Text(
                        message,
                        style: TextStyle(color: colors.onErrorContainer),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: ZestSpace.lg),
          ZestButton(
            label: actionLabel,
            onPressed: onRetry,
            icon: Icons.refresh_rounded,
            kind: ZestButtonKind.danger,
          ),
        ],
      ),
    );
  }
}
