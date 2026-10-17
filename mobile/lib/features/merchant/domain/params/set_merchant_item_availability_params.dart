class SetMerchantItemAvailabilityParams {
  const SetMerchantItemAvailabilityParams({
    required this.accessToken,
    required this.itemId,
    required this.available,
  });

  final String accessToken;
  final String itemId;
  final bool available;
}
