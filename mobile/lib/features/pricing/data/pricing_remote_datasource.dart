import 'dart:math' as math;

import 'package:dio/dio.dart';

import '../../../core/network/api_envelope.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/api_paths.dart';
import '../../../core/network/dio_mapper.dart';
import '../domain/pricing.dart';
import '../../../core/maps/route_geometry.dart';

Map<String, Object> _point(PricePoint point) => {
  'lat': point.lat,
  'lng': point.lng,
  'label': point.label,
};

class DioPricingRemoteDataSource implements PricingRepository {
  DioPricingRemoteDataSource({required this.dio});

  final Dio dio;
  List<RideVehicleClassOption>? _cachedVehicleClasses;
  Future<List<RideVehicleClassOption>>? _inFlightVehicleClasses;

  Options _auth(String token) =>
      Options(headers: {'Authorization': 'Bearer $token'});

  @override
  Future<RideQuote> quoteRide({
    required String accessToken,
    required PricePoint pickup,
    required PricePoint dropoff,
    List<PricePoint> stops = const [],
  }) async {
    try {
      final response = await dio.post<Object?>(
        ApiPaths.ridesQuote,
        data: {
          'pickup': _point(pickup),
          'dropoff': _point(dropoff),
          if (stops.isNotEmpty) 'stops': [for (final s in stops) _point(s)],
        },
        options: _auth(accessToken),
      );
      return decodeRideQuote(requireSuccessData(response.data));
    } on DioException catch (error) {
      throw apiExceptionFromDio(error);
    }
  }

  @override
  Future<List<RideVehicleClassOption>> listVehicleClasses({
    required String accessToken,
  }) {
    final cached = _cachedVehicleClasses;
    if (cached != null) {
      return Future<List<RideVehicleClassOption>>.value(cached);
    }
    final existing = _inFlightVehicleClasses;
    if (existing != null) {
      return existing;
    }
    final future = _fetchVehicleClasses(accessToken);
    _inFlightVehicleClasses = future;
    future.whenComplete(() => _inFlightVehicleClasses = null);
    return future;
  }

  Future<List<RideVehicleClassOption>> _fetchVehicleClasses(
    String accessToken,
  ) async {
    try {
      final response = await dio.get<Object?>(
        ApiPaths.rideVehicleClasses,
        options: _auth(accessToken),
      );
      final classes = decodeVehicleClasses(requireSuccessData(response.data));
      _cachedVehicleClasses = classes;
      return classes;
    } on DioException catch (error) {
      throw apiExceptionFromDio(error);
    }
  }

  @override
  Future<FoodDeliveryQuote> quoteFoodDelivery({
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
      return decodeFoodDeliveryQuote(requireSuccessData(response.data));
    } on DioException catch (error) {
      throw apiExceptionFromDio(error);
    }
  }
}

FoodDeliveryQuote decodeFoodDeliveryQuote(Map<String, Object?> data) {
  final fare = data['suggestedDeliveryFareVnd'] ?? data['deliveryFareVnd'];
  if (fare is! num) {
    throw const ApiException(
      statusCode: 502,
      message: 'Malformed delivery quote',
      errorCode: 'MALFORMED_RESPONSE',
    );
  }
  final min = data['minOfferVnd'];
  final max = data['maxOfferVnd'];
  final step = data['fareStepVnd'];
  if (min is! num || max is! num) {
    return FoodDeliveryQuote.fixed(fare.toInt());
  }
  return FoodDeliveryQuote(
    suggestedVnd: fare.toInt(),
    minOfferVnd: min.toInt(),
    maxOfferVnd: max.toInt(),
    fareStepVnd: step is num && step > 0 ? step.toInt() : 1000,
    feeMode: parseFoodDeliveryFeeMode(data['feeMode']),
  );
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
  final km = distance.toDouble();
  final route =
      RouteGeometry.tryParse(data['route']) ?? RouteGeometry.unavailable;
  return RideQuote(
    distanceKm: km,
    referenceFareVnd: reference.toInt(),
    minFareVnd: min.toInt(),
    maxFareVnd: max.toInt(),
    minBidVnd: _int(data['minBidVnd']),
    maxBidVnd: _int(data['maxBidVnd']),
    vehicleClassCode: _text(data['vehicleClassCode']),
    vehicleClassName: _text(data['vehicleClassName']) ?? _text(data['name']),
    seats: _int(data['seats']),
    baseFareVnd: _int(data['baseFareVnd']) ?? 0,
    perKmVnd: _int(data['perKmVnd']) ?? 0,
    perMinuteVnd: _int(data['perMinuteVnd']) ?? 0,
    durationMin: _int(data['durationMin']) ?? 0,
    imageUrl: _text(data['imageUrl']),
    // Class options inherit the same A→B road geometry (coords live on the
    // parent quote payload, not per-class rows).
    options: _decodeOptions(
      data['options'],
      km,
      route,
      intercity: data['intercity'] == true,
    ),
    route: route,
    intercity: data['intercity'] == true,
    bidCeilingPercent: _ceilingPercent(data),
    fareStepVnd: _fareStep(data),
  );
}

int? _ceilingPercent(Map<String, Object?> data) {
  final direct = _int(data['bidCeilingPercent']);
  if (direct != null) return direct;
  final tariff = data['tariff'];
  if (tariff is Map) {
    return _int(Map<String, Object?>.from(tariff)['bidCeilingPercent']);
  }
  return null;
}

List<RideQuote> _decodeOptions(
  Object? raw,
  double distanceKm,
  RouteGeometry route, {
  bool intercity = false,
}) {
  if (raw is! List) {
    return const [];
  }
  final options = <RideQuote>[];
  for (final item in raw) {
    if (item is! Map) {
      continue;
    }
    final data = Map<String, Object?>.from(item);
    final reference = data['referenceFareVnd'];
    final min = data['minFareVnd'];
    final max = data['maxFareVnd'];
    final code = _text(data['code']);
    if (reference is! num || min is! num || max is! num || code == null) {
      continue;
    }
    options.add(
      RideQuote(
        distanceKm: distanceKm,
        referenceFareVnd: reference.toInt(),
        minFareVnd: min.toInt(),
        maxFareVnd: max.toInt(),
        minBidVnd: _int(data['minBidVnd']),
        maxBidVnd: _int(data['maxBidVnd']),
        vehicleClassCode: code,
        vehicleClassName: _text(data['name']),
        seats: _int(data['seats']),
        baseFareVnd: _int(data['baseFareVnd']) ?? 0,
        perKmVnd: _int(data['perKmVnd']) ?? 0,
        perMinuteVnd: _int(data['perMinuteVnd']) ?? 0,
        durationMin: _int(data['durationMin']) ?? 0,
        imageUrl: _text(data['imageUrl']),
        route: route,
        // Multi-stop: a class whose service has stops off / too few allowed.
        available: data['available'] != false,
        unavailableReason: _text(data['unavailableReason']),
        intercity: intercity,
        bidCeilingPercent: _ceilingPercent(data),
        fareStepVnd: _fareStep(data),
      ),
    );
  }
  return List.unmodifiable(options);
}

List<RideVehicleClassOption> decodeVehicleClasses(Map<String, Object?> data) {
  final raw = data['classes'];
  if (raw is! List) {
    return const [];
  }
  final classes = <RideVehicleClassOption>[];
  for (final item in raw) {
    if (item is! Map) {
      continue;
    }
    final row = Map<String, Object?>.from(item);
    final code = _text(row['code']);
    final name = _text(row['name']);
    final seats = _int(row['seats']);
    if (code == null || name == null || seats == null) {
      continue;
    }
    classes.add(
      RideVehicleClassOption(
        code: code,
        name: name,
        seats: seats,
        imageUrl: _text(row['imageUrl']),
      ),
    );
  }
  return List.unmodifiable(classes);
}

String? _text(Object? value) {
  if (value is! String) {
    return null;
  }
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

/// MOB-001: the server's fare step (falls back to 1.000đ; top-level falls back to the first option).
int _fareStep(Map<String, Object?> data) {
  int? read(Object? raw) {
    final v = _int(raw);
    return v != null && v > 0 ? v : null;
  }

  final direct = read(data['fareStepVnd']);
  if (direct != null) return direct;
  final options = data['options'];
  if (options is List && options.isNotEmpty && options.first is Map) {
    final nested = read((options.first as Map)['fareStepVnd']);
    if (nested != null) return nested;
  }
  return RideQuote.defaultFareStepVnd;
}

int? _int(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return null;
}

/// Offline quotes for tests, screenshots and `useMockData`, mirroring the
/// backend rule with the seeded setting values (fares rounded up to 1.000đ).
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

  /// Stops sent with the last [quoteRide] call (multi-stop assertions).
  List<PricePoint> lastStops = const [];

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
    List<PricePoint> stops = const [],
  }) async {
    _maybeFail();
    lastStops = stops;
    final km = _haversineKm(pickup, dropoff);
    final distanceKm = (km * 10).round() / 10;
    final reference =
        fixedReferenceVnd ??
        math.max(minFareVnd, _roundUpToFareStep((km * vndPerKm).round()));
    final bikeReference = math.min(reference, maxFareVnd);
    final options = [
      _fakeClass(
        distanceKm: distanceKm,
        code: 'MOTORBIKE',
        name: 'Xe máy',
        seats: 1,
        referenceFareVnd: bikeReference,
        minFareVnd: minFareVnd,
        maxFareVnd: maxFareVnd,
        perKmVnd: vndPerKm,
      ),
      _fakeClass(
        distanceKm: distanceKm,
        code: 'CAR_4',
        name: 'Xe 4 chỗ',
        seats: 4,
        referenceFareVnd: _fakeCarFare(
          km: km,
          base: minFareVnd,
          perKm: (vndPerKm * 1.5).round(),
          perMinute: 400,
          speedKmh: 22,
          minFare: minFareVnd * 2,
          maxFare: maxFareVnd * 2,
        ),
        minFareVnd: minFareVnd * 2,
        maxFareVnd: maxFareVnd * 2,
        baseFareVnd: minFareVnd,
        perKmVnd: (vndPerKm * 1.5).round(),
        perMinuteVnd: 400,
        durationMin: ((km / 22) * 60).round(),
      ),
      _fakeClass(
        distanceKm: distanceKm,
        code: 'CAR_7',
        name: 'Xe 7 chỗ',
        seats: 7,
        referenceFareVnd: _fakeCarFare(
          km: km,
          base: (minFareVnd * 1.5).round(),
          perKm: (vndPerKm * 1.8).round(),
          perMinute: 500,
          speedKmh: 20,
          minFare: minFareVnd * 3,
          maxFare: maxFareVnd * 3,
        ),
        minFareVnd: minFareVnd * 3,
        maxFareVnd: maxFareVnd * 3,
        baseFareVnd: (minFareVnd * 1.5).round(),
        perKmVnd: (vndPerKm * 1.8).round(),
        perMinuteVnd: 500,
        durationMin: ((km / 20) * 60).round(),
      ),
    ];
    return RideQuote(
      distanceKm: distanceKm,
      referenceFareVnd: bikeReference,
      minFareVnd: minFareVnd,
      maxFareVnd: maxFareVnd,
      vehicleClassCode: 'MOTORBIKE',
      vehicleClassName: 'Xe máy',
      seats: 1,
      perKmVnd: vndPerKm,
      options: options,
    );
  }

  @override
  Future<List<RideVehicleClassOption>> listVehicleClasses({
    required String accessToken,
  }) async {
    _maybeFail();
    return const [
      RideVehicleClassOption(code: 'MOTORBIKE', name: 'Xe máy', seats: 1),
      RideVehicleClassOption(code: 'CAR_4', name: 'Xe 4 chỗ', seats: 4),
      RideVehicleClassOption(code: 'CAR_7', name: 'Xe 7 chỗ', seats: 7),
    ];
  }

  @override
  Future<FoodDeliveryQuote> quoteFoodDelivery({
    required String accessToken,
    required String storeId,
    required PricePoint dropoff,
  }) async {
    _maybeFail();
    return FoodDeliveryQuote(
      suggestedVnd: deliveryFareVnd,
      minOfferVnd: (deliveryFareVnd * 0.7 / 1000).ceil() * 1000,
      maxOfferVnd: deliveryFareVnd * 3,
      fareStepVnd: 1000,
    );
  }
}

RideQuote _fakeClass({
  required double distanceKm,
  required String code,
  required String name,
  required int seats,
  required int referenceFareVnd,
  required int minFareVnd,
  required int maxFareVnd,
  int baseFareVnd = 0,
  int perKmVnd = 0,
  int perMinuteVnd = 0,
  int durationMin = 0,
}) {
  return RideQuote(
    distanceKm: distanceKm,
    referenceFareVnd: referenceFareVnd,
    minFareVnd: minFareVnd,
    maxFareVnd: maxFareVnd,
    vehicleClassCode: code,
    vehicleClassName: name,
    seats: seats,
    baseFareVnd: baseFareVnd,
    perKmVnd: perKmVnd,
    perMinuteVnd: perMinuteVnd,
    durationMin: durationMin,
  );
}

int _fakeCarFare({
  required double km,
  required int base,
  required int perKm,
  required int perMinute,
  required int speedKmh,
  required int minFare,
  required int maxFare,
}) {
  final durationMin = ((km / speedKmh) * 60).round();
  final raw = base + (km * perKm).round() + durationMin * perMinute;
  return _roundUpToFareStep(raw).clamp(minFare, maxFare).toInt();
}

/// Mirrors the server's RIDE_FARE_ROUNDING_STEP_VND: suggested fares are whole
/// thousands, rounded up.
int _roundUpToFareStep(int vnd) => ((vnd + 999) ~/ 1000) * 1000;

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
