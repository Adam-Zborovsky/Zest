/// Invented records for bar matching. No provider recipes are test assets.
Map<String, dynamic> barRecipeJson({
  String id = '99101',
  String name = 'Testbench Sour',
  List<(String, String?)> ingredients = const [
    ('Imaginary gin', '2 oz'),
    ('Pretend lime juice', '1 oz'),
  ],
}) => {
  'idDrink': id,
  'strDrink': name,
  'strInstructions': 'Stir the invented components. Keep the sentence whole.',
  'strGlass': 'Test glass',
  'strCategory': 'Synthetic test drink',
  'strAlcoholic': 'Alcoholic',
  for (var slot = 1; slot <= 15; slot++) ...{
    'strIngredient$slot': slot <= ingredients.length
        ? ingredients[slot - 1].$1
        : null,
    'strMeasure$slot': slot <= ingredients.length
        ? ingredients[slot - 1].$2
        : null,
  },
};
