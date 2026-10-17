import '../../../food/domain/entities/food_models.dart';

abstract interface class MerchantOrdersRepository {
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
