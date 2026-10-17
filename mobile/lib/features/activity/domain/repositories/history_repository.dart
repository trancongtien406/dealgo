import '../entities/history_models.dart';

abstract interface class HistoryRepository {
  Future<List<HistoryItem>> listRideHistory(String accessToken);

  Future<List<HistoryItem>> listFoodHistory(String accessToken);
}
