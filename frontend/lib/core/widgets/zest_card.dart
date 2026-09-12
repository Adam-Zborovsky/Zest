import 'package:flutter/material.dart';

import '../design/zest_tokens.dart';

/// Peach paper. Ordinary cards stay flat with a quiet divider edge; recipe
/// cards are cut-paper objects — asymmetric corners, an ink outline, and a
/// hard offset shadow — so the things that lead somewhere read as objects.
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
  Widget build(BuildContext context) {
    if (!recipe) {
      return Card(
        color: color,
        child: Padding(padding: padding, child: child),
      );
    }
    final radius = ZestShape.recipe.resolve(Directionality.of(context));
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: ZestShadow.hard(ZestPalette.leaf, offset: 4),
      ),
      child: Card(
        color: color,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: const BorderSide(color: ZestPalette.leaf, width: 1.5),
        ),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
