import '../../discovery/domain/ingredient.dart';
import '../../discovery/domain/recipe.dart';

/// Folds [input] into a normalized search key: lowercase, Latin diacritics
/// removed, punctuation/symbols treated as word separators, and whitespace
/// collapsed. Non-Latin letters and digits are preserved untouched.
///
/// Used both to build the index (labels, aliases) and to prepare an
/// incoming query, so the two sides compare on identical terms.
String foldSearchText(String input) {
  final lower = input.toLowerCase();
  final buffer = StringBuffer();
  for (final rune in lower.runes) {
    final char = String.fromCharCode(rune);
    buffer.write(_diacriticFold[char] ?? char);
  }
  return buffer
      .toString()
      .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')
      .trim();
}

/// Latin diacritic folding table. Covers the accents named in the M11 plan
/// plus the rest of the common Latin-1/Latin Extended-A accented letters, so
/// folding is not surprising just outside the minimum list.
const Map<String, String> _diacriticFold = {
  'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a', 'ā': 'a',
  'ç': 'c', 'ć': 'c', 'č': 'c',
  'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e', 'ē': 'e', 'ė': 'e', 'ę': 'e',
  'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i', 'ī': 'i',
  'ñ': 'n', 'ń': 'n',
  'ò': 'o', 'ó': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o', 'ø': 'o', 'ō': 'o',
  'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u', 'ū': 'u',
  'ý': 'y', 'ÿ': 'y',
  'ß': 'ss',
  'æ': 'ae',
  'œ': 'oe',
};

/// What a [CatalogSuggestion] identifies.
enum CatalogSuggestionKind { recipe, ingredient }

/// One ranked search result: a recipe by name, or an ingredient identity.
final class CatalogSuggestion {
  const CatalogSuggestion({
    required this.kind,
    required this.id,
    required this.label,
    required this.recipeCount,
  });

  /// What kind of thing this suggestion points at.
  final CatalogSuggestionKind kind;

  /// Provider id for a recipe; normalized ingredient identity for an
  /// ingredient (see [normalizeIngredientName]).
  final String id;

  /// Display text: the recipe name, or the most common catalog spelling
  /// for the ingredient identity.
  final String label;

  /// 1 for a recipe; the number of distinct recipes using the ingredient
  /// identity for an ingredient.
  final int recipeCount;

  @override
  bool operator ==(Object other) =>
      other is CatalogSuggestion &&
      other.kind == kind &&
      other.id == id &&
      other.label == label &&
      other.recipeCount == recipeCount;

  @override
  int get hashCode => Object.hash(kind, id, label, recipeCount);

  @override
  String toString() =>
      'CatalogSuggestion(kind: $kind, id: $id, label: $label, '
      'recipeCount: $recipeCount)';
}

/// One indexed, precomputed entry: a recipe name or an ingredient identity.
class _Entry {
  const _Entry({
    required this.kind,
    required this.id,
    required this.label,
    required this.recipeCount,
    required this.foldedLabel,
    required this.labelWords,
    required this.exactMatchTexts,
  });

  final CatalogSuggestionKind kind;
  final String id;
  final String label;
  final int recipeCount;

  /// [foldSearchText] applied to [label]; precomputed once at construction.
  final String foldedLabel;

  /// [foldedLabel] split on spaces (empty only when the label folds away
  /// entirely, e.g. an all-punctuation name).
  final List<String> labelWords;

  /// Folded strings that count as an exact-tier match for this entry: the
  /// folded label, the folded identity, and any reviewed alias spellings
  /// that resolve to this identity (ingredients only).
  final Set<String> exactMatchTexts;

  CatalogSuggestion toSuggestion() =>
      CatalogSuggestion(
        kind: kind,
        id: id,
        label: label,
        recipeCount: recipeCount,
      );
}

/// A pure Dart, in-memory ranked search index over the local catalog: every
/// recipe name and every ingredient identity (with reviewed aliases folded
/// in), rebuilt whenever the underlying catalog snapshot changes.
///
/// Performance: every label is folded into text and words once, at
/// construction ([fromRecipes]). [suggest] and [recipeIdsMatchingName] are a
/// single O(entries × query words) scan with O(1)-ish per-word comparisons
/// (typo tolerance is a direct O(word length) check, not a full
/// Damerau–Levenshtein DP table) followed by an O(k log k) sort of the
/// matches — comfortably interactive for the low thousands of entries this
/// catalog holds.
final class CatalogSearchIndex {
  CatalogSearchIndex._(
    List<_Entry> entries,
    Map<String, List<String>> ingredientRecipeIds,
  ) : _entries = List.unmodifiable(entries),
      _ingredientRecipeIds = Map.unmodifiable(ingredientRecipeIds);

  /// Builds the index from every recipe's name and ingredients.
  ///
  /// Each ingredient identity ([normalizeIngredientName]) becomes one entry,
  /// labeled with its most common raw catalog spelling (ties broken
  /// alphabetically) and counted by the number of distinct recipes using it.
  /// Reviewed [ingredientAliases] keys that resolve to an identity present
  /// in the catalog are folded in as additional exact-match spellings for
  /// that identity, so an alias never creates a duplicate entry.
  factory CatalogSearchIndex.fromRecipes(Iterable<Recipe> recipes) {
    final recipeList = recipes.toList(growable: false);

    final entries = <_Entry>[
      for (final recipe in recipeList) _recipeEntry(recipe),
    ];

    // identity -> {raw spelling -> occurrence count}
    final spellingCounts = <String, Map<String, int>>{};
    // identity -> {recipe id -> recipe name} (map dedupes by recipe)
    final recipesByIdentity = <String, Map<String, String>>{};

    for (final recipe in recipeList) {
      final seenIdentities = <String>{};
      for (final ingredient in recipe.ingredients) {
        final identity = ingredient.normalizedName;
        final counts = spellingCounts.putIfAbsent(identity, () => {});
        counts.update(
          ingredient.name,
          (count) => count + 1,
          ifAbsent: () => 1,
        );
        if (seenIdentities.add(identity)) {
          recipesByIdentity
              .putIfAbsent(identity, () => {})[recipe.id] = recipe.name;
        }
      }
    }

    final aliasesByIdentity = <String, List<String>>{};
    for (final alias in ingredientAliases.entries) {
      aliasesByIdentity.putIfAbsent(alias.value, () => []).add(alias.key);
    }

    final ingredientRecipeIds = <String, List<String>>{};
    for (final identity in spellingCounts.keys) {
      final recipeMap = recipesByIdentity[identity]!;
      final sortedIds = recipeMap.keys.toList()
        ..sort((a, b) {
          final byName = foldSearchText(
            recipeMap[a]!,
          ).compareTo(foldSearchText(recipeMap[b]!));
          return byName != 0 ? byName : a.compareTo(b);
        });
      ingredientRecipeIds[identity] = List.unmodifiable(sortedIds);

      entries.add(
        _ingredientEntry(
          identity: identity,
          spellingCounts: spellingCounts[identity]!,
          recipeCount: sortedIds.length,
          aliases: aliasesByIdentity[identity] ?? const [],
        ),
      );
    }

    return CatalogSearchIndex._(entries, ingredientRecipeIds);
  }

  /// The empty index: every query returns no suggestions or ids.
  static final CatalogSearchIndex empty = CatalogSearchIndex.fromRecipes(
    const [],
  );

  final List<_Entry> _entries;
  final Map<String, List<String>> _ingredientRecipeIds;

  static _Entry _recipeEntry(Recipe recipe) {
    final folded = foldSearchText(recipe.name);
    return _Entry(
      kind: CatalogSuggestionKind.recipe,
      id: recipe.id,
      label: recipe.name,
      recipeCount: 1,
      foldedLabel: folded,
      labelWords: _words(folded),
      exactMatchTexts: {folded},
    );
  }

  static _Entry _ingredientEntry({
    required String identity,
    required Map<String, int> spellingCounts,
    required int recipeCount,
    required List<String> aliases,
  }) {
    final spellings = spellingCounts.keys.toList()
      ..sort((a, b) {
        final byCount = spellingCounts[b]!.compareTo(spellingCounts[a]!);
        return byCount != 0 ? byCount : a.compareTo(b);
      });
    final label = spellings.first;
    final folded = foldSearchText(label);
    final exactMatchTexts = <String>{folded, foldSearchText(identity)};
    for (final alias in aliases) {
      exactMatchTexts.add(foldSearchText(alias));
    }
    return _Entry(
      kind: CatalogSuggestionKind.ingredient,
      id: identity,
      label: label,
      recipeCount: recipeCount,
      foldedLabel: folded,
      labelWords: _words(folded),
      exactMatchTexts: exactMatchTexts,
    );
  }

  static List<String> _words(String folded) =>
      folded.isEmpty ? const [] : folded.split(' ');

  /// The default suggestion kinds: both recipes and ingredients.
  static const _defaultKinds = {
    CatalogSuggestionKind.recipe,
    CatalogSuggestionKind.ingredient,
  };

  /// Ranked suggestions for [query], best match first, capped at [limit].
  ///
  /// An empty or whitespace-only query returns no suggestions. An empty
  /// [kinds] returns no suggestions. [limit] must be positive.
  List<CatalogSuggestion> suggest(
    String query, {
    Set<CatalogSuggestionKind> kinds = _defaultKinds,
    int limit = 8,
  }) {
    if (limit <= 0) {
      throw ArgumentError.value(limit, 'limit', 'must be greater than zero');
    }
    if (kinds.isEmpty) return const [];
    final prepared = _prepareQuery(query);
    if (prepared == null) return const [];
    final matches = _match(prepared.folded, prepared.words, kinds);
    return [
      for (final match in matches.take(limit)) match.$2.toSuggestion(),
    ];
  }

  /// Every recipe whose name matches [query], ranked, no limit. Tier-5
  /// (typo) matches are included only when tiers 1–4 return nothing at all
  /// (finding #10) — otherwise a query with plenty of real matches (e.g.
  /// "sour") would also pull in unrelated one-edit-distance noise.
  List<String> recipeIdsMatchingName(String query) {
    final prepared = _prepareQuery(query);
    if (prepared == null) return const [];
    final matches = _match(prepared.folded, prepared.words, const {
      CatalogSuggestionKind.recipe,
    });
    final hasNonTypoMatch = matches.any((match) => match.$1 <= 4);
    final ranked = hasNonTypoMatch
        ? matches.where((match) => match.$1 <= 4)
        : matches;
    return [for (final match in ranked) match.$2.id];
  }

  /// Recipe ids that use the ingredient identity named by [identity] (after
  /// [normalizeIngredientName]), ordered by folded recipe name then id.
  ///
  /// [normalizeIngredientName] only lowercases and collapses whitespace —
  /// it does not fold diacritics — so free text like "creme de cassis"
  /// normalizes to an identity that never exactly matches the catalog's own
  /// "crème de cassis". When the direct lookup misses, this falls back to
  /// an exact *folded* match ([foldSearchText]) against every ingredient
  /// entry's label, identity and reviewed aliases (finding #11), so the
  /// same free text a person would type for that ingredient still resolves
  /// to it. An unknown or blank identity returns an empty list.
  List<String> recipeIdsWithIngredient(String identity) {
    final String normalized;
    try {
      normalized = normalizeIngredientName(identity);
    } on FormatException {
      return const [];
    }
    final direct = _ingredientRecipeIds[normalized];
    if (direct != null) return direct;
    final folded = foldSearchText(identity);
    if (folded.isEmpty) return const [];
    for (final entry in _entries) {
      if (entry.kind == CatalogSuggestionKind.ingredient &&
          entry.exactMatchTexts.contains(folded)) {
        return _ingredientRecipeIds[entry.id] ?? const [];
      }
    }
    return const [];
  }

  /// Folds and defensively truncates [query]; returns null when there is
  /// nothing left to search for.
  ({String folded, List<String> words})? _prepareQuery(String query) {
    var folded = foldSearchText(query);
    if (folded.length > 100) {
      folded = folded.substring(0, 100).trim();
    }
    if (folded.isEmpty) return null;
    return (folded: folded, words: folded.split(' '));
  }

  List<(int, _Entry)> _match(
    String folded,
    List<String> words,
    Set<CatalogSuggestionKind> kinds,
  ) {
    final matches = <(int, _Entry)>[
      for (final entry in _entries)
        if (kinds.contains(entry.kind))
          if (_tierFor(entry, folded, words) case final int tier)
            (tier, entry),
    ];
    matches.sort(_compareMatches);
    return matches;
  }

  static int _kindOrder(CatalogSuggestionKind kind) =>
      kind == CatalogSuggestionKind.ingredient ? 0 : 1;

  static int _compareMatches((int, _Entry) a, (int, _Entry) b) {
    final byTier = a.$1.compareTo(b.$1);
    if (byTier != 0) return byTier;
    final byCount = b.$2.recipeCount.compareTo(a.$2.recipeCount);
    if (byCount != 0) return byCount;
    final byLabel = a.$2.foldedLabel.compareTo(b.$2.foldedLabel);
    if (byLabel != 0) return byLabel;
    final byKind = _kindOrder(a.$2.kind).compareTo(_kindOrder(b.$2.kind));
    if (byKind != 0) return byKind;
    return a.$2.id.compareTo(b.$2.id);
  }

  /// Best matching tier for [entry] against the already-folded [query] and
  /// its [queryWords], or null when it does not match at all.
  ///
  /// 1 exact (folded label, identity or alias); 2 prefix of the full label;
  /// 3 every query word is a prefix of some label word, in label order; 4
  /// substring of the full label; 5 typo tolerance (queries of 4+ folded
  /// characters only; see [_matchesWordForTypo]).
  static int? _tierFor(_Entry entry, String query, List<String> queryWords) {
    if (entry.exactMatchTexts.contains(query)) return 1;
    if (entry.foldedLabel.startsWith(query)) return 2;
    if (_wordPrefixInOrder(queryWords, entry.labelWords)) return 3;
    if (entry.foldedLabel.contains(query)) return 4;
    if (query.length >= 4 &&
        queryWords.every((word) => _matchesWordForTypo(word, entry.labelWords))) {
      return 5;
    }
    return null;
  }

  /// True when every word in [queryWords] is a prefix of some word in
  /// [labelWords], matched in order (each match must come at or after the
  /// previous one), so "old fash" matches "Old Fashioned" but not a label
  /// whose words appear in the opposite order.
  static bool _wordPrefixInOrder(
    List<String> queryWords,
    List<String> labelWords,
  ) {
    if (queryWords.isEmpty || labelWords.isEmpty) return false;
    var searchFrom = 0;
    for (final queryWord in queryWords) {
      var found = -1;
      for (var i = searchFrom; i < labelWords.length; i++) {
        if (labelWords[i].startsWith(queryWord)) {
          found = i;
          break;
        }
      }
      if (found == -1) return false;
      searchFrom = found + 1;
    }
    return true;
  }

  /// Whether [queryWord] passes typo tolerance against some word in
  /// [labelWords]. Words shorter than 4 characters get no tolerance at all
  /// — they must be a literal prefix of a label word.
  static bool _matchesWordForTypo(String queryWord, List<String> labelWords) {
    if (queryWord.length < 4) {
      return labelWords.any((word) => word.startsWith(queryWord));
    }
    return labelWords.any((word) => _typoMatchesWord(queryWord, word));
  }

  /// [queryWord] matches [labelWord] within one Damerau–Levenshtein edit,
  /// either against the full word (query words of 4+ chars, per
  /// [_matchesWordForTypo]) or against its prefix of equal length — a typo
  /// made partway through typing a longer word — which needs query words of
  /// 5+ chars: at 4 chars the equal-length prefix rule matched too many
  /// unrelated short words (finding #10).
  static bool _typoMatchesWord(String queryWord, String labelWord) {
    if (_withinOneEdit(queryWord, labelWord)) return true;
    if (queryWord.length >= 5 && labelWord.length >= queryWord.length) {
      final prefix = labelWord.substring(0, queryWord.length);
      if (_withinOneEdit(queryWord, prefix)) return true;
    }
    return false;
  }

  /// True when [a] and [b] are equal or exactly one insertion, deletion,
  /// substitution or adjacent transposition apart. Linear time, no DP
  /// table: the words involved are short and this runs per query word per
  /// candidate entry, so it needs to stay cheap.
  static bool _withinOneEdit(String a, String b) {
    if (a == b) return true;
    final lengthDiff = a.length - b.length;
    if (lengthDiff.abs() > 1) return false;
    if (lengthDiff == 0) return _withinOneEditSameLength(a, b);
    final shorter = lengthDiff > 0 ? b : a;
    final longer = lengthDiff > 0 ? a : b;
    var i = 0, j = 0;
    var skipped = false;
    while (i < shorter.length && j < longer.length) {
      if (shorter[i] == longer[j]) {
        i++;
        j++;
      } else {
        if (skipped) return false;
        skipped = true;
        j++;
      }
    }
    return true;
  }

  static bool _withinOneEditSameLength(String a, String b) {
    final diffs = <int>[];
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        diffs.add(i);
        if (diffs.length > 2) return false;
      }
    }
    if (diffs.length <= 1) return true;
    final first = diffs[0], second = diffs[1];
    return second == first + 1 && a[first] == b[second] && a[second] == b[first];
  }
}
