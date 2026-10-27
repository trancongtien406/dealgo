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

/// One commission payment recorded by Ops.
class MerchantSettlement {
  const MerchantSettlement({
    required this.periodStart,
    required this.periodEnd,
    required this.commissionVnd,
    required this.createdAt,
  });

  /// `yyyy-MM-dd` Vietnam days, inclusive.
  final String periodStart;
  final String periodEnd;
  final int commissionVnd;
  final DateTime? createdAt;
}

/// Cash the store received from drivers at pickup and the DealGo commission it
/// owes for a Vietnam-day range (GrabFood / ShopeeFood merchant statement).
class MerchantStatement {
  const MerchantStatement({
    required this.from,
    required this.to,
    required this.commissionPercentNow,
    required this.orderCount,
    required this.cashReceivedVnd,
    required this.commissionVnd,
    required this.netVnd,
    required this.unsettledCommissionVnd,
    required this.settlements,
    this.settlementCycleDays = 0,
  });

  final String from;
  final String to;
  final num commissionPercentNow;
  final int orderCount;
  final int cashReceivedVnd;
  final int commissionVnd;

  /// What the store keeps after commission.
  final int netVnd;

  /// Commission in this range not yet covered by a recorded payment.
  final int unsettledCommissionVnd;
  final List<MerchantSettlement> settlements;

  /// MERCHANT_SETTLEMENT_CYCLE_DAYS (0 when an older backend omits it).
  final int settlementCycleDays;
}

abstract interface class MerchantStatsRepository {
  Future<MerchantStats> stats({required String accessToken, int days = 7});

  /// Commission statement; `from`/`to` are `yyyy-MM-dd` (ICT).
  Future<MerchantStatement> statement({
    required String accessToken,
    String? from,
    String? to,
  });
}
