import 'package:dio/dio.dart';

import '../../../../core/network/api_paths.dart';
import '../../../../core/network/dio_mapper.dart';
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
  }) async {
    try {
      await _dio.post<Object?>(
        ApiPaths.mePresence,
        data: {
          'online': online,
          'lat': ?lat,
          'lng': ?lng,
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
}

typedef DioPresenceClient = DioPresenceRemoteDataSource;
