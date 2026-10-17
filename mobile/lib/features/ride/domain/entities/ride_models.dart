import 'ride_money.dart';

enum RideStatus {
  negotiating('NEGOTIATING'),
  assigned('ASSIGNED'),
  cancelled('CANCELLED'),
  expired('EXPIRED');

  const RideStatus(this.wire);

  final String wire;

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
  lost('LOST');

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

class RidePoint {
  const RidePoint({required this.lat, required this.lng, required this.label});

  final double lat;
  final double lng;
  final String label;
}

class RidePlaces {
  const RidePlaces({required this.pickupLabel, required this.dropoffLabel});

  final String pickupLabel;
  final String dropoffLabel;

  RidePoint get pickup {
    return RidePoint(
      lat: rideSamplePickupLat,
      lng: rideSamplePickupLng,
      label: pickupLabel.trim(),
    );
  }

  RidePoint get dropoff {
    return RidePoint(
      lat: rideSampleDropoffLat,
      lng: rideSampleDropoffLng,
      label: dropoffLabel.trim(),
    );
  }

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
  });

  final String id;
  final String status;
  final RidePoint pickup;
  final RidePoint dropoff;
  final int offeredFareVnd;
  final int referenceFareVnd;
  final String expiresAt;
  final int offerCount;
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
