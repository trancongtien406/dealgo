import 'dart:math' as math;

import 'package:dio/dio.dart';

import '../../../core/network/api_envelope.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/api_paths.dart';
import '../../../core/network/dio_mapper.dart';
import '../domain/pricing.dart';

Map<String, Object> _point(PricePoint point) => {
  'lat': point.lat,
  'lng': point.lng,
  'label': point.label,
};

class DioPricingRemoteDataSource implements PricingRepository {
  DioPricingRemoteDataSource({required this.dio});

  final Dio dio;

  Options _auth(String token) =>
      Options(headers: {'Authorization': 'Bearer $token'});

  @override
  Future<RideQuote> quoteRide({
    required String accessToken,
    required PricePoint pickup,
    required PricePoint dropoff,
  }) async {
    try {
      final response = await dio.post<Object?>(
        ApiPaths.ridesQuote,
        data: {'pickup': _point(pickup), 'dropoff': _point(dropoff)},
        options: _auth(accessToken),
      );
      return decodeRideQuote(requireSuccessData(response.data));
    } on DioException catch (error) {
      throw apiExceptionFromDio(error);
    }
  }

  @override
  Future<int> quoteFoodDelivery({
    required String accessToken,
    required String storeId,
    required PricePoint dropoff,
  }) async {
    try {
      final response = await dio.post<Object?>(
        ApiPaths.foodQuote,
        data: {'storeId': storeId, 'dropoff': _point(dropoff)},
        options: _auth(accessToken),
      );
      final fare = requireSuccessData(response.data)['deliveryFareVnd'];
      if (fare is! num) {
        throw const ApiException(
          statusCode: 502,
          message: 'Malformed delivery quote',
          errorCode: 'MALFORMED_RESPONSE',
        );
      }
      return fare.toInt();
    } on DioException catch (error) {
      throw apiExceptionFromDio(error);
    }
  }
}

RideQuote decodeRideQuote(Map<String, Object?> data) {
  final distance = data['distanceKm'];
  final reference = data['referenceFareVnd'];
  final min = data['minFareVnd'];
  final max = data['maxFareVnd'];
  if (distance is! num || reference is! num || min is! num || max is! num) {
    throw const ApiException(
      statusCode: 502,
      message: 'Malformed ride quote',
      errorCode: 'MALFORMED_RESPONSE',
    );
  }
  return RideQuote(
    distanceKm: distance.toDouble(),
    referenceFareVnd: reference.toInt(),
    minFareVnd: min.toInt(),
    maxFareVnd: max.toInt(),
  );
}

/// Offline quotes for tests, screenshots and `useMockData`, mirroring the
/// backend rule with the seeded setting values.
class FakePricingRemoteDataSource implements PricingRepository {
  FakePricingRemoteDataSource({
    this.vndPerKm = 12000,
    this.minFareVnd = 15000,
    this.maxFareVnd = 1000000,
    this.deliveryFareVnd = 15000,
    this.fixedReferenceVnd,
  });

  final int vndPerKm;
  final int minFareVnd;
  final int maxFareVnd;
  final int deliveryFareVnd;

  /// Pins the reference fare regardless of distance (tests).
  final int? fixedReferenceVnd;

  /// Throws on the next call (error-state tests).
  Object? failNext;

  void _maybeFail() {
    final error = failNext;
    if (error != null) {
      failNext = null;
      throw error;
    }
  }

  @override
  Future<RideQuote> quoteRide({
    required String accessToken,
    required PricePoint pickup,
    required PricePoint dropoff,
  }) async {
    _maybeFail();
    final km = _haversineKm(pickup, dropoff);
    final reference =
        fixedReferenceVnd ?? math.max(minFareVnd, (km * vndPerKm).round());
    return RideQuote(
      distanceKm: (km * 10).round() / 10,
      referenceFareVnd: math.min(reference, maxFareVnd),
      minFareVnd: minFareVnd,
      maxFareVnd: maxFareVnd,
    );
  }

  @override
  Future<int> quoteFoodDelivery({
    required String accessToken,
    required String storeId,
    required PricePoint dropoff,
  }) async {
    _maybeFail();
    return deliveryFareVnd;
  }
}

double _haversineKm(PricePoint a, PricePoint b) {
  const earthKm = 6371.0;
  double rad(double deg) => deg * math.pi / 180;
  final dLat = rad(b.lat - a.lat);
  final dLng = rad(b.lng - a.lng);
  final h =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(a.lat)) *
          math.cos(rad(b.lat)) *
          math.pow(math.sin(dLng / 2), 2);
  return 2 * earthKm * math.asin(math.sqrt(h));
}
