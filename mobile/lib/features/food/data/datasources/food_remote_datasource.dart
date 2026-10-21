import '../../domain/entities/food_models.dart';
import '../../../merchant/domain/entities/merchant_menu_models.dart';
import '../../domain/params/food_delivery_action.dart';
import '../../domain/params/place_food_order_params.dart';

export '../../domain/params/food_delivery_action.dart';

export '../../domain/params/place_food_order_params.dart';

abstract interface class FoodRemoteDataSource {
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

  /// Driver pickup / deliver / fail. Returns the order's new `{id, status}`.
  Future<ClaimedFoodDelivery> advanceDelivery({
    required String accessToken,
    required String orderId,
    required FoodDeliveryAction action,
    /// DEC-PROD-036: handover code (pickup) or delivery code (deliver).
    String? code,
  });

  /// Customer cancel (PLACED only). Returns the order's new `{id, status}`.
  Future<ClaimedFoodDelivery> cancelOrder({
    required String accessToken,
    required String orderId,
  });

  Future<List<FoodStoreSummary>> listStores(
    String accessToken, {
    double? lat,
    double? lng,
  });

  Future<FoodStoreDetail> getStore(String accessToken, String storeId);

  /// Owner-scoped catalog (`GET /v1/food/merchant/catalog`).
  Future<FoodStoreDetail> getMerchantCatalog(String accessToken);

  /// M030 store pickup point (`PATCH /v1/food/merchant/store/location`).
  /// M030 (DEC-PROD-045): rename the store; upload / remove its logo.
  Future<FoodStoreDetail> updateStoreProfile({
    required String accessToken,
    required String name,
  });

  Future<FoodStoreDetail> uploadStoreLogo({
    required String accessToken,
    required String contentBase64,
    String? contentType,
  });

  Future<FoodStoreDetail> clearStoreLogo({required String accessToken});

  Future<FoodStoreDetail> updateStoreLocation({
    required String accessToken,
    required double lat,
    required double lng,
    String? addressLabel,
  });

  Future<FoodStoreDetail> updateStoreHours({
    required String accessToken,
    required StoreSchedule schedule,
  });

  Future<FoodStoreDetail> updateStoreServiceMode({
    required String accessToken,
    required StoreServiceMode mode,
    int? resumeAfterMinutes,
    int? busyExtraMinutes,
  });

  Future<FoodStoreDetail> updateStoreAcceptSettings({
    required String accessToken,
    required StoreAcceptSettings settings,
    required int lastOrderMinutes,
  });

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
  });

  /// DEC-PROD-033 — full replacement of a dish's option groups.
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


  Future<List<MerchantMenuCategory>> listMerchantMenuCategories(String accessToken);

  Future<MerchantMenuCategory> createMerchantMenuCategory({
    required String accessToken,
    required String name,
    String? description,
  });

  Future<MerchantMenuCategory> updateMerchantMenuCategory({
    required String accessToken,
    required String categoryId,
    required String name,
    String? description,
  });

  Future<void> deleteMerchantMenuCategory({
    required String accessToken,
    required String categoryId,
  });

  Future<MerchantHistoryPage> listMerchantOrderHistory({
    required String accessToken,
    int page = 1,
    int limit = 20,
    String? tab,
    String? q,
  });


  Future<List<MerchantMenuCategory>> reorderMerchantMenuCategories({
    required String accessToken,
    required List<String> orderedIds,
  });

  Future<FoodMenuItem> uploadMerchantItemImage({
    required String accessToken,
    required String itemId,
    required String contentBase64,
    String? contentType,
  });

  Future<FoodMenuItem> clearMerchantItemImage({
    required String accessToken,
    required String itemId,
  });

  Future<PlacedFoodOrder> placeOrder(PlaceFoodOrderParams request);

  Future<FoodOrderDetail> getOrder({
    required String accessToken,
    required String orderId,
  });
}

/// Backward-compatible alias used by mocks, tests, and DI overrides.
typedef FoodClient = FoodRemoteDataSource;
