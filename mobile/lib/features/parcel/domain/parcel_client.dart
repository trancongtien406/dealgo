import 'parcel_models.dart';

/// `/v1/parcels*` (DEC-PROD-071). Matching and tracking stay on the ride APIs.
abstract interface class ParcelClient {
  Future<List<ParcelSizeClass>> sizeClasses({required String accessToken});

  Future<ParcelQuote> quote({
    required String accessToken,
    required ParcelDraft draft,
  });

  Future<ParcelRide> create({
    required String accessToken,
    required String idempotencyKey,
    required ParcelDraft draft,
    required String vehicleClassCode,
    required int offeredFareVnd,
  });

  Future<ParcelRide> get({required String accessToken, required String rideId});

  Future<ParcelRide> pickup({
    required String accessToken,
    required String rideId,
    required ParcelPhoto photo,
    String? pickupCode,
  });

  Future<ParcelRide> deliver({
    required String accessToken,
    required String rideId,
    required ParcelPhoto photo,
    String? recipientCode,
  });

  Future<ParcelRide> fail({
    required String accessToken,
    required String rideId,
    required ParcelFailReason reason,
    String? note,
  });

  Future<ParcelRide> returned({
    required String accessToken,
    required String rideId,
    required ParcelPhoto photo,
  });
}
