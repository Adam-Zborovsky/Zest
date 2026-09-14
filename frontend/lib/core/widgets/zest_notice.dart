import 'package:flutter/material.dart';

import '../design/zest_tokens.dart';

/// A dismissable, screen-reader-announced status notice — Zest's themed
/// alternative to a generic Material `SnackBar`, used for catalog update
/// notices (`docs/M11.md`). Rendered as a floating card pinned to the
/// bottom of the screen via the nearest [Overlay]; stays on screen until
/// dismissed or its action is activated (which also dismisses it) — never
/// auto-hides on a timer, so a person reading it never has it vanish mid-read.
///
/// Accessibility: the whole notice is one polite live region (never
/// `assertive` — this is a routine status update, not an alarm), the close
/// control is a real 48×48 logical-pixel button with a `Dismiss` label, the
/// action (when present) is a real button reachable by keyboard focus
/// traversal, and message/action/dismiss stack vertically so nothing
/// overflows at 320 logical pixels with 2x text.
class ZestNotice extends StatelessWidget {
  const ZestNotice({
    super.key,
    required this.message,
    this.actionLabel,
    this.onAction,
    required this.onDismiss,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      liveRegion: true,
      child: Material(
        color: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: ZestSpace.contentWidth),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: ZestPalette.leaf,
              borderRadius: ZestShape.control,
              boxShadow: ZestShadow.hard(ZestPalette.moss),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                ZestSpace.lg,
                ZestSpace.md,
                ZestSpace.sm,
                ZestSpace.sm,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(
                      right: ZestSpace.md,
                      bottom: ZestSpace.xs,
                    ),
                    child: Text(
                      message,
                      style: textTheme.bodyMedium?.copyWith(
                        color: ZestPalette.nightInk,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (actionLabel != null)
                        TextButton(
                          key: const ValueKey('zest-notice-action'),
                          onPressed: () {
                            onAction?.call();
                            onDismiss();
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: ZestPalette.grapefruit,
                            minimumSize: const Size(
                              ZestSpace.touchTarget,
                              ZestSpace.touchTarget,
                            ),
                          ),
                          child: Text(actionLabel!),
                        ),
                      SizedBox(
                        width: ZestSpace.touchTarget,
                        height: ZestSpace.touchTarget,
                        child: IconButton(
                          key: const ValueKey('zest-notice-dismiss'),
                          tooltip: 'Dismiss',
                          icon: const Icon(Icons.close_rounded),
                          color: ZestPalette.nightMuted,
                          onPressed: onDismiss,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Hosts one [ZestNotice] in the nearest root [Overlay] and owns its own
/// enter/exit animation, so [showZestNotice] never needs a `TickerProvider`
/// of its own. Reduced motion (`ZestMotion.reduced`) skips the animation
/// entirely — the notice appears and disappears on the very next frame.
class _ZestNoticeHost extends StatefulWidget {
  const _ZestNoticeHost({
    required this.message,
    required this.actionLabel,
    required this.onAction,
    required this.onRemove,
    required this.reduced,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback onRemove;
  final bool reduced;

  @override
  State<_ZestNoticeHost> createState() => _ZestNoticeHostState();
}

class _ZestNoticeHostState extends State<_ZestNoticeHost>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.reduced ? Duration.zero : ZestMotion.enter,
    reverseDuration: widget.reduced ? Duration.zero : ZestMotion.exit,
  );
  late final Animation<double> _entrance = CurvedAnimation(
    parent: _controller,
    curve: ZestMotion.easeOut,
  );

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  Future<void> _dismiss() async {
    await _controller.reverse();
    widget.onRemove();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: ZestSpace.lg,
      right: ZestSpace.lg,
      bottom: ZestSpace.lg,
      child: SafeArea(
        top: false,
        child: FadeTransition(
          opacity: _entrance,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.15),
              end: Offset.zero,
            ).animate(_entrance),
            child: ZestNotice(
              message: widget.message,
              actionLabel: widget.actionLabel,
              onAction: widget.onAction,
              onDismiss: _dismiss,
            ),
          ),
        ),
      ),
    );
  }
}

OverlayEntry? _activeZestNoticeEntry;

/// Shows a [ZestNotice] over the current screen. A notice already showing is
/// replaced rather than stacked. Returns nothing: the notice manages its own
/// dismissal (by the person, or by activating [actionLabel]).
///
/// Takes the [OverlayState] directly rather than a [BuildContext]: the app
/// shell hosts this notice's listener above the router (finding #3/#7), so
/// the only context it holds — the `Navigator`'s own — is an *ancestor* of
/// the overlay, not a descendant, and `Overlay.of(context)` would search the
/// wrong direction and throw "No Overlay widget found". Callers reach the
/// overlay via `navigatorKey.currentState?.overlay` instead.
void showZestNotice(
  OverlayState overlayState, {
  required String message,
  String? actionLabel,
  VoidCallback? onAction,
}) {
  _activeZestNoticeEntry?.remove();
  final reduced = ZestMotion.reduced(overlayState.context);
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => _ZestNoticeHost(
      message: message,
      actionLabel: actionLabel,
      onAction: onAction,
      reduced: reduced,
      onRemove: () {
        entry.remove();
        if (identical(_activeZestNoticeEntry, entry)) {
          _activeZestNoticeEntry = null;
        }
      },
    ),
  );
  _activeZestNoticeEntry = entry;
  overlayState.insert(entry);
}
