import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/api_exception.dart';
import '../../domain/entities/chat_models.dart';
import '../../domain/params/list_chat_messages_params.dart';
import '../../domain/params/send_chat_message_params.dart';
import '../../domain/usecases/list_food_order_chat_messages.dart';
import '../../domain/usecases/list_ride_chat_messages.dart';
import '../../domain/usecases/send_food_order_chat_message.dart';
import '../../domain/usecases/send_ride_chat_message.dart';

enum ChatThreadKind { ride, foodOrder }

class ChatState {
  const ChatState({
    this.messages = const [],
    this.loading = false,
    this.sending = false,
    this.loadError,
    this.sendError,
  });

  final List<ChatMessageView> messages;
  final bool loading;
  final bool sending;
  final Object? loadError;
  final Object? sendError;

  ChatState copyWith({
    List<ChatMessageView>? messages,
    bool? loading,
    bool? sending,
    Object? loadError = _unset,
    Object? sendError = _unset,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      loading: loading ?? this.loading,
      sending: sending ?? this.sending,
      loadError: identical(loadError, _unset) ? this.loadError : loadError,
      sendError: identical(sendError, _unset) ? this.sendError : sendError,
    );
  }
}

const Object _unset = Object();

class ChatCubit extends Cubit<ChatState> {
  ChatCubit({
    required this._listRideChatMessages,
    required this._sendRideChatMessage,
    required this._listFoodOrderChatMessages,
    required this._sendFoodOrderChatMessage,
    required this.kind,
    required this.resourceId,
  }) : super(const ChatState());

  final ListRideChatMessages _listRideChatMessages;
  final SendRideChatMessage _sendRideChatMessage;
  final ListFoodOrderChatMessages _listFoodOrderChatMessages;
  final SendFoodOrderChatMessage _sendFoodOrderChatMessage;
  final ChatThreadKind kind;
  final String resourceId;

  var _loadGeneration = 0;
  var _sendGeneration = 0;

  Future<void> load({required String? accessToken}) async {
    final generation = ++_loadGeneration;
    final token = accessToken?.trim() ?? '';
    if (token.isEmpty) {
      emit(
        state.copyWith(
          loading: false,
          loadError: const ApiException(
            statusCode: 401,
            message: '',
            errorCode: 'UNAUTHORIZED',
          ),
        ),
      );
      return;
    }

    emit(state.copyWith(loading: true, loadError: null));
    try {
      final page = switch (kind) {
        ChatThreadKind.ride => await _listRideChatMessages(
          ListRideChatMessagesParams(accessToken: token, rideId: resourceId),
        ),
        ChatThreadKind.foodOrder => await _listFoodOrderChatMessages(
          ListFoodOrderChatMessagesParams(
            accessToken: token,
            orderId: resourceId,
          ),
        ),
      };
      if (isClosed || generation != _loadGeneration) {
        return;
      }
      emit(
        state.copyWith(
          messages: List.unmodifiable(page.items),
          loading: false,
          loadError: null,
        ),
      );
    } catch (error) {
      if (isClosed || generation != _loadGeneration) {
        return;
      }
      emit(state.copyWith(loading: false, loadError: error));
    }
  }

  Future<void> send({
    required String? accessToken,
    required String body,
  }) async {
    final trimmed = body.trim();
    if (trimmed.isEmpty || state.sending) {
      return;
    }
    final token = accessToken?.trim() ?? '';
    if (token.isEmpty) {
      emit(
        state.copyWith(
          sendError: const ApiException(
            statusCode: 401,
            message: '',
            errorCode: 'UNAUTHORIZED',
          ),
        ),
      );
      return;
    }

    final generation = ++_sendGeneration;
    emit(state.copyWith(sending: true, sendError: null));
    try {
      final message = switch (kind) {
        ChatThreadKind.ride => await _sendRideChatMessage(
          SendRideChatMessageParams(
            accessToken: token,
            rideId: resourceId,
            body: trimmed,
          ),
        ),
        ChatThreadKind.foodOrder => await _sendFoodOrderChatMessage(
          SendFoodOrderChatMessageParams(
            accessToken: token,
            orderId: resourceId,
            body: trimmed,
          ),
        ),
      };
      if (isClosed || generation != _sendGeneration) {
        return;
      }
      final next = [...state.messages, message];
      emit(
        state.copyWith(
          messages: List.unmodifiable(next),
          sending: false,
          sendError: null,
        ),
      );
    } catch (error) {
      if (isClosed || generation != _sendGeneration) {
        return;
      }
      emit(state.copyWith(sending: false, sendError: error));
    }
  }

  void clearSendError() {
    if (state.sendError == null) {
      return;
    }
    emit(state.copyWith(sendError: null));
  }
}
