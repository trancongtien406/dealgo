import '../entities/chat_models.dart';
import '../params/send_chat_message_params.dart';
import '../repositories/chat_repository.dart';

class SendRideChatMessage {
  const SendRideChatMessage(this._repository);

  final ChatRepository _repository;

  Future<ChatMessageView> call(SendRideChatMessageParams params) {
    return _repository.postRideMessage(
      accessToken: params.accessToken,
      rideId: params.rideId,
      body: params.body,
    );
  }
}
