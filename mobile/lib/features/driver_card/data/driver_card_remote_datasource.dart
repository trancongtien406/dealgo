import 'package:dio/dio.dart';

import '../../../core/network/api_envelope.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/api_paths.dart';
import '../../../core/network/dio_mapper.dart';
import '../domain/driver_card.dart';

class DioDriverCardRemoteDataSource implements DriverCardRepository {
  DioDriverCardRemoteDataSource({required this.dio});

  final Dio dio;

  @override
  Future<DriverCard> fetch({
    required String accessToken,
    required DriverCardJob job,
    required String jobId,
    String? offerId,
  }) async {
    final path = switch (job) {
      DriverCardJob.ride => ApiPaths.rideDriver(jobId),
      DriverCardJob.rideOffer => ApiPaths.rideOfferDriver(jobId, offerId ?? ''),
      DriverCardJob.foodOrder => ApiPaths.foodOrderCourier(jobId),
    };
    try {
      final response = await dio.get<Object?>(
        path,
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );
      return decodeDriverCard(requireSuccessData(response.data));
    } on DioException catch (error) {
      throw apiExceptionFromDio(error);
    }
  }

  @override
  Future<String> fetchCustomerName({
    required String accessToken,
    required String jobId,
    bool isFood = false,
  }) async {
    try {
      final response = await dio.get<Object?>(
        isFood
            ? ApiPaths.foodOrderCustomer(jobId)
            : ApiPaths.rideCustomer(jobId),
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );
      final name = requireSuccessData(response.data)['displayName'];
      return name is String ? name.trim() : '';
    } on DioException catch (error) {
      throw apiExceptionFromDio(error);
    }
  }
}

DriverCard decodeDriverCard(Map<String, Object?> data) {
  final id = data['driverId'];
  final name = data['displayName'];
  if (id is! String || name is! String) {
    throw const ApiException(
      statusCode: 502,
      message: 'Malformed driver card',
      errorCode: 'MALFORMED_RESPONSE',
    );
  }
  String? text(Object? value) =>
      value is String && value.trim().isNotEmpty ? value.trim() : null;
  final average = data['ratingAverage'];
  final count = data['ratingCount'];
  return DriverCard(
    driverId: id,
    displayName: name.trim(),
    avatarUrl: text(data['avatarUrl']),
    vehiclePlate: text(data['vehiclePlate']),
    vehicleType: text(data['vehicleType']),
    ratingAverage: average is num ? average.toDouble() : null,
    ratingCount: count is num ? count.toInt() : 0,
  );
}

/// Test/mock source. Without [card] it behaves like a job with no driver yet.
class FakeDriverCardRemoteDataSource implements DriverCardRepository {
  FakeDriverCardRemoteDataSource({this.card, this.customerName = ''});

  DriverCard? card;
  String customerName;
  final calls = <({DriverCardJob job, String jobId})>[];

  /// Per-driver cards for offer lists, keyed by offer id.
  final offerCards = <String, DriverCard>{};

  @override
  Future<DriverCard> fetch({
    required String accessToken,
    required DriverCardJob job,
    required String jobId,
    String? offerId,
  }) async {
    calls.add((job: job, jobId: jobId));
    final value = job == DriverCardJob.rideOffer ? offerCards[offerId] : card;
    if (value == null) {
      throw const ApiException(
        statusCode: 404,
        message: 'No driver assigned yet',
        errorCode: 'DRIVER_NOT_ASSIGNED',
      );
    }
    return value;
  }

  @override
  Future<String> fetchCustomerName({
    required String accessToken,
    required String jobId,
    bool isFood = false,
  }) async => customerName;
}
