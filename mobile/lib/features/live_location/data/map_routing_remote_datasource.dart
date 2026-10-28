import 'package:dio/dio.dart';

import '../../../core/maps/map_lat_lng.dart';
import '../../../core/maps/route_geometry.dart';
import '../../../core/network/api_envelope.dart';
import '../../../core/network/api_paths.dart';
import '../../../core/network/dio_mapper.dart';
import '../domain/map_routing.dart';

class DioMapRoutingRemoteDataSource implements MapRoutingRepository {
  DioMapRoutingRemoteDataSource({required this.dio});

  final Dio dio;

  @override
  Future<RouteGeometry> route({
    required String accessToken,
    required MapLatLng from,
    required MapLatLng to,
    List<MapLatLng> via = const [],
  }) async {
    try {
      final response = await dio.get<Object?>(
        ApiPaths.ridesRoute,
        queryParameters: {
          'fromLat': from.lat,
          'fromLng': from.lng,
          'toLat': to.lat,
          'toLng': to.lng,
          if (via.isNotEmpty)
            'via': [for (final p in via.take(5)) '${p.lat},${p.lng}'].join('|'),
        },
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );
      final data = requireSuccessData(response.data);
      return RouteGeometry.tryParse(data) ?? RouteGeometry.unavailable;
    } on DioException catch (error) {
      throw apiExceptionFromDio(error);
    }
  }
}

/// In-memory stand-in for tests / USE_MOCK_DATA.
class FakeMapRoutingRemoteDataSource implements MapRoutingRepository {
  FakeMapRoutingRemoteDataSource({this.next = RouteGeometry.unavailable});

  RouteGeometry next;
  final List<({MapLatLng from, MapLatLng to})> calls = [];

  @override
  Future<RouteGeometry> route({
    required String accessToken,
    required MapLatLng from,
    required MapLatLng to,
    List<MapLatLng> via = const [],
  }) async {
    calls.add((from: from, to: to));
    return next;
  }
}
