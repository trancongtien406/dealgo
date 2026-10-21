const foodLineQuantityMax = 20;

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
