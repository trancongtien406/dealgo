import '../entities/food_models.dart';

class FoodOrderItem {
  const FoodOrderItem({required this.itemId, required this.quantity});

  final String itemId;
  final int quantity;
}

class PlaceFoodOrderParams {
  const PlaceFoodOrderParams({
    required this.accessToken,
    required this.idempotencyKey,
    required this.storeId,
    required this.items,
    required this.dropoff,
    required this.deliveryFareVnd,
  });

  final String accessToken;
  final String idempotencyKey;
  final String storeId;
  final List<FoodOrderItem> items;
  final FoodDropoff dropoff;
  final int deliveryFareVnd;
}

/// Backward-compatible alias for existing tests and call sites.
typedef PlaceFoodRequest = PlaceFoodOrderParams;
