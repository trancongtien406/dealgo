import '../../../food/data/datasources/food_remote_datasource.dart';
import '../../../food/domain/entities/food_models.dart';
import 'merchant_orders_remote_datasource.dart';

class DefaultMerchantOrdersClient implements MerchantOrdersClient {
  DefaultMerchantOrdersClient({required this.food});

  final FoodClient food;

  @override
  Future<List<MerchantQueueOrder>> listOrderQueue(String accessToken) {
    return food.listOrderQueue(accessToken);
  }

  @override
  Future<MerchantOrderUpdate> acceptOrder({
    required String accessToken,
    required String orderId,
  }) {
    return food.acceptOrder(accessToken: accessToken, orderId: orderId);
  }

  @override
  Future<MerchantOrderUpdate> markOrderReady({
    required String accessToken,
    required String orderId,
  }) {
    return food.markOrderReady(accessToken: accessToken, orderId: orderId);
  }

  @override
  Future<FoodOrderDetail> getOrder({
    required String accessToken,
    required String orderId,
  }) {
    return food.getOrder(accessToken: accessToken, orderId: orderId);
  }

  @override
  Future<FoodStoreDetail> getMerchantCatalog(String accessToken) {
    return food.getMerchantCatalog(accessToken);
  }

  @override
  Future<FoodMenuItem> createCatalogItem({
    required String accessToken,
    required String name,
    required int priceVnd,
    bool? available,
  }) {
    return food.createMerchantItem(
      accessToken: accessToken,
      name: name,
      priceVnd: priceVnd,
      available: available,
    );
  }

  @override
  Future<FoodMenuItem> updateCatalogItem({
    required String accessToken,
    required String itemId,
    String? name,
    int? priceVnd,
  }) {
    return food.updateMerchantItem(
      accessToken: accessToken,
      itemId: itemId,
      name: name,
      priceVnd: priceVnd,
    );
  }

  @override
  Future<FoodMenuItem> setItemAvailability({
    required String accessToken,
    required String itemId,
    required bool available,
  }) {
    return food.setMerchantItemAvailability(
      accessToken: accessToken,
      itemId: itemId,
      available: available,
    );
  }
}
