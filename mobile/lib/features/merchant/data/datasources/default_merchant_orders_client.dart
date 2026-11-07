import '../../../food/data/datasources/food_remote_datasource.dart';
import '../../../food/domain/entities/food_models.dart';
import '../../domain/entities/merchant_menu_models.dart';
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
  Future<MerchantOrderUpdate> rejectOrder({
    required String accessToken,
    required String orderId,
    required FoodRejectReason reason,
    String? note,
  }) {
    return food.rejectOrder(
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
  Future<FoodStoreDetail> updateStoreProfile({
    required String accessToken,
    String? name,
    String? category,
    int? minOrderVnd,
    String? description,
  }) => food.updateStoreProfile(
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
  }) => food.uploadStoreLogo(
    accessToken: accessToken,
    contentBase64: contentBase64,
    contentType: contentType,
    cover: cover,
  );

  @override
  Future<FoodStoreDetail> clearStoreLogo({
    required String accessToken,
    bool cover = false,
  }) => food.clearStoreLogo(accessToken: accessToken, cover: cover);

  @override
  Future<FoodStoreDetail> updateStoreLocation({
    required String accessToken,
    required double lat,
    required double lng,
    String? addressLabel,
  }) {
    return food.updateStoreLocation(
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
    return food.updateStoreHours(accessToken: accessToken, schedule: schedule);
  }

  @override
  Future<FoodStoreDetail> updateStoreServiceMode({
    required String accessToken,
    required StoreServiceMode mode,
    int? resumeAfterMinutes,
    int? busyExtraMinutes,
  }) {
    return food.updateStoreServiceMode(
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
    return food.updateStoreAcceptSettings(
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
    String? description,
    int? prepMinutes,
    String? menuCategoryId,
    int? originalPriceVnd,
    List<MerchantItemImageUpload>? newImages,
    List<FoodOptionGroup>? optionGroups,
  }) {
    return food.createMerchantItem(
      accessToken: accessToken,
      name: name,
      priceVnd: priceVnd,
      available: available,
      description: description,
      prepMinutes: prepMinutes,
      menuCategoryId: menuCategoryId,
      originalPriceVnd: originalPriceVnd,
      newImages: newImages,
      optionGroups: optionGroups,
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
    bool clearDescription = false,
    int? prepMinutes,
    bool clearPrepMinutes = false,
    String? imageUrl,
    List<String>? imageUrls,
    List<MerchantItemImageUpload>? newImages,
    String? menuCategoryId,
    bool clearMenuCategoryId = false,
    int? originalPriceVnd,
    bool clearOriginalPrice = false,
    List<FoodOptionGroup>? optionGroups,
  }) {
    return food.updateMerchantItem(
      accessToken: accessToken,
      itemId: itemId,
      name: name,
      priceVnd: priceVnd,
      available: available,
      description: description,
      clearDescription: clearDescription,
      prepMinutes: prepMinutes,
      clearPrepMinutes: clearPrepMinutes,
      imageUrl: imageUrl,
      imageUrls: imageUrls,
      newImages: newImages,
      menuCategoryId: menuCategoryId,
      clearMenuCategoryId: clearMenuCategoryId,
      originalPriceVnd: originalPriceVnd,
      clearOriginalPrice: clearOriginalPrice,
      optionGroups: optionGroups,
    );
  }

  @override
  Future<void> deleteCatalogItem({
    required String accessToken,
    required String itemId,
  }) {
    return food.deleteMerchantItem(accessToken: accessToken, itemId: itemId);
  }

  @override
  Future<FoodMenuItem> replaceItemOptions({
    required String accessToken,
    required String itemId,
    required List<FoodOptionGroup> groups,
  }) {
    return food.replaceMerchantItemOptions(
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
    return food.setMerchantItemAvailability(
      accessToken: accessToken,
      itemId: itemId,
      available: available,
    );
  }

  @override
  Future<List<MerchantMenuCategory>> listMenuCategories(String accessToken) =>
      food.listMerchantMenuCategories(accessToken);

  @override
  Future<MerchantMenuCategory> createMenuCategory({
    required String accessToken,
    required String name,
    String? description,
  }) => food.createMerchantMenuCategory(
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
  }) => food.updateMerchantMenuCategory(
    accessToken: accessToken,
    categoryId: categoryId,
    name: name,
    description: description,
  );

  @override
  Future<void> deleteMenuCategory({
    required String accessToken,
    required String categoryId,
  }) => food.deleteMerchantMenuCategory(
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
    DateTime? from,
    DateTime? to,
  }) => food.listMerchantOrderHistory(
    accessToken: accessToken,
    page: page,
    limit: limit,
    tab: tab,
    q: q,
    from: from,
    to: to,
  );

  @override
  Future<List<MerchantMenuCategory>> reorderMenuCategories({
    required String accessToken,
    required List<String> orderedIds,
  }) => food.reorderMerchantMenuCategories(
    accessToken: accessToken,
    orderedIds: orderedIds,
  );

  @override
  Future<FoodMenuItem> uploadItemImage({
    required String accessToken,
    required String itemId,
    required String contentBase64,
    String? contentType,
  }) => food.uploadMerchantItemImage(
    accessToken: accessToken,
    itemId: itemId,
    contentBase64: contentBase64,
    contentType: contentType,
  );

  @override
  Future<FoodMenuItem> clearItemImage({
    required String accessToken,
    required String itemId,
  }) => food.clearMerchantItemImage(accessToken: accessToken, itemId: itemId);
}
