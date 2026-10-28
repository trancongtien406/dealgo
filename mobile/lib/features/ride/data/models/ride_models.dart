import '../../../../core/network/api_envelope.dart';
import '../../../../core/network/api_exception.dart';
import '../../domain/entities/ride_models.dart';
import '../../../../core/maps/route_geometry.dart';

class RidePointModel {
  const RidePointModel({
    required this.lat,
    required this.lng,
    required this.label,
  });

  final double lat;
  final double lng;
  final String label;

  factory RidePointModel.fromJson(Map<String, Object?> json) {
    final lat = _asDouble(json['lat']);
    final lng = _asDouble(json['lng']);
    final label = json['label'];
    if (lat == null || lng == null || label is! String || label.isEmpty) {
      throw const ApiException(
        statusCode: 200,
        message: 'Invalid response',
        errorCode: 'INVALID_RESPONSE',
      );
    }
    return RidePointModel(lat: lat, lng: lng, label: label);
  }

  factory RidePointModel.fromEntity(RidePoint point) {
    return RidePointModel(lat: point.lat, lng: point.lng, label: point.label);
  }

  Map<String, Object> toJson() => {'lat': lat, 'lng': lng, 'label': label};

  RidePoint toEntity() => RidePoint(lat: lat, lng: lng, label: label);
}

/// Parses `stops[]`; malformed rows are skipped, order follows `seq`.
List<RideStop> parseRideStops(Object? raw) {
  if (raw is! List) return const [];
  final stops = <RideStop>[];
  for (final (index, item) in raw.indexed) {
    final map = asJsonMap(item);
    if (map == null) continue;
    // The open-ride list sends stops in order without `seq`: use position.
    final seq = _asInt(map['seq']) ?? index + 1;
    try {
      stops.add(
        RideStop(
          seq: seq,
          point: RidePointModel.fromJson(map).toEntity(),
          arrivedAt: _nullableString(map['arrivedAt']),
          departedAt: _nullableString(map['departedAt']),
        ),
      );
    } on ApiException {
      continue;
    }
  }
  stops.sort((a, b) => a.seq.compareTo(b.seq));
  return List.unmodifiable(stops);
}

Map<String, Object?> rideStopToJson(RideStop stop) => {
  'seq': stop.seq,
  'lat': stop.point.lat,
  'lng': stop.point.lng,
  'label': stop.point.label,
  'arrivedAt': stop.arrivedAt,
  'departedAt': stop.departedAt,
};

MultiStopPolicy _policy(Object? raw) {
  final map = asJsonMap(raw);
  if (map == null) return MultiStopPolicy.disabled;
  return MultiStopPolicy(
    enabled: map['enabled'] == true,
    maxStops: _asInt(map['maxStops']) ?? 0,
    stopFeeVnd: _asInt(map['stopFeeVnd']) ?? 0,
    freeWaitMinutes: _asInt(map['freeWaitMinutes']) ?? 0,
    waitFeeVndPerMinute: _asInt(map['waitFeeVndPerMinute']) ?? 0,
  );
}

/// `{BIKE: {...}, CAR: {...}}` → settings; anything malformed reads as off.
MultiStopSettings parseMultiStopSettings(Object? raw) {
  final map = asJsonMap(raw);
  if (map == null) return MultiStopSettings.disabled;
  return MultiStopSettings(
    bike: _policy(map['BIKE']),
    car: _policy(map['CAR']),
  );
}

class RideOfferModel {
  const RideOfferModel({
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

  factory RideOfferModel.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final driverId = json['driverId'];
    final amountVnd = _asInt(json['amountVnd']);
    final kind = RideOfferKind.parse(_string(json['kind']) ?? '');
    final status = RideOfferStatus.parse(_string(json['status']) ?? '');
    final expiresAt = json['expiresAt'];
    if (id is! String ||
        id.isEmpty ||
        driverId is! String ||
        driverId.isEmpty ||
        amountVnd == null ||
        kind == null ||
        status == null ||
        expiresAt is! String ||
        expiresAt.isEmpty) {
      throw const ApiException(
        statusCode: 200,
        message: 'Invalid response',
        errorCode: 'INVALID_RESPONSE',
      );
    }
    return RideOfferModel(
      id: id,
      driverId: driverId,
      amountVnd: amountVnd,
      kind: kind,
      status: status,
      expiresAt: expiresAt,
    );
  }

  factory RideOfferModel.fromEntity(RideOffer offer) {
    return RideOfferModel(
      id: offer.id,
      driverId: offer.driverId,
      amountVnd: offer.amountVnd,
      kind: offer.kind,
      status: offer.status,
      expiresAt: offer.expiresAt,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'driverId': driverId,
      'amountVnd': amountVnd,
      'kind': kind.wire,
      'status': status.wire,
      'expiresAt': expiresAt,
    };
  }

  RideOffer toEntity() {
    return RideOffer(
      id: id,
      driverId: driverId,
      amountVnd: amountVnd,
      kind: kind,
      status: status,
      expiresAt: expiresAt,
    );
  }
}

class RideViewModel {
  const RideViewModel({
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
    required this.vehicleClassCode,
    this.imageUrl,
    this.route = RouteGeometry.unavailable,
    this.approachRoute,
    this.customerRating,
    this.stops = const [],
    this.routeVersion = 0,
    this.currentStopSeq,
    this.stopFeeVnd = 0,
    this.waitFeeVnd = 0,
  });

  final String id;
  final RideStatus status;
  final RidePointModel pickup;
  final RidePointModel dropoff;
  final int offeredFareVnd;
  final int referenceFareVnd;
  final int? agreedFareVnd;
  final String? assignedDriverId;
  final String? selectedOfferId;
  final String expiresAt;
  final List<RideOfferModel> offers;
  final String? pickupCode;
  final String? updatedAt;
  final int discountVnd;
  final String? voucherCode;
  final String vehicleClassCode;
  final String? imageUrl;
  final RouteGeometry route;
  final RouteGeometry? approachRoute;
  final CustomerRatingSummary? customerRating;
  final List<RideStop> stops;
  final int routeVersion;
  final int? currentStopSeq;
  final int stopFeeVnd;
  final int waitFeeVnd;

  factory RideViewModel.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final status = RideStatus.parse(_string(json['status']) ?? '');
    final pickupRaw = asJsonMap(json['pickup']);
    final dropoffRaw = asJsonMap(json['dropoff']);
    final offeredFareVnd = _asInt(json['offeredFareVnd']);
    final referenceFareVnd = _asInt(json['referenceFareVnd']);
    final expiresAt = json['expiresAt'];
    final rawOffers = json['offers'];
    if (id is! String ||
        id.isEmpty ||
        status == null ||
        pickupRaw == null ||
        dropoffRaw == null ||
        offeredFareVnd == null ||
        referenceFareVnd == null ||
        expiresAt is! String ||
        expiresAt.isEmpty ||
        rawOffers is! List) {
      throw const ApiException(
        statusCode: 200,
        message: 'Invalid response',
        errorCode: 'INVALID_RESPONSE',
      );
    }
    final offers = <RideOfferModel>[];
    for (final raw in rawOffers) {
      final map = asJsonMap(raw);
      if (map == null) {
        continue;
      }
      try {
        offers.add(RideOfferModel.fromJson(map));
      } on ApiException {
        continue;
      }
    }
    return RideViewModel(
      id: id,
      status: status,
      pickup: RidePointModel.fromJson(pickupRaw),
      dropoff: RidePointModel.fromJson(dropoffRaw),
      offeredFareVnd: offeredFareVnd,
      referenceFareVnd: referenceFareVnd,
      agreedFareVnd: _nullableInt(json['agreedFareVnd']),
      assignedDriverId: _nullableString(json['assignedDriverId']),
      selectedOfferId: _nullableString(json['selectedOfferId']),
      expiresAt: expiresAt,
      offers: List.unmodifiable(offers),
      pickupCode: _nullableString(json['pickupCode']),
      updatedAt: _nullableString(json['updatedAt']),
      discountVnd: _nullableInt(json['discountVnd']) ?? 0,
      voucherCode: _nullableString(json['voucherCode']),
      vehicleClassCode: _nullableString(json['vehicleClassCode']) ?? '',
      imageUrl: _nullableString(json['imageUrl']),
      route: RouteGeometry.tryParse(json['route']) ?? RouteGeometry.unavailable,
      approachRoute: RouteGeometry.tryParse(json['approachRoute']),
      customerRating: parseCustomerRatingSummary(json['customerRating']),
      stops: parseRideStops(json['stops']),
      routeVersion: _nullableInt(json['routeVersion']) ?? 0,
      currentStopSeq: _nullableInt(json['currentStopSeq']),
      stopFeeVnd: _nullableInt(json['stopFeeVnd']) ?? 0,
      waitFeeVnd: _nullableInt(json['waitFeeVnd']) ?? 0,
    );
  }

  factory RideViewModel.fromEntity(RideView ride) {
    return RideViewModel(
      id: ride.id,
      status: ride.status,
      pickup: RidePointModel.fromEntity(ride.pickup),
      dropoff: RidePointModel.fromEntity(ride.dropoff),
      offeredFareVnd: ride.offeredFareVnd,
      referenceFareVnd: ride.referenceFareVnd,
      agreedFareVnd: ride.agreedFareVnd,
      assignedDriverId: ride.assignedDriverId,
      selectedOfferId: ride.selectedOfferId,
      expiresAt: ride.expiresAt,
      offers: [
        for (final offer in ride.offers) RideOfferModel.fromEntity(offer),
      ],
      pickupCode: ride.pickupCode,
      updatedAt: ride.updatedAt,
      discountVnd: ride.discountVnd,
      voucherCode: ride.voucherCode,
      vehicleClassCode: ride.vehicleClassCode,
      imageUrl: ride.imageUrl,
      route: ride.route,
      approachRoute: ride.approachRoute,
      customerRating: ride.customerRating,
      stops: ride.stops,
      routeVersion: ride.routeVersion,
      currentStopSeq: ride.currentStopSeq,
      stopFeeVnd: ride.stopFeeVnd,
      waitFeeVnd: ride.waitFeeVnd,
    );
  }

  factory RideViewModel.fromResponseBody(Object? body) {
    return RideViewModel.fromJson(requireSuccessData(body));
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'status': status.wire,
      'pickup': pickup.toJson(),
      'dropoff': dropoff.toJson(),
      'offeredFareVnd': offeredFareVnd,
      'referenceFareVnd': referenceFareVnd,
      'agreedFareVnd': agreedFareVnd,
      'assignedDriverId': assignedDriverId,
      'selectedOfferId': selectedOfferId,
      'expiresAt': expiresAt,
      'offers': [for (final offer in offers) offer.toJson()],
      if (pickupCode != null) 'pickupCode': pickupCode,
      if (updatedAt != null) 'updatedAt': updatedAt,
      'discountVnd': discountVnd,
      'voucherCode': voucherCode,
      'vehicleClassCode': vehicleClassCode,
      if (imageUrl != null) 'imageUrl': imageUrl,
      'stops': [for (final stop in stops) rideStopToJson(stop)],
      'routeVersion': routeVersion,
      'currentStopSeq': currentStopSeq,
      'stopFeeVnd': stopFeeVnd,
      'waitFeeVnd': waitFeeVnd,
      'route': {
        'available': route.available,
        'provider': route.provider,
        'coords': [
          for (final c in route.coords) [c.lat, c.lng],
        ],
        if (route.distanceM != null) 'distanceM': route.distanceM,
        if (route.durationSec != null) 'durationSec': route.durationSec,
      },
    };
  }

  RideView toEntity() {
    return RideView(
      id: id,
      status: status,
      pickup: pickup.toEntity(),
      dropoff: dropoff.toEntity(),
      offeredFareVnd: offeredFareVnd,
      referenceFareVnd: referenceFareVnd,
      agreedFareVnd: agreedFareVnd,
      assignedDriverId: assignedDriverId,
      selectedOfferId: selectedOfferId,
      expiresAt: expiresAt,
      offers: List.unmodifiable([for (final offer in offers) offer.toEntity()]),
      pickupCode: pickupCode,
      updatedAt: updatedAt,
      discountVnd: discountVnd < 0 ? 0 : discountVnd,
      voucherCode: voucherCode,
      vehicleClassCode: vehicleClassCode,
      imageUrl: imageUrl,
      route: route,
      approachRoute: approachRoute,
      customerRating: customerRating,
      stops: stops,
      routeVersion: routeVersion,
      currentStopSeq: currentStopSeq,
      stopFeeVnd: stopFeeVnd < 0 ? 0 : stopFeeVnd,
      waitFeeVnd: waitFeeVnd < 0 ? 0 : waitFeeVnd,
    );
  }
}

class OpenRideModel {
  const OpenRideModel({
    required this.id,
    required this.status,
    required this.pickup,
    required this.dropoff,
    required this.offeredFareVnd,
    required this.referenceFareVnd,
    required this.expiresAt,
    required this.offerCount,
    required this.vehicleClassCode,
    this.imageUrl,
    this.customerRating,
    this.stops = const [],
    this.routeVersion = 0,
  });

  final String id;
  final String status;
  final RidePointModel pickup;
  final RidePointModel dropoff;
  final int offeredFareVnd;
  final int referenceFareVnd;
  final String expiresAt;
  final int offerCount;
  final String vehicleClassCode;
  final String? imageUrl;
  final CustomerRatingSummary? customerRating;
  final List<RidePoint> stops;
  final int routeVersion;

  factory OpenRideModel.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final status = json['status'];
    final pickupRaw = asJsonMap(json['pickup']);
    final dropoffRaw = asJsonMap(json['dropoff']);
    final offeredFareVnd = _asInt(json['offeredFareVnd']);
    final referenceFareVnd = _asInt(json['referenceFareVnd']);
    final expiresAt = json['expiresAt'];
    final offerCount = _asInt(json['offerCount']);
    if (id is! String ||
        id.isEmpty ||
        status is! String ||
        status.isEmpty ||
        pickupRaw == null ||
        dropoffRaw == null ||
        offeredFareVnd == null ||
        referenceFareVnd == null ||
        expiresAt is! String ||
        expiresAt.isEmpty ||
        offerCount == null) {
      throw const ApiException(
        statusCode: 200,
        message: 'Invalid response',
        errorCode: 'INVALID_RESPONSE',
      );
    }
    return OpenRideModel(
      id: id,
      status: status,
      pickup: RidePointModel.fromJson(pickupRaw),
      dropoff: RidePointModel.fromJson(dropoffRaw),
      offeredFareVnd: offeredFareVnd,
      referenceFareVnd: referenceFareVnd,
      expiresAt: expiresAt,
      offerCount: offerCount,
      vehicleClassCode: _nullableString(json['vehicleClassCode']) ?? '',
      imageUrl: _nullableString(json['imageUrl']),
      customerRating: parseCustomerRatingSummary(json['customerRating']),
      stops: [for (final stop in parseRideStops(json['stops'])) stop.point],
      routeVersion: _nullableInt(json['routeVersion']) ?? 0,
    );
  }

  factory OpenRideModel.fromEntity(OpenRide ride) {
    return OpenRideModel(
      id: ride.id,
      status: ride.status,
      pickup: RidePointModel.fromEntity(ride.pickup),
      dropoff: RidePointModel.fromEntity(ride.dropoff),
      offeredFareVnd: ride.offeredFareVnd,
      referenceFareVnd: ride.referenceFareVnd,
      expiresAt: ride.expiresAt,
      offerCount: ride.offerCount,
      vehicleClassCode: ride.vehicleClassCode,
      imageUrl: ride.imageUrl,
      customerRating: ride.customerRating,
      stops: ride.stops,
      routeVersion: ride.routeVersion,
    );
  }

  static List<OpenRideModel> listFromResponseBody(Object? body) {
    final data = readSuccessPayload(body);
    if (data is! List) {
      throw const ApiException(
        statusCode: 200,
        message: 'Invalid response',
        errorCode: 'INVALID_RESPONSE',
      );
    }
    final rides = <OpenRideModel>[];
    for (final item in data) {
      final map = asJsonMap(item);
      if (map == null) {
        continue;
      }
      try {
        rides.add(OpenRideModel.fromJson(map));
      } on ApiException {
        continue;
      }
    }
    return List.unmodifiable(rides);
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'status': status,
      'pickup': pickup.toJson(),
      'dropoff': dropoff.toJson(),
      'offeredFareVnd': offeredFareVnd,
      'referenceFareVnd': referenceFareVnd,
      'expiresAt': expiresAt,
      'offerCount': offerCount,
      'vehicleClassCode': vehicleClassCode,
      if (imageUrl != null) 'imageUrl': imageUrl,
      'stops': [
        for (final (i, stop) in stops.indexed)
          {'seq': i + 1, 'lat': stop.lat, 'lng': stop.lng, 'label': stop.label},
      ],
      'routeVersion': routeVersion,
    };
  }

  OpenRide toEntity() {
    return OpenRide(
      id: id,
      status: status,
      pickup: pickup.toEntity(),
      dropoff: dropoff.toEntity(),
      offeredFareVnd: offeredFareVnd,
      referenceFareVnd: referenceFareVnd,
      expiresAt: expiresAt,
      offerCount: offerCount,
      vehicleClassCode: vehicleClassCode,
      imageUrl: imageUrl,
      customerRating: customerRating,
      stops: stops,
      routeVersion: routeVersion,
    );
  }
}

class CreateRideBody {
  const CreateRideBody({
    required this.pickup,
    required this.dropoff,
    required this.offeredFareVnd,
    required this.vehicleClassCode,
    this.stops = const [],
  });

  final RidePointModel pickup;
  final RidePointModel dropoff;
  final int offeredFareVnd;
  final String vehicleClassCode;
  final List<RidePointModel> stops;

  Map<String, Object?> toJson() {
    return {
      'pickup': pickup.toJson(),
      'dropoff': dropoff.toJson(),
      // Omitted when empty so single-destination bodies stay byte-identical.
      if (stops.isNotEmpty) 'stops': [for (final s in stops) s.toJson()],
      'offeredFareVnd': offeredFareVnd,
      'vehicleClassCode': vehicleClassCode,
    };
  }
}

/// `PUT /v1/rides/:id/stops` — full replacement of the stop list.
class UpdateRideStopsBody {
  const UpdateRideStopsBody({
    required this.stops,
    this.offeredFareVnd,
    this.routeVersion,
  });

  final List<RidePointModel> stops;
  final int? offeredFareVnd;
  final int? routeVersion;

  Map<String, Object?> toJson() => {
    'stops': [for (final s in stops) s.toJson()],
    if (offeredFareVnd != null) 'offeredFareVnd': offeredFareVnd,
    if (routeVersion != null) 'routeVersion': routeVersion,
  };
}

class SelectRideOfferBody {
  const SelectRideOfferBody({required this.offerId, this.voucherCode});

  final String offerId;
  final String? voucherCode;

  Map<String, Object?> toJson() => {
    'offerId': offerId,
    if (voucherCode != null && voucherCode!.trim().isNotEmpty)
      'voucherCode': voucherCode!.trim().toUpperCase(),
  };
}

class SubmitRideOfferBody {
  const SubmitRideOfferBody({required this.amountVnd, this.routeVersion});

  final int amountVnd;
  final int? routeVersion;

  Map<String, Object?> toJson() => {
    'amountVnd': amountVnd,
    if (routeVersion != null) 'routeVersion': routeVersion,
  };
}

String? _string(Object? value) {
  if (value is! String) {
    return null;
  }
  return value;
}

String? _nullableString(Object? value) {
  if (value is! String) {
    return null;
  }
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

int? _nullableInt(Object? value) {
  if (value == null) {
    return null;
  }
  return _asInt(value);
}

/// `{average: number|null, count}`; anything else reads as absent.
CustomerRatingSummary? parseCustomerRatingSummary(Object? raw) {
  final map = asJsonMap(raw);
  if (map == null) {
    return null;
  }
  final count = _asInt(map['count']);
  if (count == null || count < 0) {
    return null;
  }
  final average = map['average'];
  return CustomerRatingSummary(
    average: average is num ? average.toDouble() : null,
    count: count,
  );
}

int? _asInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num && value == value.roundToDouble()) {
    return value.toInt();
  }
  return null;
}

double? _asDouble(Object? value) {
  if (value is double) {
    return value;
  }
  if (value is num) {
    return value.toDouble();
  }
  return null;
}
