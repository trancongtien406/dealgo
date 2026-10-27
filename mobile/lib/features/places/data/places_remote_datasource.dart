import 'package:dio/dio.dart';

import '../../../core/network/api_envelope.dart';
import '../../../core/network/api_paths.dart';
import '../../../core/network/dio_mapper.dart';
import '../domain/place.dart';

const _recentLimit = 5;

class DioPlacesRemoteDataSource implements PlacesRepository {
  DioPlacesRemoteDataSource({required this.dio});

  final Dio dio;

  Options _auth(String token) =>
      Options(headers: {'Authorization': 'Bearer $token'});

  @override
  Future<PlaceSearchResult> search({
    required String accessToken,
    required String query,
    double? nearLat,
    double? nearLng,
  }) async {
    try {
      final response = await dio.get<Object?>(
        ApiPaths.placesSearch,
        queryParameters: {
          'q': query.trim(),
          if (nearLat != null && nearLng != null) ...{
            'lat': nearLat,
            'lng': nearLng,
          },
        },
        options: _auth(accessToken),
      );
      return decodePlaceSearch(requireSuccessData(response.data));
    } on DioException catch (error) {
      throw apiExceptionFromDio(error);
    }
  }

  @override
  Future<PlaceOption?> reverse({
    required String accessToken,
    required double lat,
    required double lng,
  }) async {
    try {
      final response = await dio.get<Object?>(
        ApiPaths.placesReverse,
        queryParameters: {'lat': lat, 'lng': lng},
        options: _auth(accessToken),
      );
      return _decodeSuggestion(
        requireSuccessData(response.data)['place'],
        PlaceSource.current,
      );
    } on DioException catch (error) {
      throw apiExceptionFromDio(error);
    }
  }

  @override
  Future<List<PlaceOption>> recentDestinations({
    required String accessToken,
  }) async {
    try {
      final response = await dio.get<Object?>(
        ApiPaths.meRides,
        options: _auth(accessToken),
      );
      return decodeRecentDestinations(readSuccessPayload(response.data));
    } on DioException catch (error) {
      throw apiExceptionFromDio(error);
    }
  }

  @override
  Future<List<PlaceOption>> history({required String accessToken}) async {
    try {
      final response = await dio.get<Object?>(
        ApiPaths.mePlaceHistory,
        options: _auth(accessToken),
      );
      return decodePlaceHistory(readSuccessPayload(response.data));
    } on DioException catch (error) {
      throw apiExceptionFromDio(error);
    }
  }

  @override
  Future<PlaceOption?> recordHistory({
    required String accessToken,
    required PlaceOption place,
  }) async {
    try {
      final response = await dio.post<Object?>(
        ApiPaths.mePlaceHistory,
        data: {
          'name': _cap(place.name, 160),
          if (place.address.isNotEmpty) 'address': _cap(place.address, 300),
          'lat': place.lat,
          'lng': place.lng,
        },
        options: _auth(accessToken),
      );
      return _decodeHistoryRow(readSuccessPayload(response.data));
    } on DioException catch (error) {
      throw apiExceptionFromDio(error);
    }
  }

  @override
  Future<void> deleteHistory({
    required String accessToken,
    required String id,
  }) async {
    try {
      await dio.delete<Object?>(
        ApiPaths.mePlaceHistoryItem(id),
        options: _auth(accessToken),
      );
    } on DioException catch (error) {
      throw apiExceptionFromDio(error);
    }
  }

  @override
  Future<void> clearHistory({required String accessToken}) async {
    try {
      await dio.delete<Object?>(
        ApiPaths.mePlaceHistory,
        options: _auth(accessToken),
      );
    } on DioException catch (error) {
      throw apiExceptionFromDio(error);
    }
  }
}

String _cap(String value, int max) =>
    value.length > max ? value.substring(0, max) : value;

/// `{ items: [{ id, name, address, lat, lng, ... }] }` → history places.
List<PlaceOption> decodePlaceHistory(Object? payload) {
  final rows = payload is List ? payload : asJsonMap(payload)?['items'];
  return [
    if (rows is List)
      for (final row in rows) ?_decodeHistoryRow(row),
  ];
}

PlaceOption? _decodeHistoryRow(Object? raw) {
  final place = _decodeSuggestion(raw, PlaceSource.history);
  final id = asJsonMap(raw)?['id'];
  return place == null || id is! String ? null : place.copyWith(historyId: id);
}

PlaceSearchResult decodePlaceSearch(Map<String, Object?> data) {
  final rows = data['items'];
  return PlaceSearchResult(
    available: data['available'] != false,
    googleAttribution: data['attribution'] == 'google',
    items: [
      if (rows is List)
        for (final row in rows) ?_decodeSuggestion(row, PlaceSource.search),
    ],
  );
}

PlaceOption? _decodeSuggestion(Object? raw, PlaceSource source) {
  final map = asJsonMap(raw);
  final lat = map?['lat'];
  final lng = map?['lng'];
  final name = map?['name'];
  if (map == null || lat is! num || lng is! num || name is! String) {
    return null;
  }
  final address = map['address'];
  final distance = map['distanceKm'];
  return PlaceOption(
    name: name,
    address: address is String ? address : '',
    lat: lat.toDouble(),
    lng: lng.toDouble(),
    source: source,
    approximate: map['approximate'] == true,
    distanceKm: distance is num ? distance.toDouble() : null,
  );
}

/// Ride history payload (`[...]` or `{ items: [...] }`) → distinct drop-offs.
List<PlaceOption> decodeRecentDestinations(Object? payload) {
  final rows = payload is List ? payload : asJsonMap(payload)?['items'];
  if (rows is! List) {
    return const [];
  }
  final seen = <String>{};
  final out = <PlaceOption>[];
  for (final row in rows) {
    final dropoff = asJsonMap(asJsonMap(row)?['dropoff']);
    final lat = dropoff?['lat'];
    final lng = dropoff?['lng'];
    final label = dropoff?['label'];
    if (lat is! num ||
        lng is! num ||
        label is! String ||
        label.trim().isEmpty) {
      continue;
    }
    final key = label.trim().toLowerCase();
    if (!seen.add(key)) {
      continue;
    }
    final parts = label.split(',');
    out.add(
      PlaceOption(
        name: parts.first.trim(),
        address: parts.length > 1 ? parts.skip(1).join(',').trim() : '',
        lat: lat.toDouble(),
        lng: lng.toDouble(),
        source: PlaceSource.recent,
      ),
    );
    if (out.length == _recentLimit) {
      break;
    }
  }
  return out;
}

/// In-memory places for tests, screenshots and `useMockData`.
class FakePlacesRemoteDataSource implements PlacesRepository {
  FakePlacesRemoteDataSource({
    List<PlaceOption>? catalog,
    List<PlaceOption>? recent,
    List<PlaceOption>? history,
    this.available = true,
    this.googleAttribution = false,
  }) : _catalog = [...?catalog],
       _recent = [...?recent],
       _history = [
         for (final (i, place) in [...?history].indexed)
           place.copyWith(
             source: PlaceSource.history,
             historyId: place.historyId ?? 'h$i',
           ),
       ];

  final List<PlaceOption> _catalog;
  final List<PlaceOption> _recent;
  final List<PlaceOption> _history;
  var _historySeq = 0;

  /// Rows the fake has recorded, newest first (assertions).
  List<PlaceOption> get historyRows => List.unmodifiable(_history);
  final bool available;

  /// Tag results as Google Places (attribution tests).
  final bool googleAttribution;

  /// Throws on the next search (error-state tests).
  Object? failNext;

  /// Real Da Nang landmarks, for screenshots and mock builds only.
  static const sampleCatalog = [
    PlaceOption(
      name: 'Cầu Rồng',
      address: 'Nguyễn Văn Linh, Sơn Trà, Đà Nẵng',
      lat: 16.061,
      lng: 108.2275,
      source: PlaceSource.search,
    ),
    PlaceOption(
      name: 'Chợ Hàn',
      address: '119 Trần Phú, Hải Châu, Đà Nẵng',
      lat: 16.068,
      lng: 108.2235,
      source: PlaceSource.search,
    ),
    PlaceOption(
      name: 'Biển Mỹ Khê',
      address: 'Võ Nguyên Giáp, Sơn Trà, Đà Nẵng',
      lat: 16.0617,
      lng: 108.2476,
      source: PlaceSource.search,
    ),
  ];

  static const sampleRecent = [
    PlaceOption(
      name: 'Sân bay Quốc tế Đà Nẵng',
      address: 'Nguyễn Văn Linh, Hải Châu, Đà Nẵng',
      lat: 16.0439,
      lng: 108.1994,
      source: PlaceSource.recent,
    ),
  ];

  @override
  Future<PlaceSearchResult> search({
    required String accessToken,
    required String query,
    double? nearLat,
    double? nearLng,
  }) async {
    final error = failNext;
    if (error != null) {
      failNext = null;
      throw error;
    }
    if (!available) {
      return const PlaceSearchResult(items: [], available: false);
    }
    final needle = query.trim().toLowerCase();
    return PlaceSearchResult(
      available: true,
      googleAttribution: googleAttribution,
      items: [
        for (final place in _catalog)
          if (place.name.toLowerCase().contains(needle) ||
              place.address.toLowerCase().contains(needle))
            place,
      ],
    );
  }

  @override
  Future<PlaceOption?> reverse({
    required String accessToken,
    required double lat,
    required double lng,
  }) async => null;

  @override
  Future<List<PlaceOption>> recentDestinations({
    required String accessToken,
  }) async => List.unmodifiable(_recent);

  @override
  Future<List<PlaceOption>> history({required String accessToken}) async =>
      List.unmodifiable(_history);

  @override
  Future<PlaceOption?> recordHistory({
    required String accessToken,
    required PlaceOption place,
  }) async {
    final key = placeDedupeKey(place);
    final index = _history.indexWhere((row) => placeDedupeKey(row) == key);
    final id = index >= 0 ? _history[index].historyId! : 'f${_historySeq++}';
    if (index >= 0) {
      _history.removeAt(index);
    }
    final row = PlaceOption(
      name: place.name,
      address: place.address,
      lat: place.lat,
      lng: place.lng,
      source: PlaceSource.history,
      historyId: id,
    );
    _history.insert(0, row);
    if (_history.length > placeHistoryMax) {
      _history.removeRange(placeHistoryMax, _history.length);
    }
    return row;
  }

  @override
  Future<void> deleteHistory({
    required String accessToken,
    required String id,
  }) async => _history.removeWhere((row) => row.historyId == id);

  @override
  Future<void> clearHistory({required String accessToken}) async =>
      _history.clear();
}
