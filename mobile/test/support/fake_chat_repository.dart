import 'dart:async';

import 'package:dealgo/features/chat/domain/entities/chat_models.dart';
import 'package:dealgo/features/chat/domain/repositories/chat_repository.dart';
import 'package:dealgo/features/chat/domain/usecases/list_food_order_chat_messages.dart';
import 'package:dealgo/features/chat/domain/usecases/list_ride_chat_messages.dart';
import 'package:dealgo/features/chat/domain/usecases/send_food_order_chat_message.dart';
import 'package:dealgo/features/chat/domain/usecases/send_ride_chat_message.dart';
import 'package:dealgo/features/driver_card/domain/driver_card.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

ChatMessageView chatMessage(
  String id,
  String sender,
  String body,
  DateTime at, {
  String threadId = 't1',
}) => ChatMessageView(
  id: id,
  threadId: threadId,
  senderUserId: sender,
  body: body,
  createdAt: at,
);

/// In-memory chat backend for cubit / sheet tests and previews.
class FakeChatRepository implements ChatRepository {
  FakeChatRepository({List<ChatMessageView>? messages, this.senderId = 'me'})
    : messages = messages ?? [];

  final List<ChatMessageView> messages;
  final String senderId;
  int listCalls = 0;
  final posted = <String>[];

  /// Bodies whose POST fails (once each unless [failAlways]).
  final failBodies = <String>{};
  bool failAlways = false;

  /// Bodies whose POST never completes (preview of "sending").
  final hangBodies = <String>{};
  DateTime Function() clock = DateTime.now;
  var _seq = 0;

  ChatMessagePage _page() => ChatMessagePage(
    items: List.of(messages),
    page: 1,
    limit: 50,
    total: messages.length,
  );

  Future<ChatMessageView> _post(String body) async {
    posted.add(body);
    if (hangBodies.contains(body)) {
      return Completer<ChatMessageView>().future;
    }
    if (failBodies.contains(body)) {
      if (!failAlways) failBodies.remove(body);
      throw StateError('offline');
    }
    final m = chatMessage('srv-${++_seq}', senderId, body, clock().toUtc());
    messages.add(m);
    return m;
  }

  @override
  Future<ChatMessagePage> listRideMessages({
    required String accessToken,
    required String rideId,
    int page = 1,
    int limit = 50,
  }) async {
    listCalls += 1;
    return _page();
  }

  @override
  Future<ChatMessagePage> listFoodOrderMessages({
    required String accessToken,
    required String orderId,
    int page = 1,
    int limit = 50,
  }) async {
    listCalls += 1;
    return _page();
  }

  @override
  Future<ChatMessageView> postRideMessage({
    required String accessToken,
    required String rideId,
    required String body,
  }) => _post(body);

  @override
  Future<ChatMessageView> postFoodOrderMessage({
    required String accessToken,
    required String orderId,
    required String body,
  }) => _post(body);
}

class FakeDriverCards implements DriverCardRepository {
  FakeDriverCards({this.card, this.customerName = ''});

  final DriverCard? card;
  final String customerName;
  int calls = 0;

  @override
  Future<DriverCard> fetch({
    required String accessToken,
    required DriverCardJob job,
    required String jobId,
    String? offerId,
  }) async {
    calls += 1;
    return card ?? const DriverCard(driverId: 'd', displayName: '');
  }

  @override
  Future<String> fetchCustomerName({
    required String accessToken,
    required String jobId,
    bool isFood = false,
  }) async {
    calls += 1;
    return customerName;
  }
}

/// The four chat use cases over [repo], as the app's DI provides them.
Widget chatProviders(
  FakeChatRepository repo, {
  required Widget child,
  List<RepositoryProvider<Object>> extra = const [],
}) => MultiRepositoryProvider(
  providers: [
    RepositoryProvider.value(value: ListRideChatMessages(repo)),
    RepositoryProvider.value(value: SendRideChatMessage(repo)),
    RepositoryProvider.value(value: ListFoodOrderChatMessages(repo)),
    RepositoryProvider.value(value: SendFoodOrderChatMessage(repo)),
    ...extra,
  ],
  child: child,
);
