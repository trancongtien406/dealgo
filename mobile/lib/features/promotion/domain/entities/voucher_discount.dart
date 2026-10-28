/// Percentage vouchers take off whole 1.000đ steps, rounded down — the same
/// rule as the server (`percentVoucherDiscountVnd`), so an estimate never
/// promises more than checkout gives.
const voucherDiscountStepVnd = 1000;

/// `amountVnd × percent`, capped at [capVnd] when set, rounded down to
/// [voucherDiscountStepVnd]. Never negative.
int percentVoucherDiscountVnd(int amountVnd, num percent, int? capVnd) {
  if (amountVnd <= 0 || percent <= 0) return 0;
  final raw = amountVnd * percent / 100;
  final capped = capVnd != null && capVnd > 0 && raw > capVnd ? capVnd : raw;
  return (capped / voucherDiscountStepVnd).floor() * voucherDiscountStepVnd;
}
