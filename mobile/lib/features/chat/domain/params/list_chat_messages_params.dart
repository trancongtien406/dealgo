class ListRideChatMessagesParams {
  const ListRideChatMessagesParams({
    required this.accessToken,
    required this.rideId,
    this.page = 1,
    this.limit = 50,
  });

  final String accessToken;
  final String rideId;
  final int page;
  final int limit;
}

class ListFoodOrderChatMessagesParams {
  const ListFoodOrderChatMessagesParams({
    required this.accessToken,
    required this.orderId,
    this.page = 1,
    this.limit = 50,
  });

  final String accessToken;
  final String orderId;
  final int page;
  final int limit;
}
