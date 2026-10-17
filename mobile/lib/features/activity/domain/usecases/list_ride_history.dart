import '../entities/history_models.dart';
import '../repositories/history_repository.dart';

class ListRideHistory {
  const ListRideHistory(this._repository);

  final HistoryRepository _repository;

  Future<List<HistoryItem>> call(String accessToken) {
    return _repository.listRideHistory(accessToken);
  }
}
