import 'package:dio/dio.dart';

import '../../../../core/network/api_paths.dart';
import '../../../../core/network/dio_mapper.dart';
import '../../domain/entities/driver_service_prefs.dart';
import 'presence_remote_datasource.dart';

class DioPresenceRemoteDataSource implements PresenceRemoteDataSource {
  DioPresenceRemoteDataSource({required this._dio});

  final Dio _dio;

  @override
  Future<void> setPresence({
    required String accessToken,
    required bool online,
    double? lat,
    double? lng,
    bool? rideEnabled,
    bool? foodEnabled,
  }) async {
    try {
      await _dio.post<Object?>(
        ApiPaths.mePresence,
        data: {
          'online': online,
          'lat': ?lat,
          'lng': ?lng,
          'rideEnabled': ?rideEnabled,
          'foodEnabled': ?foodEnabled,
        },
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      if (status == 404 || status == 501) {
        return;
      }
      throw apiExceptionFromDio(error);
    }
  }

  @override
  Future<DriverServicePrefs> getServicePrefs({required String accessToken}) async {
    try {
      final response = await _dio.get<Object?>(
        ApiPaths.mePresence,
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );
      final body = response.data;
      return decodeDriverServicePrefs(body is Map ? body['data'] : null);
    } on DioException catch (error) {
      throw apiExceptionFromDio(error);
    }
  }
}

typedef DioPresenceClient = DioPresenceRemoteDataSource;
