import '../entities/inbox_notification.dart';

abstract interface class InboxRepository {
  Future<InboxPage> list({
    required String accessToken,
    int page = 1,
    int limit = 30,
  });

  Future<void> markRead({required String accessToken, required String id});

  Future<int> markAllRead({required String accessToken});
}
