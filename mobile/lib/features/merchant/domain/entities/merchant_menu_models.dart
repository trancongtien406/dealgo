/// M025 store menu category (DEC-PROD-039).
class MerchantMenuCategory {
  const MerchantMenuCategory({
    required this.id,
    required this.name,
    this.description,
    required this.position,
    this.itemCount = 0,
  });

  final String id;
  final String name;
  final String? description;
  final int position;
  final int itemCount;
}

/// M020 finished order row for the merchant history list.
class MerchantHistoryOrder {
  const MerchantHistoryOrder({
    required this.id,
    required this.status,
    required this.subtotalVnd,
    required this.totalVnd,
    required this.createdAt,
    required this.finishedAt,
    this.customerName,
    required this.lineSummary,
  });

  final String id;
  final String status;
  final int subtotalVnd;
  final int totalVnd;
  final DateTime createdAt;
  final DateTime finishedAt;
  final String? customerName;
  final String lineSummary;
}

class MerchantHistoryPage {
  const MerchantHistoryPage({
    required this.items,
    required this.page,
    required this.limit,
    required this.total,
    required this.deliveredCount,
    required this.deliveredRevenueVnd,
  });

  final List<MerchantHistoryOrder> items;
  final int page;
  final int limit;
  final int total;
  final int deliveredCount;
  final int deliveredRevenueVnd;
}
