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
  Future<CustomerCard> fetchCustomer({
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
      return decodeCustomerCard(requireSuccessData(response.data));
    } on DioException catch (error) {
      throw apiExceptionFromDio(error);
    }
  }
}

String? _cardText(Object? value) =>
    value is String && value.trim().isNotEmpty ? value.trim() : null;

CustomerCard decodeCustomerCard(Map<String, Object?> data) => CustomerCard(
  displayName: _cardText(data['displayName']) ?? '',
  avatarUrl: _cardText(data['avatarUrl']),
  phone: _cardText(data['phone']),
);

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
  const text = _cardText;
  final average = data['ratingAverage'];
  final count = data['ratingCount'];
  final trips = data['completedTrips'];
  return DriverCard(
    driverId: id,
    displayName: name.trim(),
    avatarUrl: text(data['avatarUrl']),
    vehiclePlate: text(data['vehiclePlate']),
    vehicleType: text(data['vehicleType']),
    vehicleName: text(data['vehicleName']),
    ratingAverage: average is num ? average.toDouble() : null,
    ratingCount: count is num ? count.toInt() : 0,
    completedTrips: trips is num ? trips.toInt() : null,
    phone: text(data['phone']),
  );
}

/// Test/mock source. Without [card] it behaves like a job with no driver yet.
class FakeDriverCardRemoteDataSource implements DriverCardRepository {
  FakeDriverCardRemoteDataSource({
    this.card,
    this.customerName = '',
    this.customerAvatarUrl,
    this.customerPhone,
  });

  DriverCard? card;
  String customerName;
  String? customerAvatarUrl;
  String? customerPhone;
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
  Future<CustomerCard> fetchCustomer({
    required String accessToken,
    required String jobId,
    bool isFood = false,
  }) async => CustomerCard(
    displayName: customerName,
    avatarUrl: customerAvatarUrl,
    phone: customerPhone,
  );
}
