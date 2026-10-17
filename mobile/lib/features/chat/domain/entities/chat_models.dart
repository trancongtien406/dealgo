class ChatMessageView {
  const ChatMessageView({
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
}

class ChatMessagePage {
  const ChatMessagePage({
    required this.items,
    required this.page,
    required this.limit,
    required this.total,
  });

  final List<ChatMessageView> items;
  final int page;
  final int limit;
  final int total;
}
