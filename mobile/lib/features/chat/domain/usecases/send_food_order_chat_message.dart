import '../entities/chat_models.dart';
import '../params/send_chat_message_params.dart';
import '../repositories/chat_repository.dart';

class SendFoodOrderChatMessage {
  const SendFoodOrderChatMessage(this._repository);

  final ChatRepository _repository;

  Future<ChatMessageView> call(SendFoodOrderChatMessageParams params) {
    return _repository.postFoodOrderMessage(
      accessToken: params.accessToken,
      orderId: params.orderId,
      body: params.body,
    );
  }
}
