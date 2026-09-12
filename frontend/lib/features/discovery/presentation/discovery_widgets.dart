import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/design/zest_tokens.dart';
import '../../../core/network/cocktail_api_exception.dart';
import '../../../core/widgets/botanical_art.dart';
import '../../../core/widgets/zest_button.dart';
import '../../../core/widgets/zest_card.dart';
import '../../../core/widgets/zest_states.dart';
import '../application/discovery_providers.dart';

/// Injectable image loading: tests render authored images without network access.
final recipeImageProvider = Provider<ImageProvider Function(String)>((ref) {
  return (url) => NetworkImage(url);
});

final sourceLauncherProvider = Provider<Future<bool> Function(Uri)>((ref) {
  return (uri) => launchUrl(uri, mode: LaunchMode.externalApplication);
});

class DiscoveryFrame extends StatelessWidget {
  const DiscoveryFrame({
    super.key,
    required this.child,
    this.back = false,
    this.slivers = const [],
  });
  final Widget child;
  final bool back;
  final List<Widget> slivers;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: CustomScrollView(
            key: const PageStorageKey('discovery-scroll'),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.all(ZestSpace.page),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          if (back) ...[
                            IconButton(
                              tooltip: 'Back to discovery',
                              onPressed: () => context.canPop()
                                  ? context.pop()
                                  : context.go('/discover'),
                              icon: const Icon(Icons.arrow_back_rounded),
                            ),
                            const SizedBox(width: ZestSpace.sm),
                          ],
                          const BotanicalArt(size: 36),
                          const SizedBox(width: ZestSpace.sm),
                          Expanded(
                            child: Text(
                              'Zest',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: ZestSpace.section),
                      child,
                      const SizedBox(height: ZestSpace.xxl),
                    ],
                  ),
                ),
              ),
              ...slivers,
            ],
          ),
        ),
      ),
    ),
  );
}

class DiscoveryHeading extends StatelessWidget {
  const DiscoveryHeading(this.text, {super.key, this.large = false});
  final String text;
  final bool large;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Text(
      text,
      style: large
          ? Theme.of(context).textTheme.displayMedium
          : Theme.of(context).textTheme.headlineSmall,
    ),
  );
}

class RecipeImage extends ConsumerWidget {
  const RecipeImage({
    super.key,
    required this.url,
    required this.name,
    this.compact = false,
  });
  final String? url;
  final String name;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uri = Uri.tryParse(url?.trim() ?? '');
    final valid =
        uri != null &&
        uri.scheme == 'https' &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty;
    if (!valid) {
      return _fallback(context, 'No source image');
    }
    return Image(
      image: ref.watch(recipeImageProvider)(uri.toString()),
      fit: BoxFit.cover,
      width: double.infinity,
      height: compact ? 140 : 260,
      semanticLabel: '$name — image from TheCocktailDB',
      frameBuilder: (context, child, frame, synchronous) =>
          frame != null || synchronous
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _framed(context, child),
                const SizedBox(height: ZestSpace.sm),
                Text(
                  'Image: TheCocktailDB',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            )
          : _fallback(context, 'Loading source image'),
      errorBuilder: (context, error, stack) =>
          _fallback(context, 'Source image unavailable'),
    );
  }

  Widget _framed(BuildContext context, Widget child) => ClipRRect(
    borderRadius: ZestShape.recipe.resolve(Directionality.of(context)),
    child: child,
  );

  Widget _fallback(BuildContext context, String label) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _framed(
        context,
        SizedBox(
          height: compact ? 140 : 260,
          child: ColoredBox(
            color: Theme.of(context).colorScheme.secondaryContainer,
            child: Center(
              child: BotanicalArt(
                motif: BotanicalMotif.emptyGlass,
                size: compact ? 72 : 112,
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: ZestSpace.sm),
      Text(label, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}

class DiscoveryFailure extends ConsumerStatefulWidget {
  const DiscoveryFailure({
    super.key,
    required this.error,
    required this.onRetry,
  });
  final Object error;
  final VoidCallback onRetry;

  @override
  ConsumerState<DiscoveryFailure> createState() => _DiscoveryFailureState();
}

class _DiscoveryFailureState extends ConsumerState<DiscoveryFailure> {
  Timer? _timer;
  int _remaining = 0;

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  @override
  void didUpdateWidget(DiscoveryFailure oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.error, widget.error)) _startCooldown();
  }

  void _startCooldown() {
    _timer?.cancel();
    final error = widget.error;
    final delay =
        error is CocktailApiException &&
            error.kind == CocktailApiErrorKind.rateLimited
        ? error.retryAfter ?? const Duration(seconds: 30)
        : Duration.zero;
    final now = ref.read(nowProvider);
    final deadline = error is CocktailApiException
        ? error.retryAt ?? now().add(delay)
        : now();
    int remaining() {
      final seconds = (deadline.difference(now()).inMilliseconds / 1000).ceil();
      return seconds > 0 ? seconds : 0;
    }

    _remaining = remaining();
    if (_remaining > 0) {
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() => _remaining = remaining());
        if (_remaining <= 0) timer.cancel();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final kind = widget.error is CocktailApiException
        ? (widget.error as CocktailApiException).kind
        : null;
    final message = switch (kind) {
      CocktailApiErrorKind.network => 'Check your connection, then try again.',
      CocktailApiErrorKind.timeout =>
        'The recipe source took too long to reply. Try again.',
      CocktailApiErrorKind.rateLimited =>
        'The recipe source needs a short pause. Your search is still here.',
      CocktailApiErrorKind.invalidResponse =>
        'The recipe source sent a response Zest could not read. Try again later.',
      _ => 'The recipe source is unavailable right now. Try again later.',
    };
    if (_remaining == 0) {
      return ZestErrorState(
        title: 'Recipes are out of reach',
        message: message,
        onRetry: widget.onRetry,
      );
    }
    return ZestCard(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            liveRegion: true,
            child: const DiscoveryHeading('A moment for the source'),
          ),
          const SizedBox(height: ZestSpace.sm),
          Text(message),
          const SizedBox(height: ZestSpace.lg),
          ZestButton(label: 'Try again in $_remaining s', onPressed: null),
        ],
      ),
    );
  }
}

class SourceAttribution extends ConsumerStatefulWidget {
  const SourceAttribution({
    super.key,
    required this.uri,
    this.notices = const [],
  });
  final Uri uri;
  final List<String> notices;

  @override
  ConsumerState<SourceAttribution> createState() => _SourceAttributionState();
}

class _SourceAttributionState extends ConsumerState<SourceAttribution> {
  bool _failed = false;

  Future<void> _open() async {
    var opened = false;
    try {
      opened = await ref.read(sourceLauncherProvider)(widget.uri);
    } catch (_) {
      /* Safe visible fallback below. */
    }
    if (mounted) setState(() => _failed = !opened);
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text('Recipe data and imagery: TheCocktailDB'),
      for (final notice in widget.notices.where(
        (text) => text.trim().isNotEmpty,
      )) ...[const SizedBox(height: ZestSpace.sm), Text(notice)],
      const SizedBox(height: ZestSpace.md),
      ZestButton(
        label: 'Open source recipe',
        icon: Icons.open_in_new_rounded,
        kind: ZestButtonKind.secondary,
        onPressed: _open,
      ),
      if (_failed) ...[
        const SizedBox(height: ZestSpace.sm),
        Semantics(
          liveRegion: true,
          child: const Text(
            'Could not open the source. Copy this address into your browser:',
          ),
        ),
        SelectableText(widget.uri.toString()),
      ],
    ],
  );
}
