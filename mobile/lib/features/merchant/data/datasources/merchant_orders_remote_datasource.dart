import '../../../food/domain/entities/food_models.dart';

/// Merchant kitchen queue + owner-scoped catalog. Presentation depends on this, not Dio.
abstract interface class MerchantOrdersRemoteDataSource {
  Future<List<MerchantQueueOrder>> listOrderQueue(String accessToken);

  Future<MerchantOrderUpdate> acceptOrder({
    required String accessToken,
    required String orderId,
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
  });

  Future<FoodMenuItem> setItemAvailability({
    required String accessToken,
    required String itemId,
    required bool available,
  });
}

/// Backward-compatible alias used by mocks, tests, and DI overrides.
typedef MerchantOrdersClient = MerchantOrdersRemoteDataSource;
