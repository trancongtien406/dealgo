import '../../domain/entities/chat_models.dart';
import '../../domain/repositories/chat_repository.dart';
import '../datasources/chat_remote_datasource.dart';

class ChatRepositoryImpl implements ChatRepository {
  ChatRepositoryImpl(this._remote);

  final ChatRemoteDataSource _remote;

  @override
  Future<ChatMessagePage> listRideMessages({
    required String accessToken,
    required String rideId,
    int page = 1,
    int limit = 50,
  }) async {
    final model = await _remote.listRideMessages(
      accessToken: accessToken,
      rideId: rideId,
      page: page,
      limit: limit,
    );
    return model.toEntity();
  }

  @override
  Future<ChatMessageView> postRideMessage({
    required String accessToken,
    required String rideId,
    required String body,
  }) async {
    final model = await _remote.postRideMessage(
      accessToken: accessToken,
      rideId: rideId,
      body: body,
    );
    return model.toEntity();
  }

  @override
  Future<ChatMessagePage> listFoodOrderMessages({
    required String accessToken,
    required String orderId,
    int page = 1,
    int limit = 50,
  }) async {
    final model = await _remote.listFoodOrderMessages(
      accessToken: accessToken,
      orderId: orderId,
      page: page,
      limit: limit,
    );
    return model.toEntity();
  }

  @override
  Future<ChatMessageView> postFoodOrderMessage({
    required String accessToken,
    required String orderId,
    required String body,
  }) async {
    final model = await _remote.postFoodOrderMessage(
      accessToken: accessToken,
      orderId: orderId,
      body: body,
    );
    return model.toEntity();
  }
}
