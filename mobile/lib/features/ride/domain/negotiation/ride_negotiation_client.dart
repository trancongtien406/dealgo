/// Negotiation / lifecycle actions.
///
/// Every call is a REST command; the resulting state reaches the screens over
/// the existing Socket.IO snapshot rooms, and pages re-GET the ride (snapshot)
/// afterwards. The server owns every rule (fare floor, edit caps, free-cancel
/// window, no-show wait) — admin settings, DRAFT defaults.
abstract interface class RideNegotiationClient {
  /// Customer opts in to taking an exact-price accept (`POST /v1/rides/:id/auto-accept`).
  Future<void> setAutoAccept({
    required String accessToken,
    required String rideId,
    required bool enabled,
  });

  /// Driver has this request on screen (`POST /v1/rides/:id/viewing`).
  Future<void> noteViewing({
    required String accessToken,
    required String rideId,
  });

  /// Driver left the request (`DELETE /v1/rides/:id/viewing`).
  Future<void> leaveViewing({
    required String accessToken,
    required String rideId,
  });

  /// Customer raises the fare while NEGOTIATING (`POST /v1/rides/:id/fare`).
  Future<void> raiseFare({
    required String accessToken,
    required String rideId,
    required int amountVnd,
  });

  /// Customer turns one offer down (`POST /v1/rides/:id/offers/decline`).
  Future<void> declineOffer({
    required String accessToken,
    required String rideId,
    required String offerId,
  });

  /// Driver takes their pending offer back (`POST /v1/rides/:id/offers/withdraw`).
  Future<void> withdrawOffer({
    required String accessToken,
    required String rideId,
  });

  /// Assigned driver cancels before the trip starts (`POST /v1/rides/:id/driver-cancel`).
  Future<void> driverCancel({
    required String accessToken,
    required String rideId,
    required DriverCancelReason reason,
  });

  /// Driver reports the customer did not show (`POST /v1/rides/:id/no-show`).
  Future<void> markNoShow({
    required String accessToken,
    required String rideId,
  });

  /// Driver's rating of the customer for a completed ride (null when not rated).
  Future<CustomerRatingEntry?> customerRating({
    required String accessToken,
    required String rideId,
  });

  /// Driver rates the customer (`POST /v1/rides/:id/customer-rating`).
  Future<void> rateCustomer({
    required String accessToken,
    required String rideId,
    required int stars,
    List<String> tags = const [],
    String? comment,
  });

  /// Driver hands a claimed food order back before pickup (`POST /v1/food/orders/:id/release`).
  Future<void> releaseFoodOrder({
    required String accessToken,
    required String orderId,
    required FoodReleaseReason reason,
  });
}

enum DriverCancelReason {
  customerUnreachable('CUSTOMER_UNREACHABLE'),
  pickupTooFar('PICKUP_TOO_FAR'),
  vehicleProblem('VEHICLE_PROBLEM'),
  safetyConcern('SAFETY_CONCERN'),
  customerAsked('CUSTOMER_ASKED'),
  other('OTHER');

  const DriverCancelReason(this.wire);

  final String wire;
}

enum FoodReleaseReason {
  storeTooSlow('STORE_TOO_SLOW'),
  storeClosed('STORE_CLOSED'),
  vehicleProblem('VEHICLE_PROBLEM'),
  safetyConcern('SAFETY_CONCERN'),
  other('OTHER');

  const FoodReleaseReason(this.wire);

  final String wire;
}

/// Tags the backend accepts for a customer rating.
const customerRatingTags = [
  'ON_TIME',
  'POLITE',
  'CLEAR_PICKUP',
  'LATE',
  'RUDE',
  'WRONG_PICKUP',
];

class CustomerRatingEntry {
  const CustomerRatingEntry({
    required this.stars,
    this.tags = const [],
    this.comment,
  });

  final int stars;
  final List<String> tags;
  final String? comment;
}
