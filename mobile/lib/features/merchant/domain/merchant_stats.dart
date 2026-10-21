/// Sales figures for one Vietnam-time day (DEC-PROD-020).
class MerchantDayStats {
  const MerchantDayStats({
    required this.date,
    required this.deliveredCount,
    required this.cancelledCount,
    required this.salesVnd,
  });

  /// `yyyy-MM-dd` in Asia/Ho_Chi_Minh.
  final String date;
  final int deliveredCount;
  final int cancelledCount;

  /// Food subtotal of delivered orders (delivery fare excluded).
  final int salesVnd;
}

class MerchantTopItem {
  const MerchantTopItem({required this.name, required this.quantity});

  final String name;
  final int quantity;
}

class MerchantStats {
  const MerchantStats({
    required this.days,
    required this.today,
    required this.openCount,
    required this.totals,
    required this.series,
    required this.topItems,
  });

  final int days;
  final MerchantDayStats today;

  /// Orders currently placed/preparing/ready.
  final int openCount;
  final MerchantDayStats totals;
  final List<MerchantDayStats> series;
  final List<MerchantTopItem> topItems;
}

abstract interface class MerchantStatsRepository {
  Future<MerchantStats> stats({required String accessToken, int days = 7});
}
