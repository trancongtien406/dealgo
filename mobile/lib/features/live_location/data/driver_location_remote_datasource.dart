import 'package:dio/dio.dart';

import '../../../core/network/api_envelope.dart';
import '../../../core/network/api_paths.dart';
import '../../../core/network/dio_mapper.dart';
import '../domain/driver_location.dart';

class DioDriverLocationRemoteDataSource implements DriverLocationRepository {
  DioDriverLocationRemoteDataSource({required this.dio});

  final Dio dio;

  Options _auth(String token) =>
      Options(headers: {'Authorization': 'Bearer $token'});

  @override
  Future<void> report({
    required String accessToken,
    required double lat,
    required double lng,
  }) async {
    try {
      await dio.post<Object?>(
        ApiPaths.mePresenceLocation,
        data: {'lat': lat, 'lng': lng},
        options: _auth(accessToken),
      );
    } on DioException catch (error) {
      throw apiExceptionFromDio(error);
    }
  }

  @override
  Future<DriverLiveLocation?> latest({
    required String accessToken,
    required TrackedJob job,
    required String id,
  }) async {
    try {
      final response = await dio.get<Object?>(switch (job) {
        TrackedJob.ride => ApiPaths.rideDriverLocation(id),
        TrackedJob.food => ApiPaths.foodDriverLocation(id),
      }, options: _auth(accessToken));
      return decodeDriverLocation(requireSuccessData(response.data));
    } on DioException catch (error) {
      throw apiExceptionFromDio(error);
    }
  }
}

/// In-memory stand-in for tests and `USE_MOCK_DATA` builds.
class FakeDriverLocationRemoteDataSource implements DriverLocationRepository {
  FakeDriverLocationRemoteDataSource({this.location});

  /// What [latest] returns for every job.
  DriverLiveLocation? location;
  final List<({double lat, double lng})> reports = [];
  final List<({TrackedJob job, String id})> reads = [];

  @override
  Future<void> report({
    required String accessToken,
    required double lat,
    required double lng,
  }) async {
    reports.add((lat: lat, lng: lng));
  }

  @override
  Future<DriverLiveLocation?> latest({
    required String accessToken,
    required TrackedJob job,
    required String id,
  }) async {
    reads.add((job: job, id: id));
    return location;
  }
}
