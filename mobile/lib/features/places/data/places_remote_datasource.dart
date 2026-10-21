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
  }) async {
    try {
      final response = await dio.get<Object?>(
        ApiPaths.placesSearch,
        queryParameters: {'q': query.trim()},
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
}

PlaceSearchResult decodePlaceSearch(Map<String, Object?> data) {
  final rows = data['items'];
  return PlaceSearchResult(
    available: data['available'] != false,
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
  return PlaceOption(
    name: name,
    address: address is String ? address : '',
    lat: lat.toDouble(),
    lng: lng.toDouble(),
    source: source,
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
    this.available = true,
  }) : _catalog = [...?catalog],
       _recent = [...?recent];

  final List<PlaceOption> _catalog;
  final List<PlaceOption> _recent;
  final bool available;

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
}
