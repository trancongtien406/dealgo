import '../entities/chat_models.dart';
import '../params/list_chat_messages_params.dart';
import '../repositories/chat_repository.dart';

class ListRideChatMessages {
  const ListRideChatMessages(this._repository);

  final ChatRepository _repository;

  Future<ChatMessagePage> call(ListRideChatMessagesParams params) {
    return _repository.listRideMessages(
      accessToken: params.accessToken,
      rideId: params.rideId,
      page: params.page,
      limit: params.limit,
    );
  }
}
