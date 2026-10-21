enum VoucherService {
  ride('RIDE'),
  food('FOOD');

  const VoucherService(this.wire);

  final String wire;
}

/// Server answer of `POST /v1/promotions/validate`.
class VoucherQuote {
  const VoucherQuote({
    required this.valid,
    required this.code,
    required this.discountVnd,
    required this.finalAmountVnd,
    this.reason,
    this.campaignName,
    this.rejectCode,
  });

  final bool valid;
  final String code;
  final int discountVnd;
  final int finalAmountVnd;

  /// Server-provided rejection reason (Vietnamese copy from the API).
  final String? reason;
  final String? campaignName;

  /// Machine-readable rejection (e.g. VOUCHER_USER_LIMIT); the UI localizes this.
  final String? rejectCode;
}
