import 'package:flutter/material.dart';

import '../design/zest_tokens.dart';
import 'botanical_art.dart';

enum ZestTileTone { grapefruit, night }

/// A large cut-paper action tile: asymmetric recipe corners, an ink outline,
/// and a hard offset shadow the tile sinks into while pressed. Under reduced
/// motion the sink is immediate. Native InkWell semantics expose it as a
/// button labelled by its title and caption.
class ZestActionTile extends StatefulWidget {
  const ZestActionTile({
    super.key,
    required this.title,
    required this.caption,
    required this.motif,
    required this.onPressed,
    this.tone = ZestTileTone.grapefruit,
  });

  final String title;
  final String caption;
  final BotanicalMotif motif;
  final VoidCallback onPressed;
  final ZestTileTone tone;

  @override
  State<ZestActionTile> createState() => _ZestActionTileState();
}

class _ZestActionTileState extends State<ZestActionTile> {
  static const _lift = 4.0;

  bool _pressed = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final night = widget.tone == ZestTileTone.night;
    final background = night ? ZestPalette.night : ZestPalette.grapefruit;
    final ink = night ? ZestPalette.nightInk : ZestPalette.leaf;
    final shadow = night ? ZestPalette.grapefruit : ZestPalette.leaf;
    final reduced = ZestMotion.reduced(context);
    final lift = _pressed ? 0.0 : _lift;
    final radius = ZestShape.recipe.resolve(Directionality.of(context));
    final textTheme = Theme.of(context).textTheme;
    return AnimatedContainer(
      duration: ZestMotion.duration(context, ZestMotion.feedback),
      curve: ZestMotion.easeOut,
      transform: Matrix4.translationValues(_lift - lift, _lift - lift, 0),
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: ZestShadow.hard(shadow, offset: lift),
      ),
      child: Material(
        color: background,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(
            color: _focused
                ? (night ? ZestPalette.grapefruit : ZestPalette.leaf)
                : ZestPalette.leaf,
            width: _focused ? 3 : 1.5,
          ),
        ),
        child: InkWell(
          onTap: widget.onPressed,
          onHighlightChanged: (value) => setState(() => _pressed = value),
          onFocusChange: (value) => setState(() => _focused = value),
          splashFactory: reduced ? NoSplash.splashFactory : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 136),
            child: Padding(
              padding: const EdgeInsets.all(ZestSpace.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Align(
                    alignment: AlignmentDirectional.topEnd,
                    child: BotanicalArt(motif: widget.motif, size: 52),
                  ),
                  const SizedBox(height: ZestSpace.sm),
                  Text(
                    widget.title,
                    style: textTheme.headlineSmall!.copyWith(color: ink),
                  ),
                  const SizedBox(height: ZestSpace.xs),
                  Text(
                    widget.caption,
                    style: textTheme.labelMedium!.copyWith(color: ink),
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
