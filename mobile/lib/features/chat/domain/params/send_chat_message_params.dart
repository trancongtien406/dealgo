class SendRideChatMessageParams {
  const SendRideChatMessageParams({
    required this.accessToken,
    required this.rideId,
    required this.body,
  });

  final String accessToken;
  final String rideId;
  final String body;
}

class SendFoodOrderChatMessageParams {
  const SendFoodOrderChatMessageParams({
    required this.accessToken,
    required this.orderId,
    required this.body,
    this.shop = false,
  });

  final String accessToken;
  final String orderId;
  final String body;

  /// true = the customer ↔ shop thread; false = customer ↔ driver.
  final bool shop;
}
