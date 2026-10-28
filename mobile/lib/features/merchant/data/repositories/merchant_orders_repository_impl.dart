import '../../../food/domain/entities/food_models.dart';
import '../../domain/entities/merchant_menu_models.dart';
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
  Future<FoodStoreDetail> updateStoreProfile({
    required String accessToken,
    String? name,
    String? category,
    int? minOrderVnd,
    String? description,
  }) => _remote.updateStoreProfile(
    accessToken: accessToken,
    name: name,
    category: category,
    minOrderVnd: minOrderVnd,
    description: description,
  );

  @override
  Future<FoodStoreDetail> uploadStoreLogo({
    required String accessToken,
    required String contentBase64,
    String? contentType,
    bool cover = false,
  }) => _remote.uploadStoreLogo(
    accessToken: accessToken,
    contentBase64: contentBase64,
    contentType: contentType,
    cover: cover,
  );

  @override
  Future<FoodStoreDetail> clearStoreLogo({
    required String accessToken,
    bool cover = false,
  }) => _remote.clearStoreLogo(accessToken: accessToken, cover: cover);

  @override
  Future<FoodStoreDetail> updateStoreLocation({
    required String accessToken,
    required double lat,
    required double lng,
    String? addressLabel,
  }) {
    return _remote.updateStoreLocation(
      accessToken: accessToken,
      lat: lat,
      lng: lng,
      addressLabel: addressLabel,
    );
  }

  @override
  Future<FoodStoreDetail> updateStoreHours({
    required String accessToken,
    required StoreSchedule schedule,
  }) {
    return _remote.updateStoreHours(
      accessToken: accessToken,
      schedule: schedule,
    );
  }

  @override
  Future<FoodStoreDetail> updateStoreServiceMode({
    required String accessToken,
    required StoreServiceMode mode,
    int? resumeAfterMinutes,
    int? busyExtraMinutes,
  }) {
    return _remote.updateStoreServiceMode(
      accessToken: accessToken,
      mode: mode,
      resumeAfterMinutes: resumeAfterMinutes,
      busyExtraMinutes: busyExtraMinutes,
    );
  }

  @override
  Future<FoodStoreDetail> updateStoreAcceptSettings({
    required String accessToken,
    required StoreAcceptSettings settings,
    required int lastOrderMinutes,
  }) {
    return _remote.updateStoreAcceptSettings(
      accessToken: accessToken,
      settings: settings,
      lastOrderMinutes: lastOrderMinutes,
    );
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
    bool? available,
    String? description,
    int? prepMinutes,
    String? imageUrl,
    String? menuCategoryId,
    int? originalPriceVnd,
    bool clearOriginalPrice = false,
  }) {
    return _remote.updateCatalogItem(
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
  Future<FoodMenuItem> replaceItemOptions({
    required String accessToken,
    required String itemId,
    required List<FoodOptionGroup> groups,
  }) {
    return _remote.replaceItemOptions(
      accessToken: accessToken,
      itemId: itemId,
      groups: groups,
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

  @override
  Future<List<MerchantMenuCategory>> listMenuCategories(String accessToken) =>
      _remote.listMenuCategories(accessToken);

  @override
  Future<MerchantMenuCategory> createMenuCategory({
    required String accessToken,
    required String name,
    String? description,
  }) => _remote.createMenuCategory(
    accessToken: accessToken,
    name: name,
    description: description,
  );

  @override
  Future<MerchantMenuCategory> updateMenuCategory({
    required String accessToken,
    required String categoryId,
    required String name,
    String? description,
  }) => _remote.updateMenuCategory(
    accessToken: accessToken,
    categoryId: categoryId,
    name: name,
    description: description,
  );

  @override
  Future<void> deleteMenuCategory({
    required String accessToken,
    required String categoryId,
  }) => _remote.deleteMenuCategory(
    accessToken: accessToken,
    categoryId: categoryId,
  );

  @override
  Future<MerchantHistoryPage> listOrderHistory({
    required String accessToken,
    int page = 1,
    int limit = 20,
    String? tab,
    String? q,
  }) => _remote.listOrderHistory(
    accessToken: accessToken,
    page: page,
    limit: limit,
    tab: tab,
    q: q,
  );

  @override
  Future<List<MerchantMenuCategory>> reorderMenuCategories({
    required String accessToken,
    required List<String> orderedIds,
  }) => _remote.reorderMenuCategories(
    accessToken: accessToken,
    orderedIds: orderedIds,
  );

  @override
  Future<FoodMenuItem> uploadItemImage({
    required String accessToken,
    required String itemId,
    required String contentBase64,
    String? contentType,
  }) => _remote.uploadItemImage(
    accessToken: accessToken,
    itemId: itemId,
    contentBase64: contentBase64,
    contentType: contentType,
  );

  @override
  Future<FoodMenuItem> clearItemImage({
    required String accessToken,
    required String itemId,
  }) => _remote.clearItemImage(accessToken: accessToken, itemId: itemId);
}
