/// Completion record for one browsed letter as reported by the catalog
/// store. A letter absent from `CatalogRepository.letterStatuses()` is still
/// pending; every status in the map is a fully applied (synced) letter.
final class CatalogLetterStatus {
  const CatalogLetterStatus({
    required this.letter,
    required this.completedAt,
    required this.recipeCount,
  });

  final String letter;
  final DateTime? completedAt;
  final int recipeCount;
}

/// What the on-device catalog currently holds, and nothing more.
///
/// Counts here are **collection prevalence**: they describe exactly the
/// recipes loaded by the A–Z browses completed so far. Completing all 26
/// letter browses means every browse returned, not that the provider catalog
/// was proven exhausted — letters can return zero records, records can shift
/// between letters, and no full-catalog count is available through the
/// supported endpoints. Any screen showing these counts must label them as
/// the loaded collection; see [completenessGuidance] for the agreed wording.
final class CoverageReport {
  const CoverageReport({
    required this.lettersCompleted,
    this.lettersTotal = 26,
    required this.recipeCount,
    required this.lastCompletedAt,
  });

  final int lettersCompleted;
  final int lettersTotal;
  final int recipeCount;
  final DateTime? lastCompletedAt;

  /// True when all 26 letter browses have completed. This certifies the
  /// sync's own bookkeeping only — never catalog completeness.
  bool get isAtoZComplete => lettersCompleted == lettersTotal;

  /// Agreed copy for the finished coverage surface — the sync card's
  /// "Collection loaded" state, the only place that presents a completed
  /// A–Z run (M5 roadmap: "Do not equate completed A–Z sync with proven
  /// full-catalog completeness"). Idle and syncing cards show counts
  /// through the coverage line and the identified-collection label without
  /// this sentence.
  static const completenessGuidance =
      'Counts describe the recipes loaded on this device from the letters '
      'browsed so far — they are not a claim about the full provider '
      'catalog. Completing every A–Z browse does not prove the catalog is '
      'exhausted.';
}
