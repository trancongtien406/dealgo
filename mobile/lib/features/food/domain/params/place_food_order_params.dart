import '../entities/food_models.dart';

class FoodOrderItem {
  const FoodOrderItem({
    required this.itemId,
    required this.quantity,
    this.optionIds = const [],
    this.note,
  });

  final String itemId;
  final int quantity;

  /// DEC-PROD-033 — chosen option ids; the server validates and prices them.
  final List<String> optionIds;

  /// Customer note for this line (≤200); blank is not sent.
  final String? note;
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
    this.note,
    this.utensils = true,
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

  /// Customer note to the store and driver (≤300); blank is not sent.
  final String? note;

  /// Cutlery request; always sent, true when the customer did not choose.
  final bool utensils;
}

/// Backward-compatible alias for existing tests and call sites.
typedef PlaceFoodRequest = PlaceFoodOrderParams;
