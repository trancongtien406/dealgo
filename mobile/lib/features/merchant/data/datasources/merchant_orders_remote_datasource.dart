import '../../../food/domain/entities/food_models.dart';
import '../../domain/entities/merchant_menu_models.dart';

/// Merchant kitchen queue + owner-scoped catalog. Presentation depends on this, not Dio.
abstract interface class MerchantOrdersRemoteDataSource {
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

  Future<FoodOrderDetail> getOrder({
    required String accessToken,
    required String orderId,
  });

  Future<FoodStoreDetail> getMerchantCatalog(String accessToken);

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

  Future<FoodMenuItem> createCatalogItem({
    required String accessToken,
    required String name,
    required int priceVnd,
    bool? available,
  });

  Future<FoodMenuItem> updateCatalogItem({
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

  Future<FoodMenuItem> replaceItemOptions({
    required String accessToken,
    required String itemId,
    required List<FoodOptionGroup> groups,
  });

  Future<FoodMenuItem> setItemAvailability({
    required String accessToken,
    required String itemId,
    required bool available,
  });

  Future<List<MerchantMenuCategory>> listMenuCategories(String accessToken);

  Future<MerchantMenuCategory> createMenuCategory({
    required String accessToken,
    required String name,
    String? description,
  });

  Future<MerchantMenuCategory> updateMenuCategory({
    required String accessToken,
    required String categoryId,
    required String name,
    String? description,
  });

  Future<void> deleteMenuCategory({
    required String accessToken,
    required String categoryId,
  });

  Future<MerchantHistoryPage> listOrderHistory({
    required String accessToken,
    int page = 1,
    int limit = 20,
    String? tab,
    String? q,
  });

  Future<List<MerchantMenuCategory>> reorderMenuCategories({
    required String accessToken,
    required List<String> orderedIds,
  });

  Future<FoodMenuItem> uploadItemImage({
    required String accessToken,
    required String itemId,
    required String contentBase64,
    String? contentType,
  });

  Future<FoodMenuItem> clearItemImage({
    required String accessToken,
    required String itemId,
  });
}

/// Backward-compatible alias used by mocks, tests, and DI overrides.
typedef MerchantOrdersClient = MerchantOrdersRemoteDataSource;
