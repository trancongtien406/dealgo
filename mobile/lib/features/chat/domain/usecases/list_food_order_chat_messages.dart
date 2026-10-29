import '../entities/chat_models.dart';
import '../params/list_chat_messages_params.dart';
import '../repositories/chat_repository.dart';

class ListFoodOrderChatMessages {
  const ListFoodOrderChatMessages(this._repository);

  final ChatRepository _repository;

  Future<ChatMessagePage> call(ListFoodOrderChatMessagesParams params) {
    return _repository.listFoodOrderMessages(
      accessToken: params.accessToken,
      orderId: params.orderId,
      shop: params.shop,
      page: params.page,
      limit: params.limit,
    );
  }
}
