import '../data/home_bar_repository.dart';
import '../domain/home_bar_item.dart';

/// Schedules the account-sync coordinator after each home-bar mutation.
final class SyncTriggeringHomeBarRepository implements HomeBarRepository {
  SyncTriggeringHomeBarRepository(
    this._inner, {
    required void Function() onWrite,
  }) : _onWrite = onWrite;

  final HomeBarRepository _inner;
  final void Function() _onWrite;

  @override
  Stream<List<HomeBarItem>> watchItems() => _inner.watchItems();

  @override
  Future<HomeBarItem> addToBar(String displayName) =>
      _inner.addToBar(displayName).then(_touched);

  @override
  Future<HomeBarItem> addToShopping(String displayName) =>
      _inner.addToShopping(displayName).then(_touched);

  @override
  Future<void> remove(String ingredientId) =>
      _inner.remove(ingredientId).then(_touchedVoid);

  T _touched<T>(T value) {
    _onWrite();
    return value;
  }

  void _touchedVoid(void _) => _onWrite();
}
