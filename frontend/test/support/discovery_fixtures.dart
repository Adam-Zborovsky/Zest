import 'dart:convert';

import 'package:http/http.dart' as http;

/// Invented records only. No provider recipes or images are test assets.
Map<String, dynamic> discoveryRecipe({
  String id = '99001',
  String name = 'Paper Garden 1',
  String? thumbnailUrl,
}) => {
  'idDrink': id,
  'strDrink': name,
  'strDrinkThumb': thumbnailUrl,
  'strInstructions':
      'Stir the imaginary ingredients. Keep this sentence together.\n\n'
      'Serve in a paper cup; garnish with a fictional leaf.',
  'strIngredient1': 'Imaginary leaf syrup',
  'strMeasure1': '1 1/2 oz',
  'strIngredient2': 'Pretend sparkling water',
  'strMeasure2': 'a small splash',
  'strGlass': 'Paper cup',
  'strCategory': 'Synthetic test drink',
  'strAlcoholic': 'Non alcoholic',
  'strImageAttribution': 'Synthetic illustrator',
};

List<Map<String, dynamic>> discoveryRecipes([int count = 8]) => [
  for (var index = 1; index <= count; index++)
    discoveryRecipe(id: '${99000 + index}', name: 'Paper Garden $index'),
];

Map<String, dynamic> discoverySummary(Map<String, dynamic> recipe) => {
  'idDrink': recipe['idDrink'],
  'strDrink': recipe['strDrink'],
  'strDrinkThumb': recipe['strDrinkThumb'],
};

http.Response discoveryResponse(List<Map<String, dynamic>>? drinks) =>
    http.Response(
      jsonEncode({'drinks': drinks}),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
