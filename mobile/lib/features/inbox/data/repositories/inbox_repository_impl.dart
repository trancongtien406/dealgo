import '../../domain/entities/inbox_notification.dart';
import '../../domain/repositories/inbox_repository.dart';
import '../datasources/inbox_remote_datasource.dart';

class InboxRepositoryImpl implements InboxRepository {
  InboxRepositoryImpl(this._remote);

  final InboxRemoteDataSource _remote;

  @override
  Future<InboxPage> list({
    required String accessToken,
    int page = 1,
    int limit = 30,
  }) {
    return _remote.list(accessToken: accessToken, page: page, limit: limit);
  }

  @override
  Future<void> markRead({required String accessToken, required String id}) {
    return _remote.markRead(accessToken: accessToken, id: id);
  }

  @override
  Future<int> markAllRead({required String accessToken}) {
    return _remote.markAllRead(accessToken: accessToken);
  }
}
