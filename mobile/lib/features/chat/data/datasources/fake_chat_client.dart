import '../../domain/entities/chat_models.dart';
import '../models/chat_models.dart';
import 'chat_remote_datasource.dart';

class FakeChatClient implements ChatClient {
  FakeChatClient({this.senderUserId = 'user-demo', this.postError});

  final String senderUserId;
  Object? postError;
  final List<ChatMessageView> _ride = [];
  final List<ChatMessageView> _food = [];
  final List<ChatMessageView> _shop = [];
  var _seq = 0;

  @override
  Future<ChatMessagePageModel> listRideMessages({
    required String accessToken,
    required String rideId,
    int page = 1,
    int limit = 50,
  }) async {
    return ChatMessagePageModel.fromEntity(_page(_ride, page, limit));
  }

  @override
  Future<ChatMessageModel> postRideMessage({
    required String accessToken,
    required String rideId,
    required String body,
  }) async {
    final error = postError;
    if (error != null) {
      throw error;
    }
    final message = _next(threadId: 'ride-$rideId', body: body);
    _ride.add(message);
    return ChatMessageModel.fromEntity(message);
  }

  @override
  Future<ChatMessagePageModel> listFoodOrderMessages({
    required String accessToken,
    required String orderId,
    bool shop = false,
    int page = 1,
    int limit = 50,
  }) async {
    return ChatMessagePageModel.fromEntity(
      _page(shop ? _shop : _food, page, limit),
    );
  }

  @override
  Future<ChatMessageModel> postFoodOrderMessage({
    required String accessToken,
    required String orderId,
    bool shop = false,
    required String body,
  }) async {
    final error = postError;
    if (error != null) {
      throw error;
    }
    final message = _next(
      threadId: '${shop ? 'shop' : 'food'}-$orderId',
      body: body,
    );
    (shop ? _shop : _food).add(message);
    return ChatMessageModel.fromEntity(message);
  }

  ChatMessageView _next({required String threadId, required String body}) {
    _seq += 1;
    return ChatMessageView(
      id: 'msg-$_seq',
      threadId: threadId,
      senderUserId: senderUserId,
      body: body,
      createdAt: DateTime.now().toUtc(),
    );
  }

  void seedRide(ChatMessageView message) => _ride.add(message);

  void seedFood(ChatMessageView message) => _food.add(message);

  void seedShop(ChatMessageView message) => _shop.add(message);

  ChatMessagePage _page(List<ChatMessageView> items, int page, int limit) {
    final start = (page - 1) * limit;
    final slice = start >= items.length
        ? const <ChatMessageView>[]
        : items.sublist(
            start,
            start + limit > items.length ? items.length : start + limit,
          );
    return ChatMessagePage(
      items: slice,
      page: page,
      limit: limit,
      total: items.length,
    );
  }
}
