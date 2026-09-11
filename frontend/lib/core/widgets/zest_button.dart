import 'package:flutter/material.dart';

import '../design/zest_tokens.dart';

enum ZestButtonKind { primary, secondary, quiet, danger }

class ZestButton extends StatelessWidget {
  const ZestButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.kind = ZestButtonKind.primary,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final ZestButtonKind kind;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 20),
          const SizedBox(width: ZestSpace.sm),
        ],
        Flexible(child: Text(label, textAlign: TextAlign.center)),
      ],
    );
    final duration = ZestMotion.duration(context, ZestMotion.feedback);
    final base = ButtonStyle(
      animationDuration: duration,
      splashFactory: ZestMotion.reduced(context)
          ? NoSplash.splashFactory
          : null,
    );
    final Widget button;
    if (kind == ZestButtonKind.quiet) {
      button = TextButton(onPressed: onPressed, style: base, child: content);
    } else {
      final secondary = kind == ZestButtonKind.secondary;
      final danger = kind == ZestButtonKind.danger;
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
        onPressed: onPressed,
        style: base.copyWith(
          side: WidgetStateProperty.resolveWith(
            (states) => BorderSide(
              color: states.contains(WidgetState.focused)
                  ? foreground
                  : Colors.transparent,
              width: 2,
            ),
          ),
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
    }
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}
