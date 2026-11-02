import 'package:flutter/widgets.dart';

import '../../../../core/design_system/icons/dealgo_icons.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../presence/domain/entities/driver_service_prefs.dart';
import '../../../ride/presentation/utils/ride_vehicle_label.dart';

/// DEC-PROD-071: food jobs are offered to motorbike drivers only.
/// A missing class still shows the switch; the server fails closed for cars.
bool driverFoodServiceVisible(String? vehicleClassCode) =>
    vehicleClassCode == null || vehicleClassCode == 'MOTORBIKE';

int driverEnabledServiceCount(
  DriverServicePrefs prefs,
  String? vehicleClassCode,
) {
  var count = 0;
  if (prefs.rideEnabled) count++;
  if (prefs.foodEnabled && driverFoodServiceVisible(vehicleClassCode)) {
    count++;
  }
  if (prefs.parcelEnabled) count++;
  return count;
}

/// Single icon set for driver-side service UI so every screen shows the same
/// glyph for the same service.
abstract final class DriverServiceIcons {
  /// Driver UI uses one car glyph for every `CAR_*` class; the 4/7-seat
  /// distinction only matters in the customer vehicle picker.
  static IconData ride(String? vehicleClassCode) =>
      isCarClass(vehicleClassCode) ? DealGoIcons.car : DealGoIcons.motorbike;

  static const IconData food = DealGoIcons.food;
  static const IconData parcel = DealGoIcons.package;

  static bool isCarClass(String? vehicleClassCode) =>
      (vehicleClassCode ?? '').toUpperCase().startsWith('CAR');
}

/// Driver's vehicle: the admin-uploaded class photo, or the ride icon when
/// ops has not uploaded one.
class DriverVehicleVisual extends StatelessWidget {
  const DriverVehicleVisual({
    required this.vehicleClassCode,
    this.imageUrl,
    this.size = 24,
    this.color = DealGoColors.primary,
    super.key,
  });

  final String? vehicleClassCode;
  final String? imageUrl;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return RideVehicleClassVisual(
      code: vehicleClassCode,
      icon: DriverServiceIcons.ride(vehicleClassCode),
      imageUrl: imageUrl,
      size: size,
      color: color,
    );
  }
}
