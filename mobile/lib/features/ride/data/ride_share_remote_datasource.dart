import 'package:dio/dio.dart';

import '../../../core/network/api_envelope.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/api_paths.dart';
import '../../../core/network/dio_mapper.dart';
import '../domain/ride_share.dart';

class DioRideShareRemoteDataSource implements RideShareRepository {
  DioRideShareRemoteDataSource({required this.dio});

  final Dio dio;

  @override
  Future<RideShareLink> create({
    required String accessToken,
    required String rideId,
  }) async {
    try {
      final response = await dio.post<Object?>(
        ApiPaths.rideShareLink(rideId),
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );
      final data = requireSuccessData(response.data);
      final url = data['url'];
      final expires = DateTime.tryParse('${data['expiresAt']}');
      if (url is! String || url.isEmpty || expires == null) {
        throw const ApiException(
          statusCode: 200,
          message: 'Invalid response',
          errorCode: 'INVALID_RESPONSE',
        );
      }
      return RideShareLink(url: url, expiresAt: expires.toLocal());
    } on DioException catch (error) {
      throw apiExceptionFromDio(error);
    }
  }
}

class FakeRideShareRepository implements RideShareRepository {
  FakeRideShareRepository({this.error});

  Object? error;
  final calls = <String>[];

  @override
  Future<RideShareLink> create({
    required String accessToken,
    required String rideId,
  }) async {
    calls.add(rideId);
    final failure = error;
    if (failure != null) {
      throw failure;
    }
    return RideShareLink(
      url: 'http://localhost:3000/chia-se-chuyen/demo-${calls.length}',
      expiresAt: DateTime.now().add(const Duration(hours: 12)),
    );
  }
}
