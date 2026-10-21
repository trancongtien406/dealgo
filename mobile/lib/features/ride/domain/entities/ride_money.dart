const rideLabelMaxLength = 160;

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

/// DEC-PROD-024: cash the customer hands the driver after a voucher (never negative).
int rideCashAfterVoucher(int fareVnd, int discountVnd) {
  final due = fareVnd - discountVnd;
  return due < 0 ? 0 : due;
}
