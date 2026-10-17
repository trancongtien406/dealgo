import 'package:geolocator/geolocator.dart';
import 'package:injectable/injectable.dart';

import '../permissions/app_permission_service.dart';

/// Foreground location shell for ride/driver flows. Background tracking is out of scope.
@lazySingleton
class LocationService {
  LocationService(this._permissions);

  final AppPermissionService _permissions;

  Future<bool> ensurePermission() => _permissions.ensureLocationWhenInUse();

  Future<bool> isLocationServiceEnabled() =>
      Geolocator.isLocationServiceEnabled();

  Future<Position?> currentPosition({
    LocationAccuracy accuracy = LocationAccuracy.high,
  }) async {
    final allowed = await ensurePermission();
    if (!allowed) {
      return null;
    }
    final enabled = await isLocationServiceEnabled();
    if (!enabled) {
      return null;
    }
    return Geolocator.getCurrentPosition(
      locationSettings: LocationSettings(accuracy: accuracy),
    );
  }

  Stream<Position> watchPosition({
    LocationAccuracy accuracy = LocationAccuracy.high,
    int distanceFilterMeters = 10,
  }) {
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilterMeters,
      ),
    );
  }
}
