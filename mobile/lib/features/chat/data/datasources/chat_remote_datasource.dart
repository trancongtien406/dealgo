import '../models/chat_models.dart';

abstract interface class ChatRemoteDataSource {
  Future<ChatMessagePageModel> listRideMessages({
    required String accessToken,
    required String rideId,
    int page,
    int limit,
  });

  Future<ChatMessageModel> postRideMessage({
    required String accessToken,
    required String rideId,
    required String body,
  });

  Future<ChatMessagePageModel> listFoodOrderMessages({
    required String accessToken,
    required String orderId,
    bool shop = false,
    int page,
    int limit,
  });

  Future<ChatMessageModel> postFoodOrderMessage({
    required String accessToken,
    required String orderId,
    bool shop = false,
    required String body,
  });
}

/// Backward-compatible alias used by mocks, tests, and DI overrides.
typedef ChatClient = ChatRemoteDataSource;
