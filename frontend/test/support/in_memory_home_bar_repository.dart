import 'dart:async';

import 'package:zest/features/discovery/domain/ingredient.dart';
import 'package:zest/features/home_bar/data/home_bar_repository.dart';
import 'package:zest/features/home_bar/domain/home_bar_item.dart';

/// Controllable, durable-looking home-bar storage for provider and widget tests.
final class InMemoryHomeBarRepository implements HomeBarRepository {
  InMemoryHomeBarRepository([List<HomeBarItem> seed = const []])
    : _items = List.of(seed);

  final _updates = StreamController<List<HomeBarItem>>.broadcast();
  List<HomeBarItem> _items;
  var _tick = DateTime.utc(2026, 9, 14);

  List<HomeBarItem> get items => List.unmodifiable(_items);

  @override
  Stream<List<HomeBarItem>> watchItems() async* {
    yield List.unmodifiable(_items);
    yield* _updates.stream;
  }

  @override
  Future<HomeBarItem> addToBar(String displayName) =>
      _write(displayName, HomeBarLocation.stocked);

  @override
  Future<HomeBarItem> addToShopping(String displayName) =>
      _write(displayName, HomeBarLocation.shopping);

  @override
  Future<void> remove(String ingredientId) async {
    _items = _items.where((item) => item.ingredientId != ingredientId).toList();
    _updates.add(List.unmodifiable(_items));
  }

  Future<HomeBarItem> _write(
    String displayName,
    HomeBarLocation location,
  ) async {
    final id = normalizeIngredientName(displayName);
    _tick = _tick.add(const Duration(milliseconds: 1));
    final item = HomeBarItem(
      ingredientId: id,
      displayName: displayName,
      location: location,
      updatedAt: _tick,
    );
    _items = [
      for (final existing in _items)
        if (existing.ingredientId != id) existing,
      item,
    ];
    _updates.add(List.unmodifiable(_items));
    return item;
  }

  Future<void> dispose() => _updates.close();
}
