import '../../domain/entities/food_models.dart';
import '../../domain/params/place_food_order_params.dart';

export '../../domain/params/place_food_order_params.dart';

abstract interface class FoodRemoteDataSource {
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

  Future<List<FoodStoreSummary>> listStores(String accessToken);

  Future<FoodStoreDetail> getStore(String accessToken, String storeId);

  /// Owner-scoped catalog (`GET /v1/food/merchant/catalog`).
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

  Future<PlacedFoodOrder> placeOrder(PlaceFoodOrderParams request);

  Future<FoodOrderDetail> getOrder({
    required String accessToken,
    required String orderId,
  });
}

/// Backward-compatible alias used by mocks, tests, and DI overrides.
typedef FoodClient = FoodRemoteDataSource;
