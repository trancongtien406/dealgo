class SubmitRideOfferParams {
  const SubmitRideOfferParams({
    required this.accessToken,
    required this.rideId,
    required this.amountVnd,
    this.routeVersion,
  });

  /// Route version the driver saw (multi-stop); null on legacy callers.
  final int? routeVersion;

  final String accessToken;
  final String rideId;
  final int amountVnd;
}

/// Backward-compatible alias for existing tests and call sites.
typedef SubmitRideOfferRequest = SubmitRideOfferParams;
