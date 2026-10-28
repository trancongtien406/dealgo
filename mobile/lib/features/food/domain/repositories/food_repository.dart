import '../entities/food_models.dart';
import '../params/place_food_order_params.dart';

abstract interface class FoodRepository {
  Future<List<FoodStoreSummary>> listStores(
    String accessToken, {
    double? lat,
    double? lng,
    String? search,
  });

  Future<FoodStoreDetail> getStore(String accessToken, String storeId);

  Future<PlacedFoodOrder> placeOrder(PlaceFoodOrderParams request);

  Future<FoodOrderDetail> getOrder({
    required String accessToken,
    required String orderId,
  });

  Future<List<ReadyFoodJob>> listReadyOrders(String accessToken);

  Future<List<MerchantQueueOrder>> listOrderQueue(String accessToken);

  Future<MerchantOrderUpdate> acceptOrder({
    required String accessToken,
    required String orderId,
  });

  Future<MerchantOrderUpdate> rejectOrder({
    required String accessToken,
    required String orderId,
    required FoodRejectReason reason,
    String? note,
  });

  Future<MerchantOrderUpdate> markOrderReady({
    required String accessToken,
    required String orderId,
  });

  Future<ClaimedFoodDelivery> claimOrder({
    required String accessToken,
    required String orderId,
  });

  /// Customer cancel (backend allows PLACED only).
  Future<ClaimedFoodDelivery> cancelOrder({
    required String accessToken,
    required String orderId,
  });

  Future<FoodStoreDetail> getMerchantCatalog(String accessToken);

  Future<FoodMenuItem> createMerchantItem({
    required String accessToken,
    required String name,
    required int priceVnd,
    bool? available,
  });

  Future<FoodMenuItem> updateMerchantItem({
    required String accessToken,
    required String itemId,
    String? name,
    int? priceVnd,
    bool? available,
    String? description,
    int? prepMinutes,
    String? imageUrl,
    String? menuCategoryId,
    int? originalPriceVnd,
    bool clearOriginalPrice = false,
  });

  Future<FoodMenuItem> replaceMerchantItemOptions({
    required String accessToken,
    required String itemId,
    required List<FoodOptionGroup> groups,
  });

  Future<FoodMenuItem> setMerchantItemAvailability({
    required String accessToken,
    required String itemId,
    required bool available,
  });
}
