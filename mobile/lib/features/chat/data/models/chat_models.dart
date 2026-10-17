import '../../../../core/network/api_exception.dart';
import '../../domain/entities/chat_models.dart';

class ChatMessageModel {
  const ChatMessageModel({
    required this.id,
    required this.threadId,
    required this.senderUserId,
    required this.body,
    required this.createdAt,
  });

  final String id;
  final String threadId;
  final String senderUserId;
  final String body;
  final DateTime createdAt;

  factory ChatMessageModel.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final threadId = json['threadId'];
    final senderUserId = json['senderUserId'];
    final body = json['body'];
    final createdAt = json['createdAt'];
    if (id is! String ||
        threadId is! String ||
        senderUserId is! String ||
        body is! String ||
        createdAt is! String) {
      throw const ApiException(
        statusCode: 500,
        message: 'Invalid chat message payload',
        errorCode: 'INVALID_RESPONSE',
      );
    }
    final parsedAt = DateTime.tryParse(createdAt);
    if (parsedAt == null) {
      throw const ApiException(
        statusCode: 500,
        message: 'Invalid chat message timestamp',
        errorCode: 'INVALID_RESPONSE',
      );
    }
    return ChatMessageModel(
      id: id,
      threadId: threadId,
      senderUserId: senderUserId,
      body: body,
      createdAt: parsedAt,
    );
  }

  factory ChatMessageModel.fromEntity(ChatMessageView message) {
    return ChatMessageModel(
      id: message.id,
      threadId: message.threadId,
      senderUserId: message.senderUserId,
      body: message.body,
      createdAt: message.createdAt,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'threadId': threadId,
      'senderUserId': senderUserId,
      'body': body,
      'createdAt': createdAt.toUtc().toIso8601String(),
    };
  }

  ChatMessageView toEntity() {
    return ChatMessageView(
      id: id,
      threadId: threadId,
      senderUserId: senderUserId,
      body: body,
      createdAt: createdAt,
    );
  }
}

class ChatMessagePageModel {
  const ChatMessagePageModel({
    required this.items,
    required this.page,
    required this.limit,
    required this.total,
  });

  final List<ChatMessageModel> items;
  final int page;
  final int limit;
  final int total;

  factory ChatMessagePageModel.fromEntity(ChatMessagePage page) {
    return ChatMessagePageModel(
      items: [for (final item in page.items) ChatMessageModel.fromEntity(item)],
      page: page.page,
      limit: page.limit,
      total: page.total,
    );
  }

  ChatMessagePage toEntity() {
    return ChatMessagePage(
      items: List.unmodifiable([for (final item in items) item.toEntity()]),
      page: page,
      limit: limit,
      total: total,
    );
  }
}
