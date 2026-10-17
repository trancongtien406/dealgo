import 'ride_money.dart';
import 'ride_models.dart';

enum RideVehicleKind { bike, car4, car7 }

class RideBookingDraft {
  const RideBookingDraft({
    required this.places,
    this.vehicleKind = RideVehicleKind.car4,
  });

  final RidePlaces places;
  final RideVehicleKind vehicleKind;

  int get suggestedFareVnd => switch (vehicleKind) {
    RideVehicleKind.bike => 25000,
    RideVehicleKind.car4 => rideDefaultOfferVnd,
    RideVehicleKind.car7 => 65000,
  };

  String get vehicleLabel => switch (vehicleKind) {
    RideVehicleKind.bike => 'Xe máy',
    RideVehicleKind.car4 => 'Xe 4 chỗ',
    RideVehicleKind.car7 => 'Xe 7 chỗ',
  };
}

String rideQuoteDisplayId(String rideId) {
  final compact = rideId.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
  if (compact.isEmpty) {
    return 'Q-CAR-0007';
  }
  final tail = compact.length <= 4
      ? compact.padLeft(4, '0')
      : compact.substring(compact.length - 4);
  return 'Q-CAR-$tail';
}

String ridePickupCode(String rideId) {
  var hash = 0;
  for (final unit in rideId.codeUnits) {
    hash = (hash * 31 + unit) & 0x7fffffff;
  }
  final code = (hash % 9000) + 1000;
  return '$code';
}
