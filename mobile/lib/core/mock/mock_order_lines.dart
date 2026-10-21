import '../../features/food/domain/entities/food_models.dart';

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
