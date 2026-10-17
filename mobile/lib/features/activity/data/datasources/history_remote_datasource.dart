import '../../domain/entities/history_models.dart';

abstract interface class HistoryRemoteDataSource {
  Future<List<HistoryItem>> listRideHistory(String accessToken);

  Future<List<HistoryItem>> listFoodHistory(String accessToken);
}

/// Backward-compatible alias used by mocks, tests, and DI overrides.
typedef HistoryClient = HistoryRemoteDataSource;
