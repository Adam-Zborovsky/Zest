import 'package:flutter/material.dart';

import '../design/zest_tokens.dart';

class ZestCard extends StatelessWidget {
  const ZestCard({
    super.key,
    required this.child,
    this.recipe = false,
    this.color,
    this.padding = const EdgeInsets.all(ZestSpace.page),
  });

  final Widget child;
  final bool recipe;
  final Color? color;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Card(
    color: color,
    shape: recipe
        ? RoundedRectangleBorder(
            borderRadius: ZestShape.recipe,
            side: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          )
        : null,
    child: Padding(padding: padding, child: child),
  );
}
