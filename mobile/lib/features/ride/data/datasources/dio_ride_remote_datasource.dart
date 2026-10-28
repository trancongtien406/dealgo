import 'package:dio/dio.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/network/api_paths.dart';
import '../../../../core/network/dio_mapper.dart';
import '../../domain/params/create_ride_params.dart';
import '../../domain/params/ride_driver_action.dart';
import '../../domain/params/select_ride_offer_params.dart';
import '../../domain/params/submit_ride_offer_params.dart';
import '../models/ride_models.dart';
import 'ride_remote_datasource.dart';

class DioRideRemoteDataSource implements RideRemoteDataSource {
  DioRideRemoteDataSource({required this.dio});

  final Dio dio;

  @override
  Future<List<OpenRideModel>> listOpenRides(String accessToken) async {
    try {
      final response = await dio.get<Object?>(
        ApiPaths.ridesOpen,
        options: _bearer(accessToken),
      );
      return OpenRideModel.listFromResponseBody(response.data);
    } on DioException catch (error) {
      throw apiExceptionFromDio(error);
    }
  }

  @override
  Future<RideViewModel> submitOffer(SubmitRideOfferParams request) {
    return _send(
      () => dio.post<Object?>(
        ApiPaths.rideOffers(request.rideId),
        data: SubmitRideOfferBody(
          amountVnd: request.amountVnd,
          routeVersion: request.routeVersion,
        ).toJson(),
        options: _bearer(request.accessToken),
      ),
    );
  }

  @override
  Future<RideViewModel> createRide(CreateRideParams request) {
    return _send(
      () => dio.post<Object?>(
        ApiPaths.rides,
        data: CreateRideBody(
          pickup: RidePointModel.fromEntity(request.pickup),
          dropoff: RidePointModel.fromEntity(request.dropoff),
          offeredFareVnd: request.offeredFareVnd,
          vehicleClassCode: request.vehicleClassCode,
          stops: [for (final s in request.stops) RidePointModel.fromEntity(s)],
        ).toJson(),
        options: _auth(request.accessToken, request.idempotencyKey),
      ),
    );
  }

  @override
  Future<RideViewModel> getRide({
    required String accessToken,
    required String rideId,
  }) {
    return _send(
      () => dio.get<Object?>(
        ApiPaths.ride(rideId),
        options: _bearer(accessToken),
      ),
    );
  }

  @override
  Future<RideViewModel> selectOffer(SelectRideOfferParams request) {
    return _send(
      () => dio.post<Object?>(
        ApiPaths.rideSelection(request.rideId),
        data: SelectRideOfferBody(
          offerId: request.offerId,
          voucherCode: request.voucherCode,
        ).toJson(),
        options: _auth(request.accessToken, request.idempotencyKey),
      ),
    );
  }

  @override
  Future<RideViewModel> cancelRide({
    required String accessToken,
    required String rideId,
  }) {
    return _send(
      () => dio.post<Object?>(
        ApiPaths.rideCancel(rideId),
        options: _bearer(accessToken),
      ),
    );
  }

  @override
  Future<RideViewModel> advanceRide({
    required String accessToken,
    required String rideId,
    required RideDriverAction action,
    String? pickupCode,
  }) {
    return _send(
      () => dio.post<Object?>(
        ApiPaths.rideDriverAction(rideId, action.pathSegment),
        data: pickupCode == null ? null : {'pickupCode': pickupCode},
        options: _bearer(accessToken),
      ),
    );
  }

  Future<RideViewModel> _send(Future<Response<Object?>> Function() send) async {
    try {
      final response = await send();
      return RideViewModel.fromResponseBody(response.data);
    } on DioException catch (error) {
      throw apiExceptionFromDio(error);
    }
  }
}

Options _bearer(String accessToken) {
  return Options(headers: {'Authorization': 'Bearer $accessToken'});
}

Options _auth(String accessToken, String idempotencyKey) {
  final key = idempotencyKey.trim();
  if (key.length < 8 || key.length > 200) {
    throw const ApiException(
      statusCode: 400,
      message: 'Idempotency-Key must be 8 to 200 characters',
      errorCode: 'VALIDATION_ERROR',
    );
  }
  return Options(
    headers: {'Authorization': 'Bearer $accessToken', 'Idempotency-Key': key},
  );
}

/// Backward-compatible alias for tests and DI overrides.
typedef DioRideClient = DioRideRemoteDataSource;
