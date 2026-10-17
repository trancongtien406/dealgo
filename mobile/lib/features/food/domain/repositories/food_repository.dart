import '../entities/food_models.dart';
import '../params/place_food_order_params.dart';

abstract interface class FoodRepository {
  Future<List<FoodStoreSummary>> listStores(String accessToken);

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

  Future<MerchantOrderUpdate> markOrderReady({
    required String accessToken,
    required String orderId,
  });

  Future<ClaimedFoodDelivery> claimOrder({
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
  });

  Future<FoodMenuItem> setMerchantItemAvailability({
    required String accessToken,
    required String itemId,
    required bool available,
  });
}
