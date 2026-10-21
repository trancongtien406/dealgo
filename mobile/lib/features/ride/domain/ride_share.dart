/// A read-only trip link for family/friends (`POST /v1/rides/:id/share-link`).
class RideShareLink {
  const RideShareLink({required this.url, required this.expiresAt});

  final String url;
  final DateTime expiresAt;
}

abstract interface class RideShareRepository {
  Future<RideShareLink> create({
    required String accessToken,
    required String rideId,
  });
}
