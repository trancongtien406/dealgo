class GetFoodStoreParams {
  const GetFoodStoreParams({
    required this.accessToken,
    required this.storeId,
    this.lat,
    this.lng,
  });

  final String accessToken;
  final String storeId;

  /// Customer position, quoted server-side into the store's "from" fee.
  final double? lat;
  final double? lng;
}
