import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/entities/food_category.dart';

enum FoodCategoriesStatus { loading, ready, failed }

/// Last known category list, kept on device so chips, tiles and labels draw
/// on the next launch before the network answers.
abstract class FoodCategoriesCache {
  Future<List<FoodCategory>?> read();
  Future<void> write(List<FoodCategory> categories);
}

class PrefsFoodCategoriesCache implements FoodCategoriesCache {
  const PrefsFoodCategoriesCache();

  static const _key = 'dealgo.foodCategories';

  @override
  Future<List<FoodCategory>?> read() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(_key);
      if (raw == null) return null;
      final list = jsonDecode(raw);
      if (list is! List) return null;
      return [for (final item in list) ?FoodCategory.fromJson(item)];
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(List<FoodCategory> categories) async {
    try {
      await (await SharedPreferences.getInstance()).setString(
        _key,
        jsonEncode([for (final c in categories) c.toJson()]),
      );
    } catch (_) {
      // Next launch waits for the network instead; nothing else depends on it.
    }
  }
}

class MemoryFoodCategoriesCache implements FoodCategoriesCache {
  MemoryFoodCategoriesCache([this.value]);

  List<FoodCategory>? value;

  @override
  Future<List<FoodCategory>?> read() async => value;

  @override
  Future<void> write(List<FoodCategory> categories) async => value = categories;
}

/// Single source for store categories (Admin › Danh mục): cache first, then
/// the server (stale-while-revalidate), like the sign-in methods store.
/// Screens draw skeleton tiles while [status] is loading and hide the strip
/// when it failed with nothing cached.
class FoodCategoriesStore extends ChangeNotifier {
  FoodCategoriesStore(
    this._fetch, {
    FoodCategoriesCache? cache,
    this.timeout = const Duration(seconds: 10),
  }) : _cache = cache ?? const PrefsFoodCategoriesCache();

  final Future<List<FoodCategory>> Function() _fetch;
  final FoodCategoriesCache _cache;
  final Duration timeout;

  FoodCategoriesStatus _status = FoodCategoriesStatus.loading;
  List<FoodCategory> _items = const [];
  Future<void>? _inFlight;
  bool _disposed = false;

  FoodCategoriesStatus get status => _status;
  List<FoodCategory> get items => _items;

  FoodCategory? byCode(String? code) {
    final value = code?.trim().toLowerCase();
    if (value == null || value.isEmpty) return null;
    for (final item in _items) {
      if (item.code == value) return item;
    }
    return null;
  }

  /// Concurrent calls share one request.
  Future<void> load() => _inFlight ??= _load().whenComplete(() {
    _inFlight = null;
  });

  Future<void> _load() async {
    if (_status != FoodCategoriesStatus.ready) {
      final cached = await _cache.read();
      if (cached != null && _status != FoodCategoriesStatus.ready) {
        _set(cached);
      }
    }
    try {
      final fresh = await _fetch().timeout(timeout);
      _set(fresh);
      unawaited(_cache.write(fresh));
    } catch (_) {
      if (_status != FoodCategoriesStatus.ready) {
        _status = FoodCategoriesStatus.failed;
        _notify();
      }
    }
  }

  void _set(List<FoodCategory> items) {
    final same =
        _status == FoodCategoriesStatus.ready &&
        items.length == _items.length &&
        [for (var i = 0; i < items.length; i++) items[i] == _items[i]]
            .every((e) => e);
    _status = FoodCategoriesStatus.ready;
    _items = List.unmodifiable(items);
    if (!same) _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// The app's store, or null in isolated widget tests mounted without it.
FoodCategoriesStore? maybeFoodCategories(
  BuildContext context, {
  bool listen = true,
}) {
  try {
    return Provider.of<FoodCategoriesStore>(context, listen: listen);
  } on ProviderNotFoundException {
    return null;
  }
}

/// Localized name for a store's category code: the managed name when known,
/// otherwise the code made readable; null codes show nothing.
String? foodCategoryLabel(BuildContext context, String? code) {
  final value = code?.trim();
  if (value == null || value.isEmpty) return null;
  final match = maybeFoodCategories(context)?.byCode(value);
  if (match != null) {
    return match.name(Localizations.localeOf(context).languageCode);
  }
  final plain = value.replaceAll('_', ' ');
  return plain[0].toUpperCase() + plain.substring(1);
}
