import 'package:flutter/material.dart';

import '../design/zest_tokens.dart';

/// A recoverable failure stated where it happened: an icon plus plain copy
/// that says what failed and what to do. Announced as a live region so a
/// screen reader hears it without moving focus. Meaning is carried by the
/// text and icon, never by color alone.
class ZestInlineError extends StatelessWidget {
  const ZestInlineError(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ExcludeSemantics(
          child: Icon(
            Icons.error_outline_rounded,
            size: 20,
            color: ZestPalette.berry,
          ),
        ),
        const SizedBox(width: ZestSpace.sm),
        Expanded(
          child: Text(
            message,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium!.copyWith(color: ZestPalette.berry),
          ),
        ),
      ],
    ),
  );
}
