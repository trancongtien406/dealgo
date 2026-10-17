const foodDeliveryFareMinVnd = 5000;
const foodDeliveryFareMaxVnd = 100000;
const foodDefaultDeliveryFareVnd = 25000;
const foodLineQuantityMax = 20;

const foodDefaultDropoffLat = 16.1064;
const foodDefaultDropoffLng = 108.2522;
const foodDefaultDropoffLabel = '456 Trần Hưng Đạo, Sơn Trà, Đà Nẵng';

String formatVnd(int amount) {
  final sign = amount < 0 ? '-' : '';
  final digits = amount.abs().toString();
  final groups = <String>[];
  for (var end = digits.length; end > 0; end -= 3) {
    final start = end - 3 < 0 ? 0 : end - 3;
    groups.add(digits.substring(start, end));
  }
  return '$sign${groups.reversed.join('.')}đ';
}

String formatVndDelta(int amount) {
  if (amount > 0) {
    return '+${formatVnd(amount)}';
  }
  return formatVnd(amount);
}

int clampDeliveryFare(int amount) {
  if (amount < foodDeliveryFareMinVnd) {
    return foodDeliveryFareMinVnd;
  }
  if (amount > foodDeliveryFareMaxVnd) {
    return foodDeliveryFareMaxVnd;
  }
  return amount;
}

bool deliveryFareInRange(int amount) {
  return amount >= foodDeliveryFareMinVnd && amount <= foodDeliveryFareMaxVnd;
}
