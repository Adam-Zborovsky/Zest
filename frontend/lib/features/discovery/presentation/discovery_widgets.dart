import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/design/zest_tokens.dart';
import '../../../core/network/cocktail_api_exception.dart';
import '../../../core/widgets/botanical_art.dart';
import '../../../core/widgets/botanical_paper.dart';
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

/// The shared page shell. Every page opens on the Night Garden band — the
/// wordmark, an optional eyebrow, heading, and intro, plus optional
/// night-field content such as the home constellation — and continues on
/// the fennel paper page. Both halves align to the 800-pixel page width
/// while the band's color bleeds edge to edge.
class DiscoveryFrame extends StatelessWidget {
  const DiscoveryFrame({
    super.key,
    required this.child,
    this.back = false,
    this.slivers = const [],
    this.eyebrow,
    this.title,
    this.titleAccent,
    this.intro,
    this.band,
  });

  final Widget child;
  final bool back;
  final List<Widget> slivers;
  final String? eyebrow;
  final String? title;

  /// Appended to [title] in grapefruit, as-is (include any leading space).
  final String? titleAccent;
  final String? intro;

  /// Extra content on the night field below the heading.
  final Widget? band;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final topInset = MediaQuery.paddingOf(context).top;
    return Scaffold(
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final gutter = math.max(
              0.0,
              (constraints.maxWidth - ZestSpace.pageWidth) / 2,
            );
            return CustomScrollView(
              key: const PageStorageKey('discovery-scroll'),
              slivers: [
                // Band and page body share one box so the body is always
                // built, even when large text makes the band taller than the
                // viewport's cache extent.
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      NightBand(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            ZestSpace.page,
                            ZestSpace.md + topInset,
                            ZestSpace.page,
                            ZestSpace.lg,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _FrameTopBar(back: back),
                              if (eyebrow != null) ...[
                                const SizedBox(height: ZestSpace.xl),
                                Text(
                                  eyebrow!,
                                  style: textTheme.labelMedium!.copyWith(
                                    color: ZestPalette.nightMuted,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                              ],
                              if (title != null) ...[
                                SizedBox(
                                  height: eyebrow == null
                                      ? ZestSpace.xl
                                      : ZestSpace.xs,
                                ),
                                DiscoveryHeading(
                                  title!,
                                  accent: titleAccent,
                                  large: true,
                                ),
                              ],
                              if (intro != null) ...[
                                const SizedBox(height: ZestSpace.md),
                                Text(
                                  intro!,
                                  style: textTheme.bodyLarge!.copyWith(
                                    color: ZestPalette.nightMuted,
                                  ),
                                ),
                              ],
                              if (band != null) ...[
                                const SizedBox(height: ZestSpace.xl),
                                band!,
                              ],
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          ZestSpace.page + gutter,
                          ZestSpace.xl,
                          ZestSpace.page + gutter,
                          ZestSpace.xxl,
                        ),
                        child: child,
                      ),
                    ],
                  ),
                ),
                for (final sliver in slivers)
                  SliverPadding(
                    padding: EdgeInsets.symmetric(horizontal: gutter),
                    sliver: sliver,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _FrameTopBar extends StatelessWidget {
  const _FrameTopBar({required this.back});

  final bool back;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      if (back) ...[
        IconButton(
          tooltip: 'Back to discovery',
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/discover'),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        const SizedBox(width: ZestSpace.xs),
      ],
      const DecoratedBox(
        decoration: BoxDecoration(
          color: ZestPalette.peach,
          shape: BoxShape.circle,
        ),
        child: Padding(
          padding: EdgeInsets.all(5),
          child: BotanicalArt(size: 34),
        ),
      ),
      const SizedBox(width: ZestSpace.sm),
      Expanded(
        child: Text('Zest', style: Theme.of(context).textTheme.headlineSmall),
      ),
    ],
  );
}

class DiscoveryHeading extends StatelessWidget {
  const DiscoveryHeading(
    this.text, {
    super.key,
    this.large = false,
    this.accent,
    this.accentColor = ZestPalette.grapefruit,
  });
  final String text;
  final bool large;

  /// Trailing text in [accentColor]. Used on the night field, where
  /// grapefruit keeps text contrast.
  final String? accent;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final style = large
        ? Theme.of(context).textTheme.displayMedium
        : Theme.of(context).textTheme.headlineSmall;
    return Semantics(
      header: true,
      child: accent == null
          ? Text(text, style: style)
          : Text.rich(
              TextSpan(
                text: text,
                children: [
                  TextSpan(
                    text: accent,
                    style: TextStyle(color: accentColor),
                  ),
                ],
              ),
              style: style,
            ),
    );
  }
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
