import '../../../core/maps/route_geometry.dart';

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
    this._minBidVnd,
    this._maxBidVnd,
    this.vehicleClassCode,
    this.vehicleClassName,
    this.seats,
    this.baseFareVnd = 0,
    this.perKmVnd = 0,
    this.perMinuteVnd = 0,
    this.durationMin = 0,
    this.imageUrl,
    this.options = const [],
    this.route = RouteGeometry.unavailable,
    this.available = true,
    this.unavailableReason,
    this.intercity = false,
    this.bidCeilingPercent,
    this.fareStepVnd = defaultFareStepVnd,
  });

  /// Fallback when an older server sends no `fareStepVnd` (MOB-001).
  static const defaultFareStepVnd = 1000;

  /// Server fare step: every bid, counter and raise is a multiple of it.
  final int fareStepVnd;

  final double distanceKm;
  final int referenceFareVnd;
  final int minFareVnd;
  final int maxFareVnd;
  final int? _minBidVnd;
  final int? _maxBidVnd;

  /// Lowest / highest bid the server accepts (about -30% / +30% of
  /// [referenceFareVnd], never below the class minimum). Falls back to the
  /// class bounds when the server does not send a band.
  int get minBidVnd => (_minBidVnd ?? minFareVnd).clamp(minFareVnd, maxFareVnd);
  int get maxBidVnd => (_maxBidVnd ?? maxFareVnd).clamp(minBidVnd, maxFareVnd);
  final String? vehicleClassCode;
  final String? vehicleClassName;
  final int? seats;
  final int baseFareVnd;
  final int perKmVnd;
  final int perMinuteVnd;
  final int durationMin;
  final String? imageUrl;

  /// One quote per enabled vehicle class. Empty on a class that was already chosen.
  final List<RideQuote> options;

  /// Nest road geometry for the overview map.
  final RouteGeometry route;

  /// False when this class cannot carry the requested stops (admin flag off
  /// or too many stops); [unavailableReason] is the server error code.
  final bool available;
  final String? unavailableReason;

  /// Server flag: trip leaves the pickup's served region (Liên tỉnh).
  final bool intercity;

  /// Admin ceiling as a percent of [referenceFareVnd] (130 = +30%).
  final int? bidCeilingPercent;

  /// Headroom above the reference the suggestion chips may split (ceiling − 100).
  int? get bidHeadroomPercent {
    final ceiling = bidCeilingPercent;
    if (ceiling == null || ceiling <= 100) return null;
    return ceiling - 100;
  }

  bool allows(int amountVnd) =>
      amountVnd >= minBidVnd && amountVnd <= maxBidVnd;

  /// Up to three bid shortcuts around the reference fare, rounded to 1.000đ
  /// and kept inside the admin bounds. They are only shortcuts: the customer
  /// can type any amount the bounds allow.
  List<int> get presetsVnd {
    int round(double value) {
      final rounded = (value / 1000).round() * 1000;
      return rounded.clamp(minBidVnd, maxBidVnd);
    }

    return {
      round(referenceFareVnd * 0.9),
      round(referenceFareVnd.toDouble()),
      round(referenceFareVnd * 1.15),
    }.toList();
  }
}

/// Admin `FOOD_DELIVERY_FEE_MODE`: [negotiate] lets drivers counter the
/// customer's fee; [fixed] lets drivers only accept it.
enum FoodDeliveryFeeMode { negotiate, fixed }

/// Unknown/missing values keep the negotiation behaviour (older servers).
FoodDeliveryFeeMode parseFoodDeliveryFeeMode(Object? raw) =>
    raw is String && raw.toUpperCase() == 'FIXED'
    ? FoodDeliveryFeeMode.fixed
    : FoodDeliveryFeeMode.negotiate;

/// A stop sent to the quote endpoints.
/// `POST /v1/food/quote`: the fee is a suggestion; the customer offers an
/// amount in [minOfferVnd]..[maxOfferVnd] (steps of [fareStepVnd]) and
/// drivers accept or counter it.
class FoodDeliveryQuote {
  const FoodDeliveryQuote({
    required this.suggestedVnd,
    required this.minOfferVnd,
    required this.maxOfferVnd,
    required this.fareStepVnd,
    this.feeMode = FoodDeliveryFeeMode.negotiate,
  });

  /// Older servers only send `deliveryFareVnd`: offer = suggestion, fixed.
  const FoodDeliveryQuote.fixed(int fareVnd)
    : suggestedVnd = fareVnd,
      minOfferVnd = fareVnd,
      maxOfferVnd = fareVnd,
      fareStepVnd = 1000,
      feeMode = FoodDeliveryFeeMode.negotiate;

  final int suggestedVnd;
  final int minOfferVnd;
  final int maxOfferVnd;
  final int fareStepVnd;

  final FoodDeliveryFeeMode feeMode;

  bool get negotiable => maxOfferVnd > minOfferVnd;

  /// Drivers may propose another fee (false in FIXED mode).
  bool get driversCanCounter => feeMode == FoodDeliveryFeeMode.negotiate;

  /// Clamps [amount] into the bounds (the suggestion itself is always valid).
  int clamp(int amount) {
    if (amount < minOfferVnd) return minOfferVnd;
    if (amount > maxOfferVnd) return maxOfferVnd;
    return amount;
  }

  @override
  bool operator ==(Object other) =>
      other is FoodDeliveryQuote &&
      other.suggestedVnd == suggestedVnd &&
      other.minOfferVnd == minOfferVnd &&
      other.maxOfferVnd == maxOfferVnd &&
      other.fareStepVnd == fareStepVnd &&
      other.feeMode == feeMode;

  @override
  int get hashCode =>
      Object.hash(suggestedVnd, minOfferVnd, maxOfferVnd, fareStepVnd, feeMode);
}

typedef PricePoint = ({double lat, double lng, String label});

class RideVehicleClassOption {
  const RideVehicleClassOption({
    required this.code,
    required this.name,
    required this.seats,
    this.imageUrl,
  });

  final String code;
  final String name;
  final int seats;
  final String? imageUrl;
}

abstract interface class PricingRepository {
  Future<RideQuote> quoteRide({
    required String accessToken,
    required PricePoint pickup,
    required PricePoint dropoff,
    List<PricePoint> stops = const [],
  });

  Future<List<RideVehicleClassOption>> listVehicleClasses({
    required String accessToken,
  });

  /// Suggested delivery fee plus the bounds the customer may offer within.
  Future<FoodDeliveryQuote> quoteFoodDelivery({
    required String accessToken,
    required String storeId,
    required PricePoint dropoff,
  });
}
