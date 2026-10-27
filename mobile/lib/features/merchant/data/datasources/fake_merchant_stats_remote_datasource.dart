import '../../domain/merchant_stats.dart';

/// Empty stats for tests and offline mock mode (no invented sales figures).
class FakeMerchantStatsRemoteDataSource implements MerchantStatsRepository {
  FakeMerchantStatsRemoteDataSource({
    this.result,
    this.error,
    this.statementResult,
    this.statementError,
  });

  MerchantStats? result;
  MerchantStatement? statementResult;
  Object? statementError;
  final statementCalls = <(String?, String?)>[];
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

  @override
  Future<MerchantStatement> statement({
    required String accessToken,
    String? from,
    String? to,
  }) async {
    statementCalls.add((from, to));
    final failure = statementError;
    if (failure != null) {
      throw failure;
    }
    return statementResult ??
        MerchantStatement(
          from: from ?? '',
          to: to ?? '',
          commissionPercentNow: 0,
          orderCount: 0,
          cashReceivedVnd: 0,
          commissionVnd: 0,
          netVnd: 0,
          unsettledCommissionVnd: 0,
          settlements: const [],
          settlementCycleDays: 7,
        );
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
