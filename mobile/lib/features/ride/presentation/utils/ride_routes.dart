abstract final class RideRoutes {
  static const routeOverview = '/customer/ride/route';
  static const vehicle = '/customer/ride/vehicle';
  static const fareBreakdown = '/customer/ride/fare-detail';
  static const fare = '/customer/ride/fare';
  static const parcel = '/customer/parcel';
  static const parcelDetails = '/customer/parcel/details';

  static String offers(String rideId) {
    return '/customer/ride/offers/${Uri.encodeComponent(rideId)}';
  }

  static String offerDetail(String rideId, {String? offerId}) {
    final base = '/customer/ride/offers/${Uri.encodeComponent(rideId)}/detail';
    if (offerId == null || offerId.isEmpty) {
      return base;
    }
    return '$base?offerId=${Uri.encodeQueryComponent(offerId)}';
  }

  static String confirm(String rideId) {
    return '/customer/ride/confirm/${Uri.encodeComponent(rideId)}';
  }

  static String matching(String rideId) {
    return '/customer/ride/matching/${Uri.encodeComponent(rideId)}';
  }

  static String tracking(String rideId) {
    return '/customer/ride/tracking/${Uri.encodeComponent(rideId)}';
  }

  static String pickupCode(String rideId) {
    return '/customer/ride/tracking/${Uri.encodeComponent(rideId)}/pickup-code';
  }

  static String safety(String rideId) {
    return '/customer/ride/tracking/${Uri.encodeComponent(rideId)}/safety';
  }

  static String cancel(String rideId) {
    return '/customer/ride/cancel/${Uri.encodeComponent(rideId)}';
  }

  static String receipt(String rideId) {
    return '/customer/ride/receipt/${Uri.encodeComponent(rideId)}';
  }
}
