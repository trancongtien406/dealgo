import '../../../../core/maps/route_geometry.dart';
import '../../../pricing/domain/pricing.dart';
import 'ride_money.dart';

enum RideStatus {
  negotiating('NEGOTIATING'),
  assigned('ASSIGNED'),
  driverEnRoute('DRIVER_EN_ROUTE'),
  driverArrived('DRIVER_ARRIVED'),
  inTrip('IN_TRIP'),
  completed('COMPLETED'),
  cancelled('CANCELLED'),
  expired('EXPIRED');

  const RideStatus(this.wire);

  final String wire;

  /// A driver is attached (ASSIGNED through COMPLETED).
  bool get hasDriver => switch (this) {
    assigned || driverEnRoute || driverArrived || inTrip || completed => true,
    negotiating || cancelled || expired => false,
  };

  /// The trip can no longer change.
  bool get isTerminal =>
      this == completed || this == cancelled || this == expired;

  static RideStatus? parse(String raw) {
    for (final status in RideStatus.values) {
      if (status.wire == raw) {
        return status;
      }
    }
    return null;
  }
}

enum RideOfferKind {
  accept('ACCEPT'),
  counter('COUNTER');

  const RideOfferKind(this.wire);

  final String wire;

  static RideOfferKind? parse(String raw) {
    for (final kind in RideOfferKind.values) {
      if (kind.wire == raw) {
        return kind;
      }
    }
    return null;
  }
}

enum RideOfferStatus {
  pending('PENDING'),
  selected('SELECTED'),
  lost('LOST'),

  /// The customer turned this price down; the driver may re-offer.
  declined('DECLINED'),

  /// The driver took the offer back before the customer chose.
  withdrawn('WITHDRAWN');

  const RideOfferStatus(this.wire);

  final String wire;

  static RideOfferStatus? parse(String raw) {
    for (final status in RideOfferStatus.values) {
      if (status.wire == raw) {
        return status;
      }
    }
    return null;
  }
}

/// The customer's average rating from drivers (null until rated).
class CustomerRatingSummary {
  const CustomerRatingSummary({required this.average, required this.count});

  final double? average;
  final int count;
}

class RidePoint {
  const RidePoint({required this.lat, required this.lng, required this.label});

  final double lat;
  final double lng;
  final String label;
}

/// Pickup and drop-off chosen by the customer, with real coordinates.
class RidePlaces {
  const RidePlaces({
    required this.pickup,
    required this.dropoff,
    this.quote,
    this.vehicleClassCode,
  });

  final RidePoint pickup;
  final RidePoint dropoff;

  /// Server quote (`POST /v1/rides/quote`), once the route overview loaded it.
  final RideQuote? quote;

  /// Class chosen on the vehicle step. Omitted until then.
  final String? vehicleClassCode;

  RidePlaces withQuote(RideQuote quote) => RidePlaces(
    pickup: pickup,
    dropoff: dropoff,
    quote: quote,
    vehicleClassCode: vehicleClassCode,
  );

  RidePlaces selectClass(RideQuote quote) => RidePlaces(
    pickup: pickup,
    dropoff: dropoff,
    quote: quote,
    // DG-DEC-VEH-001: never invent MOTORBIKE when the customer has not chosen a class.
    vehicleClassCode: quote.vehicleClassCode ?? vehicleClassCode,
  );

  String get pickupLabel => pickup.label;
  String get dropoffLabel => dropoff.label;

  bool get canContinue {
    final pickup = pickupLabel.trim();
    final dropoff = dropoffLabel.trim();
    return pickup.isNotEmpty &&
        dropoff.isNotEmpty &&
        pickup.length <= rideLabelMaxLength &&
        dropoff.length <= rideLabelMaxLength;
  }
}

class RideOffer {
  const RideOffer({
    required this.id,
    required this.driverId,
    required this.amountVnd,
    required this.kind,
    required this.status,
    required this.expiresAt,
  });

  final String id;
  final String driverId;
  final int amountVnd;
  final RideOfferKind kind;
  final RideOfferStatus status;
  final String expiresAt;
}

class RideView {
  const RideView({
    required this.id,
    required this.status,
    required this.pickup,
    required this.dropoff,
    required this.offeredFareVnd,
    required this.referenceFareVnd,
    required this.agreedFareVnd,
    required this.assignedDriverId,
    required this.selectedOfferId,
    required this.expiresAt,
    required this.offers,
    this.pickupCode,
    this.updatedAt,
    this.discountVnd = 0,
    this.voucherCode,
    this.vehicleClassCode = '',
    this.imageUrl,
    this.route = RouteGeometry.unavailable,
    this.approachRoute,
    this.customerRating,
  });

  final String id;
  final RideStatus status;
  final RidePoint pickup;
  final RidePoint dropoff;
  final int offeredFareVnd;
  final int referenceFareVnd;
  final int? agreedFareVnd;
  final String? assignedDriverId;
  final String? selectedOfferId;
  final String expiresAt;
  final List<RideOffer> offers;

  /// Server-issued pickup code; only present on the customer's own ride while
  /// the driver is on the way (DEC-PROD-017). Never derived on the client.
  final String? pickupCode;

  /// ISO time of the last status change (completion time once completed).
  final String? updatedAt;

  /// DEC-PROD-024: voucher discount reserved at offer selection (0 when none).
  final int discountVnd;
  final String? voucherCode;
  final String vehicleClassCode;
  final String? imageUrl;

  /// Nest road geometry (ROUTING_PROVIDER). Unavailable ⇒ no line is drawn.
  final RouteGeometry route;

  /// DEC-PROD-031 rev 3 (DRAFT): driver→pickup leg while ASSIGNED /
  /// DRIVER_EN_ROUTE (server-computed snapshot; `routeUpdated` replaces it).
  final RouteGeometry? approachRoute;

  /// Shown to drivers only (null on customer reads).
  final CustomerRatingSummary? customerRating;

  /// Offers still in play (Declined/withdrawn ones stay in the snapshot).
  List<RideOffer> get liveOffers => [
    for (final offer in offers)
      if (offer.status == RideOfferStatus.pending) offer,
  ];

  /// Cash the customer hands the driver: the agreed fare minus the voucher.
  int? get cashDueVnd {
    final agreed = agreedFareVnd;
    if (agreed == null) {
      return null;
    }
    final due = agreed - discountVnd;
    return due < 0 ? 0 : due;
  }
}

class OpenRide {
  const OpenRide({
    required this.id,
    required this.status,
    required this.pickup,
    required this.dropoff,
    required this.offeredFareVnd,
    required this.referenceFareVnd,
    required this.expiresAt,
    required this.offerCount,
    this.vehicleClassCode = '',
    this.imageUrl,
    this.route = RouteGeometry.unavailable,
    this.approachRoute,
    this.customerRating,
  });

  final String id;
  final String status;
  final RidePoint pickup;
  final RidePoint dropoff;
  final int offeredFareVnd;
  final int referenceFareVnd;
  final String expiresAt;
  final int offerCount;
  final String vehicleClassCode;
  final String? imageUrl;
  final RouteGeometry route;

  /// DEC-PROD-031 rev 3 (DRAFT): driver→pickup leg snapshot (assigned only).
  final RouteGeometry? approachRoute;

  /// The customer's rating from drivers, so a driver can decide.
  final CustomerRatingSummary? customerRating;
}

class RideConfirmArgs {
  const RideConfirmArgs({required this.ride, required this.tappedAmountVnd});

  final RideView ride;
  final int tappedAmountVnd;
}

bool rideNegotiationExpired(RideView ride, DateTime now) {
  if (ride.status == RideStatus.expired) {
    return true;
  }
  final expiresAt = DateTime.tryParse(ride.expiresAt);
  if (expiresAt == null) {
    return false;
  }
  return expiresAt.isBefore(now);
}

bool rideOfferSelectable(RideOffer offer, DateTime now) {
  if (offer.status != RideOfferStatus.pending) {
    return false;
  }
  final expiresAt = DateTime.tryParse(offer.expiresAt);
  if (expiresAt == null) {
    return true;
  }
  return !expiresAt.isBefore(now);
}

int? parseRideFareInput(String raw) {
  final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) {
    return null;
  }
  return int.tryParse(digits);
}
