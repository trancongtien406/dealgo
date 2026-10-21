import '../entities/inbox_notification.dart';
import '../repositories/inbox_repository.dart';

class ListInboxNotifications {
  const ListInboxNotifications(this._repository);

  final InboxRepository _repository;

  Future<InboxPage> call({
    required String accessToken,
    int page = 1,
    int limit = 30,
  }) {
    return _repository.list(accessToken: accessToken, page: page, limit: limit);
  }
}

class MarkInboxNotificationRead {
  const MarkInboxNotificationRead(this._repository);

  final InboxRepository _repository;

  Future<void> call({required String accessToken, required String id}) {
    return _repository.markRead(accessToken: accessToken, id: id);
  }
}

class MarkAllInboxNotificationsRead {
  const MarkAllInboxNotificationsRead(this._repository);

  final InboxRepository _repository;

  Future<int> call({required String accessToken}) {
    return _repository.markAllRead(accessToken: accessToken);
  }
}
