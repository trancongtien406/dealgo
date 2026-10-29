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
    this.shop = false,
  });

  final String accessToken;
  final String orderId;

  /// true = the customer ↔ shop thread; false = customer ↔ driver.
  final bool shop;
  final int page;
  final int limit;
}
