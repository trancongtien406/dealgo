import '../entities/history_models.dart';
import '../repositories/history_repository.dart';

class ListFoodHistory {
  const ListFoodHistory(this._repository);

  final HistoryRepository _repository;

  Future<List<HistoryItem>> call(String accessToken) {
    return _repository.listFoodHistory(accessToken);
  }
}
