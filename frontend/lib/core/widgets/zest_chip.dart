import 'package:flutter/material.dart';

import '../design/zest_tokens.dart';

class ZestChip extends StatelessWidget {
  const ZestChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool>? onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final duration = ZestMotion.duration(context, ZestMotion.feedback);
    final animation = AnimationStyle(
      duration: duration,
      reverseDuration: duration,
    );
    final labelStyle = theme.textTheme.labelMedium!.copyWith(
      color: onSelected == null
          ? ZestPalette.disabledInk
          : selected
          ? theme.colorScheme.onPrimary
          : theme.colorScheme.onSecondaryContainer,
    );
    return FilterChip(
      // Keep the checkmark inside the measured label: RawChip's own avatar
      // slot grows with multiline text and can clip the final wrapped line.
      label: DefaultTextStyle(
        style: labelStyle,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              ExcludeSemantics(
                child: Icon(
                  Icons.check_rounded,
                  size: 18,
                  color: labelStyle.color,
                ),
              ),
              const SizedBox(width: ZestSpace.xs),
            ],
            Flexible(child: Text(label, softWrap: true)),
          ],
        ),
      ),
      selected: selected,
      onSelected: onSelected,
      showCheckmark: false,
      labelStyle: labelStyle,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      chipAnimationStyle: ChipAnimationStyle(
        enableAnimation: animation,
        selectAnimation: animation,
        avatarDrawerAnimation: animation,
        deleteDrawerAnimation: animation,
      ),
    );
  }
}
