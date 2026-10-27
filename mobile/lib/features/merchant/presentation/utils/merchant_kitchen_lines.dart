import '../../../food/domain/entities/food_models.dart';

/// One kitchen-ticket line built from the real order detail.
class MerchantKitchenLine {
  const MerchantKitchenLine({
    this.id,
    required this.name,
    required this.qty,
    required this.unitPriceVnd,
    this.options = '',
  });

  /// Server line id — needed to edit the order.
  final String? id;
  final String name;
  final int qty;
  final int unitPriceVnd;

  /// Chosen options for the cook, e.g. "Size: L · Topping: Trân châu" (DEC-PROD-033).
  final String options;
}

/// Builds kitchen display lines from an order detail returned by the API.
List<MerchantKitchenLine> kitchenLinesFromDetail(FoodOrderDetail detail) {
  final lines = detail.lines;
  if (lines.isEmpty) {
    return const [];
  }
  return [
    for (var i = 0; i < lines.length; i++)
      MerchantKitchenLine(
        id: lines[i].id,
        name: lines[i].name,
        qty: lines[i].quantity,
        unitPriceVnd: lines[i].unitPriceVnd,
        options: lines[i].optionsSummary,
      ),
  ];
}
