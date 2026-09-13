import 'package:flutter/material.dart';

import '../../../core/design/zest_tokens.dart';
import '../../../core/widgets/botanical_paper.dart';
import '../../../core/widgets/zest_card.dart';
import '../../constellation/domain/ingredient_kind.dart';
import '../../constellation/presentation/ingredient_glyph.dart';
import 'onboarding_entrance.dart';

class _DemoIngredient {
  const _DemoIngredient(this.name, this.measure, {this.changesTo});

  final String name;
  final String measure;

  /// The measure this row settles on once the one-shot entrance plays; null
  /// for rows that never change.
  final String? changesTo;
}

const _ingredients = [
  _DemoIngredient('White rum', '60 ml'),
  _DemoIngredient('Lime juice', '25 ml', changesTo: '30 ml'),
  _DemoIngredient('Rich syrup', '15 ml'),
];

/// The page-3 demo: a peach recipe card for a personal variation, with one
/// measure changing once as the page becomes current. Synthetic content;
/// the recipe itself is never mutated by this demo.
class OnboardingVariationDemo extends StatelessWidget {
  const OnboardingVariationDemo({super.key, required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Example of a personal recipe variation',
    child: ExcludeSemantics(
      child: OnboardingEntrance(
        active: active,
        duration: ZestMotion.enter,
        builder: (context, t) => ZestCard(
          recipe: true,
          color: ZestPalette.peach,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Your variation of Daiquiri',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge!.copyWith(color: ZestPalette.leaf),
              ),
              const SizedBox(height: ZestSpace.xs),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.info_outline_rounded,
                      size: 16,
                      color: ZestPalette.secondaryInk,
                    ),
                  ),
                  const SizedBox(width: ZestSpace.xs),
                  Flexible(
                    child: Text(
                      'The original recipe stays unchanged.',
                      style: Theme.of(context).textTheme.bodySmall!.copyWith(
                        color: ZestPalette.secondaryInk,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: ZestSpace.lg),
              for (final ingredient in _ingredients) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: ZestSpace.xs),
                  child: Row(
                    children: [
                      IngredientGlyph(kind: ingredientKindOf(ingredient.name), size: 32),
                      const SizedBox(width: ZestSpace.sm),
                      Expanded(
                        child: Text(
                          ingredient.name,
                          style: Theme.of(
                            context,
                          ).textTheme.bodyLarge!.copyWith(color: ZestPalette.leaf),
                        ),
                      ),
                      if (ingredient.changesTo == null)
                        PaperTag(label: ingredient.measure)
                      else
                        PaperTag(
                          label: t < 0.999 ? ingredient.measure : ingredient.changesTo!,
                          color: ZestPalette.grapefruit.withValues(alpha: 0.5),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
