import '../../discovery/domain/recipe.dart';

/// Attribution carried on every published catalog snapshot, per the frozen
/// `GET /api/catalog` wire shape in `docs/M11.md`.
final class CatalogAttribution {
  const CatalogAttribution({required this.name, required this.url});

  final String name;
  final Uri url;
}

/// One validated, versioned catalog snapshot as downloaded from the backend.
/// `drinks` are already parsed into the existing `Recipe` model — the wire
/// shape is provider-shaped records, identical to what the gateway returns.
final class CatalogSnapshot {
  const CatalogSnapshot({
    required this.version,
    required this.publishedAt,
    required this.recipeCount,
    required this.attribution,
    required this.drinks,
  });

  /// 64 lowercase hex characters: the SHA-256 of the canonical drinks JSON.
  final String version;
  final DateTime publishedAt;
  final int recipeCount;
  final CatalogAttribution attribution;
  final List<Recipe> drinks;
}

/// What the on-device catalog currently holds, from the last applied
/// snapshot — distinct from [CatalogSnapshot], which is a download in
/// flight. Returned by `CatalogRepository.currentSnapshot()`.
final class CatalogSnapshotInfo {
  const CatalogSnapshotInfo({
    required this.version,
    required this.publishedAt,
    required this.recipeCount,
    required this.appliedAt,
  });

  final String version;
  final DateTime publishedAt;
  final int recipeCount;
  final DateTime appliedAt;
}

/// The result of replacing the on-device catalog with a new snapshot:
/// counts the diff measured, plus the names of added recipes for notice
/// copy. "Changed" means the same provider id with different source JSON.
final class CatalogDiff {
  const CatalogDiff({
    required this.added,
    required this.removed,
    required this.changed,
    required this.addedRecipeNames,
  });

  final int added;
  final int removed;
  final int changed;
  final List<String> addedRecipeNames;

  bool get isNoOp => added == 0 && removed == 0 && changed == 0;
}
