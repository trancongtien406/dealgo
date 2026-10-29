import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/realtime/snapshot_realtime.dart';
import '../../domain/entities/chat_models.dart';
import '../../domain/params/list_chat_messages_params.dart';
import '../../domain/params/send_chat_message_params.dart';
import '../../domain/usecases/list_food_order_chat_messages.dart';
import '../../domain/usecases/list_ride_chat_messages.dart';
import '../../domain/usecases/send_food_order_chat_message.dart';
import '../../domain/usecases/send_ride_chat_message.dart';
import '../model/chat_timeline.dart';

/// `foodOrder` = customer ↔ driver of a food order; `foodOrderShop` =
/// customer ↔ shop of the same order. They are separate threads end to end.
enum ChatThreadKind { ride, foodOrder, foodOrderShop }

extension ChatThreadKindX on ChatThreadKind {
  /// Aggregate name used by the realtime `chatMessage` push.
  String get aggregateType => switch (this) {
    ChatThreadKind.ride => 'Ride',
    ChatThreadKind.foodOrder => 'FoodOrder',
    ChatThreadKind.foodOrderShop => 'FoodOrderShop',
  };

  bool get isFood => this != ChatThreadKind.ride;
}

const _unauthorized = ApiException(
  statusCode: 401,
  message: '',
  errorCode: 'UNAUTHORIZED',
);

class ChatState {
  const ChatState({
    this.lines = const [],
    this.loading = false,
    this.loaded = false,
    this.loadError,
    this.sendError,
  });

  /// Ordered oldest → newest, server lines then local pending/failed ones.
  final List<ChatLine> lines;
  final bool loading;

  /// True once the first REST snapshot arrived (empty state vs spinner).
  final bool loaded;
  final Object? loadError;

  /// Only for errors that are not a per-message failure (no session).
  final Object? sendError;

  bool get sending => lines.any((l) => l.delivery == ChatDelivery.sending);

  ChatState copyWith({
    List<ChatLine>? lines,
    bool? loading,
    bool? loaded,
    Object? loadError = _unset,
    Object? sendError = _unset,
  }) {
    return ChatState(
      lines: lines ?? this.lines,
      loading: loading ?? this.loading,
      loaded: loaded ?? this.loaded,
      loadError: identical(loadError, _unset) ? this.loadError : loadError,
      sendError: identical(sendError, _unset) ? this.sendError : sendError,
    );
  }
}

const Object _unset = Object();

/// Transaction chat for one ride / food order.
///
/// REST page 1 (newest 50) is the snapshot on open and after a socket
/// reconnect; new messages arrive live on `chatMessage` (private user room) and
/// are merged by id, so reconnect/replay never duplicates. Sends are optimistic:
/// sending → sent, or failed with retry.
class ChatCubit extends Cubit<ChatState> {
  ChatCubit({
    required this._listRideChatMessages,
    required this._sendRideChatMessage,
    required this._listFoodOrderChatMessages,
    required this._sendFoodOrderChatMessage,
    required this.kind,
    required this.resourceId,
    this.currentUserId,
    this._realtime,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now,
       super(const ChatState());

  final ListRideChatMessages _listRideChatMessages;
  final SendRideChatMessage _sendRideChatMessage;
  final ListFoodOrderChatMessages _listFoodOrderChatMessages;
  final SendFoodOrderChatMessage _sendFoodOrderChatMessage;
  final ChatThreadKind kind;
  final String resourceId;
  final String? currentUserId;
  final SnapshotRealtime? _realtime;
  final DateTime Function() _clock;

  /// Server messages by id (dedupe across REST, realtime and POST replies).
  final _server = <String, ChatMessageView>{};

  /// Local lines not yet confirmed (sending or failed), in send order.
  final _pending = <ChatLine>[];
  StreamSubscription<ChatMessageHint>? _messagesSub;
  StreamSubscription<void>? _reconnectSub;
  String? _token;
  var _loadGeneration = 0;
  var _seq = 0;

  /// Loads the snapshot and follows live messages until [close].
  Future<void> start({required String? accessToken}) {
    final realtime = _realtime;
    if (realtime != null && _messagesSub == null) {
      _messagesSub = realtime.chatMessages.listen(_onHint);
      _reconnectSub = realtime.reconnects.listen((_) {
        unawaited(load(accessToken: _token, silent: true));
      });
    }
    return load(accessToken: accessToken);
  }

  Future<void> load({required String? accessToken, bool silent = false}) async {
    final generation = ++_loadGeneration;
    final token = accessToken?.trim() ?? '';
    if (token.isEmpty) {
      emit(state.copyWith(loading: false, loadError: _unauthorized));
      return;
    }
    _token = token;
    if (!silent) {
      emit(state.copyWith(loading: true, loadError: null));
    }
    try {
      final page = switch (kind) {
        ChatThreadKind.ride => await _listRideChatMessages(
          ListRideChatMessagesParams(accessToken: token, rideId: resourceId),
        ),
        ChatThreadKind.foodOrder ||
        ChatThreadKind.foodOrderShop => await _listFoodOrderChatMessages(
          ListFoodOrderChatMessagesParams(
            accessToken: token,
            orderId: resourceId,
            shop: kind == ChatThreadKind.foodOrderShop,
          ),
        ),
      };
      if (isClosed || generation != _loadGeneration) {
        return;
      }
      for (final message in page.items) {
        _server[message.id] = message;
      }
      _emitLines(loading: false, loaded: true, loadError: null);
    } catch (error) {
      if (isClosed || generation != _loadGeneration) {
        return;
      }
      if (silent && state.loaded) {
        return;
      }
      emit(state.copyWith(loading: false, loadError: error));
    }
  }

  void _onHint(ChatMessageHint hint) {
    if (isClosed ||
        hint.aggregateType != kind.aggregateType ||
        hint.aggregateId != resourceId) {
      return;
    }
    final message = ChatMessageView(
      id: hint.id,
      threadId: hint.threadId,
      senderUserId: hint.senderUserId,
      body: hint.body,
      createdAt: hint.createdAt,
    );
    _acceptServer(message);
    _emitLines();
  }

  /// Adds a server message; when it is our own echo (push raced the POST
  /// reply) the matching in-flight line is dropped so it never shows twice.
  void _acceptServer(ChatMessageView message) {
    final isNew = !_server.containsKey(message.id);
    _server[message.id] = message;
    if (isNew &&
        currentUserId != null &&
        message.senderUserId == currentUserId) {
      final echo = _pending.indexWhere(
        (l) => l.delivery == ChatDelivery.sending && l.body == message.body,
      );
      if (echo >= 0) {
        _pending.removeAt(echo);
      }
    }
  }

  Future<void> send({
    required String? accessToken,
    required String body,
  }) async {
    final trimmed = body.trim();
    if (trimmed.isEmpty) {
      return;
    }
    final token = accessToken?.trim() ?? '';
    if (token.isEmpty) {
      emit(state.copyWith(sendError: _unauthorized));
      return;
    }
    _token = token;
    final clientId = 'c${++_seq}';
    _pending.add(
      ChatLine(
        key: 'local:$clientId',
        senderUserId: currentUserId ?? '',
        body: trimmed,
        at: _clock().toLocal(),
        delivery: ChatDelivery.sending,
        clientId: clientId,
      ),
    );
    _emitLines(sendError: null);
    await _deliver(clientId, token);
  }

  /// Re-sends a failed line in place.
  Future<void> retry(String clientId, {required String? accessToken}) async {
    final index = _pending.indexWhere((l) => l.clientId == clientId);
    final token = accessToken?.trim() ?? _token ?? '';
    if (index < 0 || token.isEmpty) {
      return;
    }
    final line = _pending[index];
    _pending[index] = ChatLine(
      key: line.key,
      senderUserId: line.senderUserId,
      body: line.body,
      at: line.at,
      delivery: ChatDelivery.sending,
      clientId: clientId,
    );
    _emitLines();
    await _deliver(clientId, token);
  }

  void discard(String clientId) {
    _pending.removeWhere((l) => l.clientId == clientId);
    _emitLines();
  }

  Future<void> _deliver(String clientId, String token) async {
    final line = _pending.firstWhere((l) => l.clientId == clientId);
    try {
      final message = switch (kind) {
        ChatThreadKind.ride => await _sendRideChatMessage(
          SendRideChatMessageParams(
            accessToken: token,
            rideId: resourceId,
            body: line.body,
          ),
        ),
        ChatThreadKind.foodOrder ||
        ChatThreadKind.foodOrderShop => await _sendFoodOrderChatMessage(
          SendFoodOrderChatMessageParams(
            accessToken: token,
            orderId: resourceId,
            body: line.body,
            shop: kind == ChatThreadKind.foodOrderShop,
          ),
        ),
      };
      if (isClosed) {
        return;
      }
      _pending.removeWhere((l) => l.clientId == clientId);
      _server[message.id] = message;
      _emitLines();
    } catch (_) {
      if (isClosed) {
        return;
      }
      final index = _pending.indexWhere((l) => l.clientId == clientId);
      if (index >= 0) {
        _pending[index] = ChatLine(
          key: line.key,
          senderUserId: line.senderUserId,
          body: line.body,
          at: line.at,
          delivery: ChatDelivery.failed,
          clientId: clientId,
        );
      }
      _emitLines();
    }
  }

  void _emitLines({
    bool? loading,
    bool? loaded,
    Object? loadError = _unset,
    Object? sendError = _unset,
  }) {
    final server = _server.values.toList()
      ..sort((a, b) {
        final byTime = a.createdAt.compareTo(b.createdAt);
        return byTime != 0 ? byTime : a.id.compareTo(b.id);
      });
    final lines = <ChatLine>[
      for (final m in server)
        ChatLine(
          key: m.id,
          senderUserId: m.senderUserId,
          body: m.body,
          at: m.createdAt.toLocal(),
        ),
      ..._pending,
    ];
    emit(
      state.copyWith(
        lines: List.unmodifiable(lines),
        loading: loading,
        loaded: loaded,
        loadError: loadError,
        sendError: sendError,
      ),
    );
  }

  void clearSendError() {
    if (state.sendError == null) {
      return;
    }
    emit(state.copyWith(sendError: null));
  }

  @override
  Future<void> close() async {
    await _messagesSub?.cancel();
    await _reconnectSub?.cancel();
    return super.close();
  }
}
