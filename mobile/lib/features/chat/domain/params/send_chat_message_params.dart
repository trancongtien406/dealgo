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
  });

  final String accessToken;
  final String orderId;
  final String body;
}
