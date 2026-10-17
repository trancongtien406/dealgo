const rideFareMinVnd = 10000;
const rideFareMaxVnd = 500000;
const rideDefaultOfferVnd = 42000;
const rideFarePresetsVnd = <int>[38000, 42000, 48000];

const rideSamplePickupLat = 16.0544;
const rideSamplePickupLng = 108.2022;
const rideSamplePickupLabel = 'Hải Châu';
const rideSampleDropoffLat = 16.0471;
const rideSampleDropoffLng = 108.2062;
const rideSampleDropoffLabel = 'Sân bay';

const rideVehicleLabel = 'Xe máy';
const rideLabelMaxLength = 160;

bool rideFareAllowed(int amount) {
  return amount >= rideFareMinVnd && amount <= rideFareMaxVnd;
}

String formatRideVnd(int amount) {
  final sign = amount < 0 ? '-' : '';
  final digits = amount.abs().toString();
  final groups = <String>[];
  for (var end = digits.length; end > 0; end -= 3) {
    final start = end - 3 < 0 ? 0 : end - 3;
    groups.add(digits.substring(start, end));
  }
  return '$sign${groups.reversed.join('.')}đ';
}

String formatRideVndDelta(int amount) {
  if (amount > 0) {
    return '+${formatRideVnd(amount)}';
  }
  return formatRideVnd(amount);
}

String rideFareRangeLabel() {
  return 'Mức cho phép từ ${formatRideVnd(rideFareMinVnd)} đến ${formatRideVnd(rideFareMaxVnd)}';
}
