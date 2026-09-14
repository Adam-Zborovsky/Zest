/// What the on-device catalog currently holds, and nothing more.
///
/// M11: the catalog is a single shared snapshot downloaded from the backend,
/// not a client-driven A–Z browse, so coverage no longer counts letters. It
/// still never claims the snapshot is the full provider catalog — the
/// backend's own refresh job states that boundary in `docs/SOURCES.md`.
final class CoverageReport {
  const CoverageReport({
    required this.recipeCount,
    required this.publishedAt,
    this.version,
  });

  final int recipeCount;

  /// When the applied snapshot was published by the backend; null before any
  /// snapshot has ever been applied.
  final DateTime? publishedAt;

  /// The applied snapshot's version (64 lowercase hex), when useful for
  /// diagnostics. Never shown to people.
  final String? version;

  bool get hasSnapshot => publishedAt != null;
}
