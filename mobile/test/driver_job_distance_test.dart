import 'package:dealgo/features/driver/presentation/widgets/driver_job_distance.dart';
import 'package:dealgo/features/live_location/domain/driver_location.dart';
import 'package:dealgo/features/ride/domain/entities/ride_models.dart';
import 'package:flutter_test/flutter_test.dart';

OpenRide _ride({double? trip, double? pickup}) => OpenRide(
  id: 'r1',
  status: 'NEGOTIATING',
  pickup: const RidePoint(lat: 16.0544, lng: 108.2022, label: 'A'),
  dropoff: const RidePoint(lat: 16.0471, lng: 108.2062, label: 'B'),
  offeredFareVnd: 42000,
  referenceFareVnd: 40000,
  expiresAt: '2030-01-01T00:00:00.000Z',
  offerCount: 0,
  tripDistanceKm: trip,
  pickupDistanceKm: pickup,
);

void main() {
  test('server distances win and are exact', () {
    final d = jobDistances(_ride(trip: 5.2, pickup: 1.4), null);
    expect(d.trip!.approx, isFalse);
    expect(d.trip!.km, 5.2);
    expect(d.pickup!.km, 1.4);
    expect(d.pickup!.text.startsWith('~'), isFalse);
  });

  test('falls back to ~haversine; pickup hidden without a fix', () {
    final d = jobDistances(_ride(), null);
    expect(d.trip!.approx, isTrue);
    expect(d.trip!.km, closeTo(0.92, 0.1));
    expect(d.trip!.text.startsWith('~'), isTrue);
    expect(d.pickup, isNull);
  });

  test('pickup estimated from driver fix', () {
    final d = jobDistances(
      _ride(),
      const DriverLocationFix(lat: 16.0544, lng: 108.2122),
    );
    expect(d.pickup!.approx, isTrue);
    expect(d.pickup!.km, closeTo(1.07, 0.1));
  });
}
