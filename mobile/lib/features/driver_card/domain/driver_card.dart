/// Real driver info shown on the customer's own ride / food order: profile
/// name, vehicle declared in the approved KYC application and rating summary.
class DriverCard {
  const DriverCard({
    required this.driverId,
    required this.displayName,
    this.avatarUrl,
    this.vehiclePlate,
    this.vehicleType,
    this.ratingAverage,
    this.ratingCount = 0,
  });

  final String driverId;
  final String displayName;
  final String? avatarUrl;
  final String? vehiclePlate;
  final String? vehicleType;
  final double? ratingAverage;
  final int ratingCount;

  /// "Xe máy · 43B1-678.90" — only the parts the driver actually declared.
  String? get vehicleLine {
    final parts = [vehicleType, vehiclePlate].whereType<String>().toList();
    return parts.isEmpty ? null : parts.join(' · ');
  }
}

/// [rideOffer] needs the offer id as well (customer comparing offers).
enum DriverCardJob { ride, rideOffer, foodOrder }

abstract interface class DriverCardRepository {
  /// Throws `ApiException` (404 `DRIVER_NOT_ASSIGNED` before a driver accepts).
  Future<DriverCard> fetch({
    required String accessToken,
    required DriverCardJob job,
    required String jobId,
    String? offerId,
  });
}
