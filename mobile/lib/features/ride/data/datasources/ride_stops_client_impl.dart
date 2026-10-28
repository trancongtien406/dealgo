import 'package:dio/dio.dart';

import '../../../../core/network/api_envelope.dart';
import '../../../../core/network/api_paths.dart';
import '../../../../core/network/dio_mapper.dart';
import '../../domain/entities/ride_models.dart';
import '../../domain/stops/ride_stops_client.dart';
import '../models/ride_models.dart';

class DioRideStopsClient implements RideStopsClient {
  DioRideStopsClient({required this.dio});

  final Dio dio;

  Options _bearer(String token) =>
      Options(headers: {'Authorization': 'Bearer $token'});

  @override
  Future<MultiStopSettings> config({required String accessToken}) async {
    try {
      final response = await dio.get<Object?>(
        ApiPaths.rideMultiStopConfig,
        options: _bearer(accessToken),
      );
      return parseMultiStopSettings(requireSuccessData(response.data));
    } on DioException catch (error) {
      throw apiExceptionFromDio(error);
    }
  }

  Future<RideView> _ride(Future<Response<Object?>> Function() send) async {
    try {
      final response = await send();
      return RideViewModel.fromResponseBody(response.data).toEntity();
    } on DioException catch (error) {
      throw apiExceptionFromDio(error);
    }
  }

  @override
  Future<RideView> updateStops({
    required String accessToken,
    required String rideId,
    required List<RidePoint> stops,
    int? offeredFareVnd,
    int? routeVersion,
  }) => _ride(
    () => dio.put<Object?>(
      ApiPaths.rideStops(rideId),
      data: UpdateRideStopsBody(
        stops: [for (final s in stops) RidePointModel.fromEntity(s)],
        offeredFareVnd: offeredFareVnd,
        routeVersion: routeVersion,
      ).toJson(),
      options: _bearer(accessToken),
    ),
  );

  @override
  Future<RideView> arriveStop({
    required String accessToken,
    required String rideId,
    required int seq,
  }) => _ride(
    () => dio.post<Object?>(
      ApiPaths.rideStopAction(rideId, seq, 'arrive'),
      options: _bearer(accessToken),
    ),
  );

  @override
  Future<RideView> departStop({
    required String accessToken,
    required String rideId,
    required int seq,
  }) => _ride(
    () => dio.post<Object?>(
      ApiPaths.rideStopAction(rideId, seq, 'depart'),
      options: _bearer(accessToken),
    ),
  );
}

/// In-memory stand-in for tests / USE_MOCK_DATA. Multi-stop is off unless a
/// test passes [settings]; calls are recorded for assertions.
class FakeRideStopsClient implements RideStopsClient {
  FakeRideStopsClient({this.settings = MultiStopSettings.disabled, this.ride});

  MultiStopSettings settings;

  /// Ride returned by every command (its stops are rewritten by the fake).
  RideView? ride;
  final List<String> calls = [];

  @override
  Future<MultiStopSettings> config({required String accessToken}) async {
    calls.add('config');
    return settings;
  }

  RideView _require() {
    final current = ride;
    if (current == null) {
      throw StateError('FakeRideStopsClient.ride not set');
    }
    return current;
  }

  RideView _copy(RideView r, List<RideStop> stops, {int? version}) => RideView(
    id: r.id,
    status: r.status,
    pickup: r.pickup,
    dropoff: r.dropoff,
    offeredFareVnd: r.offeredFareVnd,
    referenceFareVnd: r.referenceFareVnd,
    agreedFareVnd: r.agreedFareVnd,
    assignedDriverId: r.assignedDriverId,
    selectedOfferId: r.selectedOfferId,
    expiresAt: r.expiresAt,
    offers: r.offers,
    pickupCode: r.pickupCode,
    updatedAt: r.updatedAt,
    discountVnd: r.discountVnd,
    voucherCode: r.voucherCode,
    vehicleClassCode: r.vehicleClassCode,
    imageUrl: r.imageUrl,
    route: r.route,
    approachRoute: r.approachRoute,
    customerRating: r.customerRating,
    stops: stops,
    routeVersion: version ?? r.routeVersion,
    currentStopSeq: _firstOpen(stops),
    stopFeeVnd: r.stopFeeVnd,
    waitFeeVnd: r.waitFeeVnd,
  );

  static int? _firstOpen(List<RideStop> stops) {
    for (final s in stops) {
      if (s.departedAt == null) return s.seq;
    }
    return null;
  }

  @override
  Future<RideView> updateStops({
    required String accessToken,
    required String rideId,
    required List<RidePoint> stops,
    int? offeredFareVnd,
    int? routeVersion,
  }) async {
    calls.add('update:${stops.length}');
    final r = _require();
    final next = _copy(r, [
      for (final (i, p) in stops.indexed) RideStop(seq: i + 1, point: p),
    ], version: r.routeVersion + 1);
    ride = next;
    return next;
  }

  RideView _mark(int seq, {required bool arrive}) {
    final r = _require();
    final now = DateTime.now().toUtc().toIso8601String();
    final next = _copy(r, [
      for (final s in r.stops)
        s.seq == seq
            ? RideStop(
                seq: s.seq,
                point: s.point,
                arrivedAt: s.arrivedAt ?? now,
                departedAt: arrive ? s.departedAt : now,
              )
            : s,
    ]);
    ride = next;
    return next;
  }

  @override
  Future<RideView> arriveStop({
    required String accessToken,
    required String rideId,
    required int seq,
  }) async {
    calls.add('arrive:$seq');
    return _mark(seq, arrive: true);
  }

  @override
  Future<RideView> departStop({
    required String accessToken,
    required String rideId,
    required int seq,
  }) async {
    calls.add('depart:$seq');
    return _mark(seq, arrive: false);
  }
}
