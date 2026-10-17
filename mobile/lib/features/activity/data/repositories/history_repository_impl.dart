import '../../domain/entities/history_models.dart';
import '../../domain/repositories/history_repository.dart';
import '../datasources/history_remote_datasource.dart';

class HistoryRepositoryImpl implements HistoryRepository {
  HistoryRepositoryImpl(this._remote);

  final HistoryRemoteDataSource _remote;

  @override
  Future<List<HistoryItem>> listRideHistory(String accessToken) {
    return _remote.listRideHistory(accessToken);
  }

  @override
  Future<List<HistoryItem>> listFoodHistory(String accessToken) {
    return _remote.listFoodHistory(accessToken);
  }
}
