class SetPresenceParams {
  const SetPresenceParams({
    required this.accessToken,
    required this.online,
    this.lat,
    this.lng,
  });

  final String accessToken;
  final bool online;
  final double? lat;
  final double? lng;
}
