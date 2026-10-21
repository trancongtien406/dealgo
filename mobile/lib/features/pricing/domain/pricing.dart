/// Server quote for a ride before booking (`POST /v1/rides/quote`).
///
/// Bounds and the reference fare come from admin settings; the app never
/// hardcodes them.
class RideQuote {
  const RideQuote({
    required this.distanceKm,
    required this.referenceFareVnd,
    required this.minFareVnd,
    required this.maxFareVnd,
  });

  final double distanceKm;
  final int referenceFareVnd;
  final int minFareVnd;
  final int maxFareVnd;

  bool allows(int amountVnd) =>
      amountVnd >= minFareVnd && amountVnd <= maxFareVnd;

  /// Up to three bid shortcuts around the reference fare, rounded to 1.000đ
  /// and kept inside the admin bounds. They are only shortcuts: the customer
  /// can type any amount the bounds allow.
  List<int> get presetsVnd {
    int round(double value) {
      final rounded = (value / 1000).round() * 1000;
      return rounded.clamp(minFareVnd, maxFareVnd);
    }

    return {
      round(referenceFareVnd * 0.9),
      round(referenceFareVnd.toDouble()),
      round(referenceFareVnd * 1.15),
    }.toList();
  }
}

/// A stop sent to the quote endpoints.
typedef PricePoint = ({double lat, double lng, String label});

abstract interface class PricingRepository {
  Future<RideQuote> quoteRide({
    required String accessToken,
    required PricePoint pickup,
    required PricePoint dropoff,
  });

  /// Delivery fare the server will charge for this store and drop-off.
  Future<int> quoteFoodDelivery({
    required String accessToken,
    required String storeId,
    required PricePoint dropoff,
  });
}
