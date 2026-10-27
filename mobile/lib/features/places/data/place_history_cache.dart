import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/place.dart';

/// Device copy of the server place history, so the list shows instantly
/// (and offline). The server stays the source of truth: every load replaces
/// this copy. Cleared on sign-out.
class PlaceHistoryCache {
  PlaceHistoryCache._();

  static const _key = 'dealgo.placeHistory.v1';

  /// Fallback when the platform store is unavailable (tests).
  static List<PlaceOption> _memory = const [];

  static Future<SharedPreferences?> _prefs() async {
    try {
      return await SharedPreferences.getInstance();
    } catch (_) {
      return null;
    }
  }

  static Future<List<PlaceOption>> load() async {
    final prefs = await _prefs();
    final raw = prefs?.getString(_key);
    if (raw == null) {
      return _memory;
    }
    try {
      final rows = jsonDecode(raw);
      if (rows is! List) {
        return const [];
      }
      return [
        for (final row in rows)
          if (row is Map &&
              row['id'] is String &&
              row['name'] is String &&
              row['lat'] is num &&
              row['lng'] is num)
            PlaceOption(
              name: row['name'] as String,
              address: row['address'] is String ? row['address'] as String : '',
              lat: (row['lat'] as num).toDouble(),
              lng: (row['lng'] as num).toDouble(),
              source: PlaceSource.history,
              historyId: row['id'] as String,
            ),
      ];
    } catch (_) {
      return const [];
    }
  }

  static Future<void> save(List<PlaceOption> rows) async {
    final kept = [
      for (final row in rows)
        if (row.historyId != null) row,
    ].take(placeHistoryMax).toList(growable: false);
    _memory = List.unmodifiable(kept);
    final prefs = await _prefs();
    await prefs?.setString(
      _key,
      jsonEncode([
        for (final row in kept)
          {
            'id': row.historyId,
            'name': row.name,
            'address': row.address,
            'lat': row.lat,
            'lng': row.lng,
          },
      ]),
    );
  }

  static Future<void> clear() async {
    _memory = const [];
    final prefs = await _prefs();
    await prefs?.remove(_key);
  }
}
