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
  });

  final double distanceKm;
  final int referenceFareVnd;
  final int minFareVnd;
  final int maxFareVnd;
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

  /// Delivery fare the server will charge for this store and drop-off.
  Future<int> quoteFoodDelivery({
    required String accessToken,
    required String storeId,
    required PricePoint dropoff,
  });
}
