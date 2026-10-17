class SelectRideOfferParams {
  const SelectRideOfferParams({
    required this.accessToken,
    required this.idempotencyKey,
    required this.rideId,
    required this.offerId,
  });

  final String accessToken;
  final String idempotencyKey;
  final String rideId;
  final String offerId;
}

/// Backward-compatible alias for existing tests and call sites.
typedef SelectRideOfferRequest = SelectRideOfferParams;
