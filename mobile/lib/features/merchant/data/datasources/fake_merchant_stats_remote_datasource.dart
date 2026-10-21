import '../../domain/merchant_stats.dart';

/// Empty stats for tests and offline mock mode (no invented sales figures).
class FakeMerchantStatsRemoteDataSource implements MerchantStatsRepository {
  FakeMerchantStatsRemoteDataSource({this.result, this.error});

  MerchantStats? result;
  Object? error;
  final calls = <int>[];

  @override
  Future<MerchantStats> stats({
    required String accessToken,
    int days = 7,
  }) async {
    calls.add(days);
    final failure = error;
    if (failure != null) {
      throw failure;
    }
    return result ?? empty(days, DateTime.now());
  }

  static MerchantStats empty(int days, DateTime now) {
    final vn = now.toUtc().add(const Duration(hours: 7));
    String key(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final series = [
      for (var i = days - 1; i >= 0; i--)
        MerchantDayStats(
          date: key(vn.subtract(Duration(days: i))),
          deliveredCount: 0,
          cancelledCount: 0,
          salesVnd: 0,
        ),
    ];
    return MerchantStats(
      days: days,
      today: series.last,
      openCount: 0,
      totals: const MerchantDayStats(
        date: '',
        deliveredCount: 0,
        cancelledCount: 0,
        salesVnd: 0,
      ),
      series: series,
      topItems: const [],
    );
  }
}
