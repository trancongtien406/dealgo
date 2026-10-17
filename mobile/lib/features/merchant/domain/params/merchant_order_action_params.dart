class MerchantOrderActionParams {
  const MerchantOrderActionParams({
    required this.accessToken,
    required this.orderId,
  });

  final String accessToken;
  final String orderId;
}
