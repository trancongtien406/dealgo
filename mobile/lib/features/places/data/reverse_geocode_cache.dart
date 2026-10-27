import 'dart:async';

import '../domain/place.dart';

/// Client-side reverse-geocode memo for pick-on-map: the pin is looked up only
/// once per ~11 m cell (4 decimals), concurrent asks for one cell share one
/// request, misses are remembered too, and the newest [capacity] cells stay.
class ReverseGeocodeCache {
  ReverseGeocodeCache({this.capacity = 64});

  final int capacity;
  // Map literals keep insertion order: first key = least recently used.
  final _entries = <String, PlaceOption?>{};
  final _inFlight = <String, Future<PlaceOption?>>{};

  static String keyFor(double lat, double lng) =>
      '${lat.toStringAsFixed(4)},${lng.toStringAsFixed(4)}';

  bool contains(double lat, double lng) =>
      _entries.containsKey(keyFor(lat, lng));

  /// Seeds a cell from a place the app already knows (search hit, saved).
  void put(PlaceOption place) => _store(keyFor(place.lat, place.lng), place);

  Future<PlaceOption?> resolve({
    required double lat,
    required double lng,
    required Future<PlaceOption?> Function() lookup,
  }) {
    final key = keyFor(lat, lng);
    if (_entries.containsKey(key)) {
      final hit = _entries.remove(key);
      _entries[key] = hit;
      return Future.value(hit);
    }
    final pending = _inFlight[key];
    if (pending != null) {
      return pending;
    }
    final future = () async {
      try {
        final place = await lookup();
        _store(key, place);
        return place;
      } finally {
        _inFlight.remove(key);
      }
    }();
    _inFlight[key] = future;
    return future;
  }

  int get length => _entries.length;

  void clear() {
    _entries.clear();
    _inFlight.clear();
  }

  void _store(String key, PlaceOption? place) {
    _entries.remove(key);
    _entries[key] = place;
    while (_entries.length > capacity) {
      _entries.remove(_entries.keys.first);
    }
  }
}

/// One memo for the app session, shared by every picker.
final reverseGeocodeCache = ReverseGeocodeCache();
