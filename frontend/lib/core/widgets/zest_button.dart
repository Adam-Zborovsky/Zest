import 'package:flutter/material.dart';

import '../design/zest_tokens.dart';

enum ZestButtonKind { primary, secondary, quiet, danger }

/// Zest's button. Primary and danger buttons sit on a hard cut-paper shadow
/// and sink into it while pressed; secondary buttons are inked celery paper;
/// quiet buttons are text only. Reduced motion makes the sink immediate.
class ZestButton extends StatefulWidget {
  const ZestButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.kind = ZestButtonKind.primary,
    this.expand = true,
    this.semanticLabel,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final ZestButtonKind kind;
  final bool expand;
  final String? semanticLabel;

  @override
  State<ZestButton> createState() => _ZestButtonState();
}

class _ZestButtonState extends State<ZestButton> {
  static const _lift = 3.0;

  final _states = WidgetStatesController();
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _states.addListener(_syncPressed);
  }

  void _syncPressed() {
    final pressed = _states.value.contains(WidgetState.pressed);
    if (pressed != _pressed) setState(() => _pressed = pressed);
  }

  @override
  void dispose() {
    _states
      ..removeListener(_syncPressed)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.icon != null) ...[
          Icon(widget.icon, size: 20),
          const SizedBox(width: ZestSpace.sm),
        ],
        Flexible(
          child: Text(
            widget.label,
            semanticsLabel: widget.semanticLabel,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
    final duration = ZestMotion.duration(context, ZestMotion.feedback);
    final base = ButtonStyle(
      animationDuration: duration,
      splashFactory: ZestMotion.reduced(context)
          ? NoSplash.splashFactory
          : null,
    );
    Widget button;
    if (widget.kind == ZestButtonKind.quiet) {
      button = TextButton(
        onPressed: widget.onPressed,
        style: base,
        child: content,
      );
    } else {
      final secondary = widget.kind == ZestButtonKind.secondary;
      final danger = widget.kind == ZestButtonKind.danger;
      final background = danger
          ? colors.error
          : secondary
          ? colors.secondaryContainer
          : colors.primary;
      final foreground = danger
          ? colors.onError
          : secondary
          ? colors.onSecondaryContainer
          : colors.onPrimary;
      button = FilledButton(
        onPressed: widget.onPressed,
        statesController: _states,
        style: base.copyWith(
          side: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.focused)) {
              return BorderSide(color: foreground, width: 3);
            }
            if (secondary && !states.contains(WidgetState.disabled)) {
              return const BorderSide(color: ZestPalette.leaf, width: 1.5);
            }
            return const BorderSide(color: Colors.transparent, width: 2);
          }),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) =>
                states.contains(WidgetState.disabled) ? null : background,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) =>
                states.contains(WidgetState.disabled) ? null : foreground,
          ),
        ),
        child: content,
      );
      if (!secondary && widget.onPressed != null) {
        final lift = _pressed ? 0.0 : _lift;
        button = AnimatedContainer(
          duration: duration,
          curve: ZestMotion.easeOut,
          transform: Matrix4.translationValues(_lift - lift, _lift - lift, 0),
          decoration: BoxDecoration(
            borderRadius: ZestShape.control,
            boxShadow: ZestShadow.hard(
              danger ? ZestPalette.leaf : ZestPalette.grapefruit,
              offset: lift,
            ),
          ),
          child: button,
        );
      }
    }
    return widget.expand
        ? SizedBox(width: double.infinity, child: button)
        : button;
  }
}
