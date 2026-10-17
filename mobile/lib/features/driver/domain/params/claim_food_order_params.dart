class ClaimFoodOrderParams {
  const ClaimFoodOrderParams({
    required this.accessToken,
    required this.orderId,
  });

  final String accessToken;
  final String orderId;
}
