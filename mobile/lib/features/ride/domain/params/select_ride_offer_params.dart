class SelectRideOfferParams {
  const SelectRideOfferParams({
    required this.accessToken,
    required this.idempotencyKey,
    required this.rideId,
    required this.offerId,
    this.voucherCode,
  });

  final String accessToken;
  final String idempotencyKey;
  final String rideId;
  final String offerId;

  /// DEC-PROD-024: optional voucher, redeemed by the server with the selection.
  final String? voucherCode;
}

/// Backward-compatible alias for existing tests and call sites.
typedef SelectRideOfferRequest = SelectRideOfferParams;
