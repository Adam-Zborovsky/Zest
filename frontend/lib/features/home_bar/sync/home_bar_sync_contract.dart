import '../../collection/sync/sync_contract.dart' show SyncStatus;
import '../domain/home_bar_item.dart';

/// One home-bar item as it travels over the accounts API.
final class HomeBarRecord {
  HomeBarRecord({
    required this.ingredientId,
    required this.displayName,
    required this.location,
    required this.updatedAt,
    required this.deleted,
    this.revision,
  }) : _item = HomeBarItem(
         ingredientId: ingredientId,
         displayName: displayName,
         location: location,
         updatedAt: updatedAt,
         deleted: deleted,
         revision: revision,
       );

  factory HomeBarRecord.fromJson(Map<String, Object?> json) {
    final ingredientId = json['ingredientId'];
    final displayName = json['displayName'];
    final location = json['location'];
    final updatedAt = json['updatedAt'];
    final deleted = json['deleted'];
    final revision = json['revision'];
    if (ingredientId is! String ||
        displayName is! String ||
        location is! String ||
        updatedAt is! String ||
        deleted is! bool ||
        (revision != null && (revision is! int || revision < 0))) {
      throw const FormatException('Invalid home-bar record.');
    }
    final parsedTime = DateTime.tryParse(updatedAt);
    if (parsedTime == null) throw const FormatException('Invalid timestamp.');
    final parsedLocation = switch (location) {
      'stocked' => HomeBarLocation.stocked,
      'shopping' => HomeBarLocation.shopping,
      _ => throw const FormatException('Invalid home-bar location.'),
    };
    try {
      return HomeBarRecord(
        ingredientId: ingredientId,
        displayName: displayName,
        location: parsedLocation,
        updatedAt: parsedTime.toUtc(),
        deleted: deleted,
        revision: revision as int?,
      );
    } on ArgumentError {
      throw const FormatException('Invalid home-bar record.');
    } on FormatException {
      throw const FormatException('Invalid home-bar record.');
    }
  }

  final String ingredientId;
  final String displayName;
  final HomeBarLocation location;
  final DateTime updatedAt;
  final bool deleted;
  final int? revision;
  final HomeBarItem _item;

  HomeBarItem toItem() => _item;

  /// Request body for `PUT /api/bar-items/:ingredientId`; revision is
  /// server-assigned and intentionally omitted.
  Map<String, Object?> toJson() => {
    'ingredientId': ingredientId,
    'displayName': displayName,
    'location': location.name,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'deleted': deleted,
  };
}

/// One ascending-revision page from `GET /api/sync/bar-items`.
final class HomeBarSyncPage {
  const HomeBarSyncPage({
    required this.items,
    required this.revision,
    required this.hasMore,
  });

  factory HomeBarSyncPage.fromJson(Map<String, Object?> json) {
    final items = json['items'];
    final revision = json['revision'];
    final hasMore = json['hasMore'];
    if (items is! List ||
        revision is! int ||
        revision < 0 ||
        hasMore is! bool) {
      throw const FormatException('Invalid home-bar sync page.');
    }
    return HomeBarSyncPage(
      items: List.unmodifiable([
        for (final item in items)
          if (item is Map<String, Object?>)
            HomeBarRecord.fromJson(item)
          else
            throw const FormatException('Invalid home-bar sync item.'),
      ]),
      revision: revision,
      hasMore: hasMore,
    );
  }

  final List<HomeBarRecord> items;
  final int revision;
  final bool hasMore;
}

abstract interface class HomeBarSyncApi {
  Future<HomeBarSyncPage> pull({required int since, int limit = 200});
  Future<HomeBarRecord> putItem(HomeBarRecord record);
}

/// The lifecycle seam shared with the account-sync coordinator. It uses the
/// established collection [SyncStatus] so profile state can combine both
/// streams without a translation layer.
abstract interface class HomeBarSync {
  SyncStatus get status;
  Stream<SyncStatus> watchStatus();
  Future<void> syncNow();
  void scheduleAfterLocalWrite();
  Future<void> pushBeforeSignOut();
}
