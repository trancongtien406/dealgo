enum InboxCategory {
  ride('RIDE'),
  food('FOOD'),
  promotion('PROMOTION'),
  system('SYSTEM');

  const InboxCategory(this.wire);

  final String wire;

  static InboxCategory fromWire(Object? value) {
    return InboxCategory.values.firstWhere(
      (category) => category.wire == value,
      orElse: () => InboxCategory.system,
    );
  }
}

class InboxNotification {
  const InboxNotification({
    required this.id,
    required this.category,
    required this.title,
    required this.body,
    required this.read,
    required this.createdAt,
    this.aggregateType,
    this.aggregateId,
    this.status,
    this.path,
    this.role,
  });

  final String id;
  final InboxCategory category;

  /// Server copy (Vietnamese). The app prefers its own text when [status] is known.
  final String title;
  final String body;
  final bool read;
  final DateTime createdAt;
  final String? aggregateType;
  final String? aggregateId;
  final String? status;

  /// In-app page the server named for this recipient (may be absent).
  final String? path;

  /// Recipient role the server wrote this row for (`CUSTOMER` / `DRIVER` /
  /// `MERCHANT`); absent on legacy rows.
  final String? role;

  InboxNotification markedRead() {
    return InboxNotification(
      id: id,
      category: category,
      title: title,
      body: body,
      read: true,
      createdAt: createdAt,
      aggregateType: aggregateType,
      aggregateId: aggregateId,
      status: status,
      path: path,
      role: role,
    );
  }
}

class InboxPage {
  const InboxPage({
    required this.items,
    required this.total,
    required this.unreadCount,
  });

  final List<InboxNotification> items;
  final int total;
  final int unreadCount;
}
