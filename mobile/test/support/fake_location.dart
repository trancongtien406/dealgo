import 'package:dealgo/core/location/location_service.dart';
import 'package:dealgo/core/permissions/app_permission_service.dart';
import 'package:geolocator/geolocator.dart';

/// Pickup used by widget tests (Hải Châu, Đà Nẵng).
const testPickupLat = 16.0544;
const testPickupLng = 108.2022;

/// Device location for widget tests: a fixed GPS fix, or none (denied).
class FakeLocationService extends LocationService {
  FakeLocationService({this.lat = testPickupLat, this.lng = testPickupLng})
    : denied = false,
      super(AppPermissionService());

  FakeLocationService.denied()
    : lat = 0,
      lng = 0,
      denied = true,
      super(AppPermissionService());

  final double lat;
  final double lng;
  final bool denied;

  @override
  Future<bool> ensurePermission() async => !denied;

  @override
  Future<Position?> currentPosition({
    LocationAccuracy accuracy = LocationAccuracy.high,
  }) async {
    if (denied) {
      return null;
    }
    return Position(
      latitude: lat,
      longitude: lng,
      timestamp: DateTime.utc(2026),
      accuracy: 5,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );
  }
}
