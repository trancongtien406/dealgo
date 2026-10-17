import '../../../../core/network/api_envelope.dart';
import '../../../../core/network/api_exception.dart';
import '../../domain/entities/ride_models.dart';

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
        message: 'Phản hồi không hợp lệ',
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
        message: 'Phản hồi không hợp lệ',
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
        message: 'Phản hồi không hợp lệ',
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
  });

  final String id;
  final String status;
  final RidePointModel pickup;
  final RidePointModel dropoff;
  final int offeredFareVnd;
  final int referenceFareVnd;
  final String expiresAt;
  final int offerCount;

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
        message: 'Phản hồi không hợp lệ',
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
    );
  }

  static List<OpenRideModel> listFromResponseBody(Object? body) {
    final data = readSuccessPayload(body);
    if (data is! List) {
      throw const ApiException(
        statusCode: 200,
        message: 'Phản hồi không hợp lệ',
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
    );
  }
}

class CreateRideBody {
  const CreateRideBody({
    required this.pickup,
    required this.dropoff,
    required this.offeredFareVnd,
  });

  final RidePointModel pickup;
  final RidePointModel dropoff;
  final int offeredFareVnd;

  Map<String, Object?> toJson() {
    return {
      'pickup': pickup.toJson(),
      'dropoff': dropoff.toJson(),
      'offeredFareVnd': offeredFareVnd,
    };
  }
}

class SelectRideOfferBody {
  const SelectRideOfferBody({required this.offerId});

  final String offerId;

  Map<String, Object?> toJson() => {'offerId': offerId};
}

class SubmitRideOfferBody {
  const SubmitRideOfferBody({required this.amountVnd});

  final int amountVnd;

  Map<String, Object?> toJson() => {'amountVnd': amountVnd};
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
