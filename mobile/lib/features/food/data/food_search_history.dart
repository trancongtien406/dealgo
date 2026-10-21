import 'package:shared_preferences/shared_preferences.dart';

/// The customer's own recent food searches, kept on this device only.
class FoodSearchHistory {
  FoodSearchHistory._();

  static const _key = 'dealgo.foodSearchHistory';
  static const maxEntries = 5;

  /// Used when the platform store is unavailable (tests, first frame).
  static List<String> _memory = const [];

  static Future<SharedPreferences?> _prefs() async {
    try {
      return await SharedPreferences.getInstance();
    } catch (_) {
      return null;
    }
  }

  static Future<List<String>> load() async {
    final prefs = await _prefs();
    return prefs?.getStringList(_key) ?? _memory;
  }

  /// Moves [query] to the front (case-insensitive de-dup) and caps the list.
  static Future<List<String>> add(String query) async {
    final value = query.trim();
    if (value.length < 2) {
      return load();
    }
    final current = await load();
    final next = [
      value,
      for (final item in current)
        if (item.toLowerCase() != value.toLowerCase()) item,
    ].take(maxEntries).toList();
    await _save(next);
    return next;
  }

  static Future<void> clear() => _save(const []);

  static Future<void> _save(List<String> values) async {
    _memory = List.unmodifiable(values);
    final prefs = await _prefs();
    await prefs?.setStringList(_key, values);
  }
}
