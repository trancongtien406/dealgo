import '../../../food/domain/entities/food_models.dart';
import '../../domain/repositories/merchant_orders_repository.dart';
import '../datasources/merchant_orders_remote_datasource.dart';

class MerchantOrdersRepositoryImpl implements MerchantOrdersRepository {
  MerchantOrdersRepositoryImpl(this._remote);

  final MerchantOrdersRemoteDataSource _remote;

  @override
  Future<List<MerchantQueueOrder>> listOrderQueue(String accessToken) {
    return _remote.listOrderQueue(accessToken);
  }

  @override
  Future<MerchantOrderUpdate> acceptOrder({
    required String accessToken,
    required String orderId,
  }) {
    return _remote.acceptOrder(accessToken: accessToken, orderId: orderId);
  }

  @override
  Future<MerchantOrderUpdate> markOrderReady({
    required String accessToken,
    required String orderId,
  }) {
    return _remote.markOrderReady(accessToken: accessToken, orderId: orderId);
  }

  @override
  Future<FoodOrderDetail> getOrder({
    required String accessToken,
    required String orderId,
  }) {
    return _remote.getOrder(accessToken: accessToken, orderId: orderId);
  }

  @override
  Future<FoodStoreDetail> getMerchantCatalog(String accessToken) {
    return _remote.getMerchantCatalog(accessToken);
  }

  @override
  Future<FoodMenuItem> createCatalogItem({
    required String accessToken,
    required String name,
    required int priceVnd,
    bool? available,
  }) {
    return _remote.createCatalogItem(
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
    return _remote.updateCatalogItem(
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
    return _remote.setItemAvailability(
      accessToken: accessToken,
      itemId: itemId,
      available: available,
    );
  }
}
