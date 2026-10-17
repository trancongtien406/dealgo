import '../../domain/entities/food_models.dart';
import '../../domain/repositories/food_repository.dart';
import '../datasources/food_remote_datasource.dart';

class FoodRepositoryImpl implements FoodRepository {
  FoodRepositoryImpl(this._remote);

  final FoodRemoteDataSource _remote;

  @override
  Future<List<FoodStoreSummary>> listStores(String accessToken) {
    return _remote.listStores(accessToken);
  }

  @override
  Future<FoodStoreDetail> getStore(String accessToken, String storeId) {
    return _remote.getStore(accessToken, storeId);
  }

  @override
  Future<PlacedFoodOrder> placeOrder(PlaceFoodOrderParams request) {
    return _remote.placeOrder(request);
  }

  @override
  Future<FoodOrderDetail> getOrder({
    required String accessToken,
    required String orderId,
  }) {
    return _remote.getOrder(accessToken: accessToken, orderId: orderId);
  }

  @override
  Future<List<ReadyFoodJob>> listReadyOrders(String accessToken) {
    return _remote.listReadyOrders(accessToken);
  }

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
  Future<ClaimedFoodDelivery> claimOrder({
    required String accessToken,
    required String orderId,
  }) {
    return _remote.claimOrder(accessToken: accessToken, orderId: orderId);
  }

  @override
  Future<FoodStoreDetail> getMerchantCatalog(String accessToken) {
    return _remote.getMerchantCatalog(accessToken);
  }

  @override
  Future<FoodMenuItem> createMerchantItem({
    required String accessToken,
    required String name,
    required int priceVnd,
    bool? available,
  }) {
    return _remote.createMerchantItem(
      accessToken: accessToken,
      name: name,
      priceVnd: priceVnd,
      available: available,
    );
  }

  @override
  Future<FoodMenuItem> updateMerchantItem({
    required String accessToken,
    required String itemId,
    String? name,
    int? priceVnd,
  }) {
    return _remote.updateMerchantItem(
      accessToken: accessToken,
      itemId: itemId,
      name: name,
      priceVnd: priceVnd,
    );
  }

  @override
  Future<FoodMenuItem> setMerchantItemAvailability({
    required String accessToken,
    required String itemId,
    required bool available,
  }) {
    return _remote.setMerchantItemAvailability(
      accessToken: accessToken,
      itemId: itemId,
      available: available,
    );
  }
}
