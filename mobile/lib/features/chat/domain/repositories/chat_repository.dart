import '../entities/chat_models.dart';

abstract interface class ChatRepository {
  Future<ChatMessagePage> listRideMessages({
    required String accessToken,
    required String rideId,
    int page,
    int limit,
  });

  Future<ChatMessageView> postRideMessage({
    required String accessToken,
    required String rideId,
    required String body,
  });

  Future<ChatMessagePage> listFoodOrderMessages({
    required String accessToken,
    required String orderId,
    int page,
    int limit,
  });

  Future<ChatMessageView> postFoodOrderMessage({
    required String accessToken,
    required String orderId,
    required String body,
  });
}
