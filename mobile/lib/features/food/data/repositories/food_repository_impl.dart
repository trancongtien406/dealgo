import '../../domain/entities/food_models.dart';
import '../../domain/repositories/food_repository.dart';
import '../datasources/food_remote_datasource.dart';

class FoodRepositoryImpl implements FoodRepository {
  FoodRepositoryImpl(this._remote);

  final FoodRemoteDataSource _remote;

  @override
  Future<FoodStorePageResult> listStores(
    String accessToken, {
    double? lat,
    double? lng,
    String? search,
    String? sortBy,
    int? maxKm,
    String? category,
    int page = 1,
    int limit = 20,
  }) {
    return _remote.listStores(
      accessToken,
      lat: lat,
      lng: lng,
      search: search,
      sortBy: sortBy,
      maxKm: maxKm,
      category: category,
      page: page,
      limit: limit,
    );
  }

  @override
  Future<FoodSearchResult> searchFood(
    String accessToken, {
    required String q,
    double? lat,
    double? lng,
    String? sortBy,
    int page = 1,
    int limit = 20,
  }) {
    return _remote.searchFood(
      accessToken,
      q: q,
      lat: lat,
      lng: lng,
      sortBy: sortBy,
      page: page,
      limit: limit,
    );
  }

  @override
  Future<List<FoodFeaturedItem>> listStoreSuggestions(
    String accessToken,
    String storeId, {
    List<String> exclude = const [],
  }) {
    return _remote.listStoreSuggestions(accessToken, storeId, exclude: exclude);
  }

  @override
  Future<FoodStoreDetail> getStore(
    String accessToken,
    String storeId, {
    double? lat,
    double? lng,
  }) {
    return _remote.getStore(accessToken, storeId, lat: lat, lng: lng);
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
  Future<MerchantOrderUpdate> rejectOrder({
    required String accessToken,
    required String orderId,
    required FoodRejectReason reason,
    String? note,
  }) {
    return _remote.rejectOrder(
      accessToken: accessToken,
      orderId: orderId,
      reason: reason,
      note: note,
    );
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
  Future<ClaimedFoodDelivery> cancelOrder({
    required String accessToken,
    required String orderId,
  }) {
    return _remote.cancelOrder(accessToken: accessToken, orderId: orderId);
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
    bool? available,
    String? description,
    int? prepMinutes,
    String? imageUrl,
    String? menuCategoryId,
    int? originalPriceVnd,
    bool clearOriginalPrice = false,
  }) {
    return _remote.updateMerchantItem(
      accessToken: accessToken,
      itemId: itemId,
      name: name,
      priceVnd: priceVnd,
      available: available,
      description: description,
      prepMinutes: prepMinutes,
      imageUrl: imageUrl,
      menuCategoryId: menuCategoryId,
      originalPriceVnd: originalPriceVnd,
      clearOriginalPrice: clearOriginalPrice,
    );
  }

  @override
  Future<FoodMenuItem> replaceMerchantItemOptions({
    required String accessToken,
    required String itemId,
    required List<FoodOptionGroup> groups,
  }) {
    return _remote.replaceMerchantItemOptions(
      accessToken: accessToken,
      itemId: itemId,
      groups: groups,
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
