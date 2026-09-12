/// Zest's display grouping for normalized ingredient identities. It exists
/// only to color and draw constellation glyphs and ingredient rows.
///
/// The grouping reads the whole words of a name — never substrings, so
/// "ginger" is not "gin" — and says nothing about flavor, taste
/// compatibility, or strength. Anything it does not recognize stays in
/// [IngredientKind.other] rather than being guessed. Rules are applied in a
/// fixed order so a name that mentions two groups resolves predictably:
/// liqueurs and bitters first ("orange bitters"), then spirits, then mixers
/// (which fall to other: "ginger ale"), then citrus, sweeteners, and herbs.
enum IngredientKind {
  spirit('Spirits'),
  liqueur('Liqueurs & bitters'),
  citrus('Citrus'),
  sweet('Sweeteners'),
  herbal('Herbs & spice'),
  other('Everything else');

  const IngredientKind(this.label);

  final String label;
}

IngredientKind ingredientKindOf(String identity) {
  final name = identity.trim().toLowerCase();
  final words = name
      .split(RegExp(r'[^a-zà-ÿ]+'))
      .where((word) => word.isNotEmpty)
      .toSet();
  bool hasWord(Set<String> vocabulary) => words.any(vocabulary.contains);

  if (hasWord(_liqueurWords) || _liqueurPhrases.any(name.contains)) {
    return IngredientKind.liqueur;
  }
  if (hasWord(_spiritWords)) return IngredientKind.spirit;
  if (hasWord(_mixerWords)) return IngredientKind.other;
  if (hasWord(_citrusWords)) return IngredientKind.citrus;
  if (hasWord(_sweetWords)) return IngredientKind.sweet;
  if (hasWord(_herbalWords)) return IngredientKind.herbal;
  return IngredientKind.other;
}

const _liqueurWords = {
  'bitters',
  'campari',
  'aperol',
  'amaro',
  'liqueur',
  'schnapps',
  'cointreau',
  'curacao',
  'kahlua',
  'amaretto',
  'chartreuse',
  'benedictine',
  'sambuca',
  'galliano',
  'vermouth',
  'frangelico',
  'midori',
  'baileys',
  'drambuie',
  'jagermeister',
  'pernod',
  'pastis',
  'ouzo',
  'lillet',
};

const _liqueurPhrases = ['triple sec', 'grand marnier', 'creme de', 'crème de'];

const _spiritWords = {
  'gin',
  'vodka',
  'rum',
  'tequila',
  'mezcal',
  'whiskey',
  'whisky',
  'bourbon',
  'scotch',
  'rye',
  'brandy',
  'cognac',
  'armagnac',
  'pisco',
  'cachaca',
  'absinthe',
  'everclear',
  'grappa',
  'calvados',
  'applejack',
  'aquavit',
  'akvavit',
  'soju',
};

const _mixerWords = {
  'soda',
  'tonic',
  'water',
  'cola',
  'ale',
  'beer',
  'lemonade',
  'milk',
  'cream',
  'coffee',
  'tea',
  'wine',
  'champagne',
  'prosecco',
  'cider',
};

const _citrusWords = {
  'lemon',
  'lime',
  'orange',
  'grapefruit',
  'citrus',
  'yuzu',
  'clementine',
  'tangerine',
  'mandarin',
};

const _sweetWords = {
  'sugar',
  'syrup',
  'honey',
  'grenadine',
  'agave',
  'molasses',
  'orgeat',
  'falernum',
  'cordial',
  'sweetener',
};

const _herbalWords = {
  'mint',
  'basil',
  'rosemary',
  'thyme',
  'sage',
  'lavender',
  'cucumber',
  'ginger',
  'cinnamon',
  'nutmeg',
  'clove',
  'cloves',
  'cardamom',
  'pepper',
  'celery',
  'elderflower',
  'anise',
  'vanilla',
};
