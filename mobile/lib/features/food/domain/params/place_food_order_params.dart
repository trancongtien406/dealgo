import '../entities/food_models.dart';

class FoodOrderItem {
  const FoodOrderItem({
    required this.itemId,
    required this.quantity,
    this.optionIds = const [],
  });

  final String itemId;
  final int quantity;

  /// DEC-PROD-033 — chosen option ids; the server validates and prices them.
  final List<String> optionIds;
}

class PlaceFoodOrderParams {
  const PlaceFoodOrderParams({
    required this.accessToken,
    required this.idempotencyKey,
    required this.storeId,
    required this.items,
    required this.dropoff,
    required this.deliveryFareVnd,
    this.deliveryOfferVnd,
    this.voucherCode,
    this.paymentMethod,
  });

  final String accessToken;
  final String idempotencyKey;
  final String storeId;
  final List<FoodOrderItem> items;
  final FoodDropoff dropoff;
  final int deliveryFareVnd;

  /// Customer's delivery-fee offer (suggestion by default); the server checks
  /// the bounds and drivers accept or counter it.
  final int? deliveryOfferVnd;

  /// Optional voucher; the server re-checks and redeems it with the order.
  final String? voucherCode;

  /// Payment method code (CASH, MOMO, …); the server re-checks availability.
  final String? paymentMethod;
}

/// Backward-compatible alias for existing tests and call sites.
typedef PlaceFoodRequest = PlaceFoodOrderParams;
