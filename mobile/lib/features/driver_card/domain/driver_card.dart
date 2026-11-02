/// Real driver info shown on the customer's own ride / food order: profile
/// name, vehicle declared in the approved KYC application and rating summary.
class DriverCard {
  const DriverCard({
    required this.driverId,
    required this.displayName,
    this.avatarUrl,
    this.vehiclePlate,
    this.vehicleType,
    this.vehicleName,
    this.ratingAverage,
    this.ratingCount = 0,
    this.completedTrips,
    this.phone,
  });

  final String driverId;
  final String displayName;
  final String? avatarUrl;
  final String? vehiclePlate;
  final String? vehicleType;

  /// t81u: declared make + model ("Honda Vision"); replaces the generic class.
  final String? vehicleName;
  final double? ratingAverage;
  final int ratingCount;

  /// t81u: lifetime completed rides/parcels + delivered food orders (null on old servers).
  final int? completedTrips;

  /// E.164; the server sends it only while the assigned job is running.
  final String? phone;

  /// "Honda Vision · 43B1-678.90" — the real vehicle when declared, else the
  /// class ("Xe máy"); only the parts the driver actually declared.
  String? get vehicleLine {
    final parts = [
      vehicleName ?? vehicleType,
      vehiclePlate,
    ].whereType<String>().toList();
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

  /// The customer of a job, for its assigned driver.
  /// Throws `ApiException` (404 for anyone but the assigned driver).
  Future<CustomerCard> fetchCustomer({
    required String accessToken,
    required String jobId,
    bool isFood = false,
  });
}

/// What the assigned driver sees about the customer: profile name ('' when
/// unset), avatar and phone (phone only while the job is running).
class CustomerCard {
  const CustomerCard({required this.displayName, this.avatarUrl, this.phone});

  final String displayName;
  final String? avatarUrl;
  final String? phone;
}
