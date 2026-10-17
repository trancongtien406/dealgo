import '../../features/food/domain/entities/food_models.dart';

class MerchantKitchenLine {
  const MerchantKitchenLine({
    required this.name,
    required this.qty,
    required this.unitPriceVnd,
    required this.kitchen,
  });

  final String name;
  final int qty;
  final int unitPriceVnd;
  final String kitchen;
}

/// Builds kitchen display lines from an order detail (DTO / fake client).
List<MerchantKitchenLine> kitchenLinesFromDetail(FoodOrderDetail detail) {
  final lines = detail.lines;
  if (lines.isEmpty) {
    return const [];
  }
  return [
    for (var i = 0; i < lines.length; i++)
      MerchantKitchenLine(
        name: lines[i].name,
        qty: lines[i].quantity,
        unitPriceVnd: lines[i].unitPriceVnd,
        kitchen: i == 0 ? 'Đã xong' : 'Đang làm',
      ),
  ];
}

/// Seeded kitchen lines when only queue summary fields are available (mock).
List<FoodOrderLine> mockOrderLinesForQueue(MerchantQueueOrder order) {
  if (order.lineCount <= 1) {
    return [
      FoodOrderLine(
        itemId: 'line-1',
        name: 'Bún bò đặc biệt',
        unitPriceVnd: order.subtotalVnd,
        quantity: 1,
      ),
    ];
  }
  final first = (order.subtotalVnd * 0.48).round();
  final second = (order.subtotalVnd * 0.32).round();
  final third = order.subtotalVnd - first - second;
  return [
    FoodOrderLine(
      itemId: 'line-1',
      name: 'Bún bò đặc biệt',
      unitPriceVnd: first,
      quantity: 1,
    ),
    FoodOrderLine(
      itemId: 'line-2',
      name: 'Bún bò thường',
      unitPriceVnd: second,
      quantity: 1,
    ),
    if (third > 0)
      FoodOrderLine(
        itemId: 'line-3',
        name: 'Trà tắc',
        unitPriceVnd: third,
        quantity: 1,
      ),
  ];
}
