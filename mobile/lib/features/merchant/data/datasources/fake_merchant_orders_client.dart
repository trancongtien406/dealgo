import '../../../../core/network/api_exception.dart';
import '../../../food/domain/entities/food_models.dart';
import '../../domain/entities/merchant_menu_models.dart';
import 'merchant_orders_remote_datasource.dart';

class FakeMerchantOrdersClient implements MerchantOrdersClient {
  FakeMerchantOrdersClient({
    this.queueOrders = const [],
    this.queueError,
    this.acceptError,
    this.readyError,
    this.orderError,
    this.catalogError,
    this.createError,
    this.updateError,
    this.availabilityError,
    this.onAccept,
    this.onReady,
    this.onGetOrder,
    this.onGetCatalog,
    this.onCreateItem,
    this.onUpdateItem,
    this.onSetAvailability,
    this.onReplaceOptions,
    this.optionsError,
    this.onDeleteItem,
    this.deleteError,
  });

  List<MerchantQueueOrder> queueOrders;
  Object? queueError;
  Object? acceptError;
  Object? readyError;
  Object? orderError;
  Object? catalogError;
  Object? createError;
  Object? updateError;
  Object? availabilityError;
  MerchantOrderUpdate Function(String orderId)? onAccept;
  MerchantOrderUpdate Function(String orderId)? onReady;
  FoodOrderDetail Function(String orderId)? onGetOrder;
  FoodStoreDetail Function()? onGetCatalog;
  FoodMenuItem Function(String name, int priceVnd, bool? available)?
  onCreateItem;
  FoodMenuItem Function(String itemId, String? name, int? priceVnd)?
  onUpdateItem;
  FoodMenuItem Function(String itemId, bool available)? onSetAvailability;
  FoodMenuItem Function(String itemId, List<FoodOptionGroup> groups)?
  onReplaceOptions;
  Object? optionsError;

  final queueCalls = <String>[];
  final acceptCalls = <String>[];
  final rejectCalls = <String>[];

  /// Handles [rejectOrder]; unset = 500 like the other missing handlers.
  MerchantOrderUpdate Function(String orderId)? onReject;
  final readyCalls = <String>[];
  final orderCalls = <String>[];
  final catalogCalls = <String>[];
  final createCalls =
      <
        ({
          String name,
          int priceVnd,
          bool? available,
          String? description,
          int? prepMinutes,
          String? menuCategoryId,
        })
      >[];
  final updateCalls = <({String itemId, String? name, int? priceVnd})>[];
  final availabilityCalls = <({String itemId, bool available})>[];
  final optionCalls = <({String itemId, List<FoodOptionGroup> groups})>[];

  @override
  Future<FoodMenuItem> replaceItemOptions({
    required String accessToken,
    required String itemId,
    required List<FoodOptionGroup> groups,
  }) async {
    optionCalls.add((itemId: itemId, groups: groups));
    final error = optionsError;
    if (error != null) {
      throw error;
    }
    final handler = onReplaceOptions;
    if (handler == null) {
      throw const ApiException(
        statusCode: 500,
        message: 'FakeMerchantOrdersClient has no options handler',
        errorCode: 'FAKE_MISSING_HANDLER',
      );
    }
    return handler(itemId, groups);
  }

  @override
  Future<List<MerchantQueueOrder>> listOrderQueue(String accessToken) async {
    queueCalls.add(accessToken);
    final error = queueError;
    if (error != null) {
      throw error;
    }
    return List.unmodifiable(queueOrders);
  }

  @override
  Future<MerchantOrderUpdate> acceptOrder({
    required String accessToken,
    required String orderId,
  }) async {
    acceptCalls.add(orderId);
    final error = acceptError;
    if (error != null) {
      throw error;
    }
    final handler = onAccept;
    if (handler == null) {
      throw const ApiException(
        statusCode: 500,
        message: 'FakeMerchantOrdersClient has no accept handler',
        errorCode: 'FAKE_MISSING_HANDLER',
      );
    }
    return handler(orderId);
  }

  @override
  Future<MerchantOrderUpdate> rejectOrder({
    required String accessToken,
    required String orderId,
    required FoodRejectReason reason,
    String? note,
  }) async {
    rejectCalls.add(orderId);
    final handler = onReject;
    if (handler == null) {
      throw const ApiException(
        statusCode: 500,
        message: 'FakeMerchantOrdersClient has no reject handler',
        errorCode: 'FAKE_MISSING_HANDLER',
      );
    }
    return handler(orderId);
  }

  @override
  Future<MerchantOrderUpdate> markOrderReady({
    required String accessToken,
    required String orderId,
  }) async {
    readyCalls.add(orderId);
    final error = readyError;
    if (error != null) {
      throw error;
    }
    final handler = onReady;
    if (handler == null) {
      throw const ApiException(
        statusCode: 500,
        message: 'FakeMerchantOrdersClient has no ready handler',
        errorCode: 'FAKE_MISSING_HANDLER',
      );
    }
    return handler(orderId);
  }

  @override
  Future<FoodOrderDetail> getOrder({
    required String accessToken,
    required String orderId,
  }) async {
    orderCalls.add(orderId);
    final error = orderError;
    if (error != null) {
      throw error;
    }
    final handler = onGetOrder;
    if (handler == null) {
      throw const ApiException(
        statusCode: 500,
        message: 'FakeMerchantOrdersClient has no order handler',
        errorCode: 'FAKE_MISSING_HANDLER',
      );
    }
    return handler(orderId);
  }

  @override
  Future<FoodStoreDetail> getMerchantCatalog(String accessToken) async {
    catalogCalls.add(accessToken);
    final error = catalogError;
    if (error != null) {
      throw error;
    }
    final handler = onGetCatalog;
    if (handler == null) {
      throw const ApiException(
        statusCode: 500,
        message: 'FakeMerchantOrdersClient has no catalog handler',
        errorCode: 'FAKE_MISSING_HANDLER',
      );
    }
    return handler();
  }

  final storeHoursCalls = <StoreSchedule>[];

  /// M030 profile calls (DEC-PROD-045): `name:NAME`, 'logo', 'clear-logo'.
  final storeProfileCalls = <String>[];

  /// Set to make the next profile/logo call fail.
  Object? storeProfileError;

  Future<FoodStoreDetail> _profileUpdate(
    String call,
    FoodStoreDetail Function(FoodStoreDetail) change,
  ) async {
    storeProfileCalls.add(call);
    final error = storeProfileError;
    if (error != null) {
      storeProfileError = null;
      throw error;
    }
    final updated = change(await getMerchantCatalog(''));
    onGetCatalog = () => updated;
    return updated;
  }

  @override
  Future<FoodStoreDetail> updateStoreProfile({
    required String accessToken,
    String? name,
    String? category,
    int? minOrderVnd,
    String? description,
  }) => _profileUpdate(
    [
      if (name != null) 'name:$name',
      if (category != null) 'category:$category',
      if (minOrderVnd != null) 'minOrder:$minOrderVnd',
      if (description != null) 'description:$description',
    ].join(','),
    (s) => s.copyWith(
      name: name,
      category: category,
      minOrderVnd: minOrderVnd,
      description: description,
      clearDescription: description != null && description.isEmpty,
    ),
  );

  @override
  Future<FoodStoreDetail> uploadStoreLogo({
    required String accessToken,
    required String contentBase64,
    String? contentType,
    bool cover = false,
  }) => _profileUpdate(
    cover ? 'cover' : 'logo',
    (s) => cover
        ? s.copyWith(coverUrl: '/v1/public/store-covers/${s.id}/fake.png')
        : s.copyWith(logoUrl: '/v1/public/store-logos/${s.id}/fake.png'),
  );

  @override
  Future<FoodStoreDetail> clearStoreLogo({
    required String accessToken,
    bool cover = false,
  }) => _profileUpdate(
    cover ? 'clear-cover' : 'clear-logo',
    (s) => cover
        ? s.copyWith(clearCoverUrl: true)
        : s.copyWith(clearLogoUrl: true),
  );

  /// M030 saves: (lat, lng, addressLabel).
  final storeLocationCalls = <(double, double, String?)>[];

  @override
  Future<FoodStoreDetail> updateStoreLocation({
    required String accessToken,
    required double lat,
    required double lng,
    String? addressLabel,
  }) async {
    storeLocationCalls.add((lat, lng, addressLabel));
    final store = await getMerchantCatalog(accessToken);
    final updated = store.copyWith(
      lat: lat,
      lng: lng,
      addressLabel: addressLabel,
    );
    onGetCatalog = () => updated;
    return updated;
  }

  @override
  Future<FoodStoreDetail> updateStoreHours({
    required String accessToken,
    required StoreSchedule schedule,
  }) async {
    storeHoursCalls.add(schedule);
    final store = await getMerchantCatalog(accessToken);
    final updated = store.copyWith(schedule: schedule);
    onGetCatalog = () => updated;
    return updated;
  }

  /// M024 calls: (mode, resumeAfterMinutes).
  final storeStatusCalls = <(StoreServiceMode, int?)>[];
  Object? storeStatusError;

  /// M022 saves: (settings, lastOrderMinutes).
  final storeAcceptCalls = <(StoreAcceptSettings, int)>[];

  @override
  Future<FoodStoreDetail> updateStoreAcceptSettings({
    required String accessToken,
    required StoreAcceptSettings settings,
    required int lastOrderMinutes,
  }) async {
    storeAcceptCalls.add((settings, lastOrderMinutes));
    final store = await getMerchantCatalog(accessToken);
    final updated = store.copyWith(acceptSettings: settings);
    onGetCatalog = () => updated;
    return updated;
  }

  /// M024 extra BUSY minutes sent with each status save.
  final storeBusyExtraCalls = <int?>[];

  @override
  Future<FoodStoreDetail> updateStoreServiceMode({
    required String accessToken,
    required StoreServiceMode mode,
    int? resumeAfterMinutes,
    int? busyExtraMinutes,
  }) async {
    storeBusyExtraCalls.add(busyExtraMinutes);
    storeStatusCalls.add((mode, resumeAfterMinutes));
    final error = storeStatusError;
    if (error != null) {
      throw error;
    }
    final store = await getMerchantCatalog(accessToken);
    final until = mode == StoreServiceMode.open || resumeAfterMinutes == null
        ? null
        : DateTime.now().add(Duration(minutes: resumeAfterMinutes));
    final updated = store.copyWith(
      serviceMode: mode,
      serviceModeUntil: until,
      clearServiceModeUntil: until == null,
    );
    onGetCatalog = () => updated;
    return updated;
  }

  final deleteCalls = <String>[];
  Object? deleteError;
  void Function(String itemId)? onDeleteItem;

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
  }) async {
    createCalls.add((
      name: name,
      priceVnd: priceVnd,
      available: available,
      description: description,
      prepMinutes: prepMinutes,
      menuCategoryId: menuCategoryId,
    ));
    final error = createError;
    if (error != null) {
      throw error;
    }
    final handler = onCreateItem;
    final uploadedUrls = [
      if (newImages != null)
        for (var i = 0; i < newImages.length; i++)
          '/v1/public/menu-items/new/fake-$i.jpg',
    ];
    if (newImages != null && newImages.isNotEmpty) {
      uploadImageCalls.add('new');
    }
    if (handler == null) {
      throw const ApiException(
        statusCode: 500,
        message: 'FakeMerchantOrdersClient has no create handler',
        errorCode: 'FAKE_MISSING_HANDLER',
      );
    }
    final base = handler(name, priceVnd, available);
    return base.copyWith(
      description: description,
      prepMinutes: prepMinutes,
      menuCategoryId: menuCategoryId,
      originalPriceVnd: originalPriceVnd,
      imageUrl: uploadedUrls.isNotEmpty ? uploadedUrls.first : base.imageUrl,
      imageUrls: uploadedUrls.isNotEmpty ? uploadedUrls : base.imageUrls,
      optionGroups: optionGroups ?? base.optionGroups,
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
  }) async {
    updateCalls.add((itemId: itemId, name: name, priceVnd: priceVnd));
    if (newImages != null && newImages.isNotEmpty) {
      uploadImageCalls.add(itemId);
    }
    final error = updateError;
    if (error != null) {
      throw error;
    }
    final handler = onUpdateItem;
    if (handler == null) {
      throw const ApiException(
        statusCode: 500,
        message: 'FakeMerchantOrdersClient has no update handler',
        errorCode: 'FAKE_MISSING_HANDLER',
      );
    }
    final item = handler(itemId, name, priceVnd);
    final baseUrls = imageUrls ?? item.imageUrls;
    final addedUrls = [
      if (newImages != null)
        for (var i = 0; i < newImages.length; i++)
          '/v1/public/menu-items/$itemId/fake-${baseUrls.length + i}.jpg',
    ];
    final nextUrls = (imageUrls != null || addedUrls.isNotEmpty)
        ? [...baseUrls, ...addedUrls]
        : null;
    final nextImageUrl = nextUrls != null
        ? (nextUrls.isNotEmpty ? nextUrls.first : null)
        : imageUrl;
    return item.copyWith(
      available: available,
      description: description,
      clearDescription: clearDescription,
      prepMinutes: prepMinutes,
      clearPrepMinutes: clearPrepMinutes,
      imageUrl: nextImageUrl,
      clearImageUrl: nextUrls != null && nextUrls.isEmpty,
      imageUrls: nextUrls,
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
  }) async {
    deleteCalls.add(itemId);
    final error = deleteError;
    if (error != null) {
      throw error;
    }
    onDeleteItem?.call(itemId);
  }

  @override
  Future<FoodMenuItem> setItemAvailability({
    required String accessToken,
    required String itemId,
    required bool available,
  }) async {
    availabilityCalls.add((itemId: itemId, available: available));
    final error = availabilityError;
    if (error != null) {
      throw error;
    }
    final handler = onSetAvailability;
    if (handler == null) {
      throw const ApiException(
        statusCode: 500,
        message: 'FakeMerchantOrdersClient has no availability handler',
        errorCode: 'FAKE_MISSING_HANDLER',
      );
    }
    return handler(itemId, available);
  }

  final menuCategories = <MerchantMenuCategory>[
    const MerchantMenuCategory(
      id: 'cat-1',
      name: 'Món chính',
      position: 0,
      itemCount: 2,
    ),
    const MerchantMenuCategory(
      id: 'cat-2',
      name: 'Đồ uống',
      position: 1,
      itemCount: 1,
    ),
  ];
  final historyOrders = <MerchantHistoryOrder>[
    MerchantHistoryOrder(
      id: 'ord-done-1',
      status: 'DELIVERED',
      subtotalVnd: 85000,
      totalVnd: 95000,
      createdAt: DateTime(2026, 10, 18, 12, 0),
      finishedAt: DateTime(2026, 10, 18, 12, 45),
      customerName: 'Lan',
      lineSummary: '2 món',
    ),
  ];

  @override
  Future<List<MerchantMenuCategory>> listMenuCategories(
    String accessToken,
  ) async {
    return List.of(menuCategories);
  }

  @override
  Future<MerchantMenuCategory> createMenuCategory({
    required String accessToken,
    required String name,
    String? description,
  }) async {
    final cat = MerchantMenuCategory(
      id: 'cat-${menuCategories.length + 1}',
      name: name,
      description: description,
      position: menuCategories.length,
    );
    menuCategories.add(cat);
    return cat;
  }

  @override
  Future<MerchantMenuCategory> updateMenuCategory({
    required String accessToken,
    required String categoryId,
    required String name,
    String? description,
  }) async {
    final i = menuCategories.indexWhere((c) => c.id == categoryId);
    if (i < 0) {
      throw const ApiException(
        statusCode: 404,
        message: 'Missing',
        errorCode: 'NOT_FOUND',
      );
    }
    final next = MerchantMenuCategory(
      id: categoryId,
      name: name,
      description: description,
      position: menuCategories[i].position,
      itemCount: menuCategories[i].itemCount,
    );
    menuCategories[i] = next;
    return next;
  }

  @override
  Future<void> deleteMenuCategory({
    required String accessToken,
    required String categoryId,
  }) async {
    menuCategories.removeWhere((c) => c.id == categoryId);
  }

  @override
  Future<MerchantHistoryPage> listOrderHistory({
    required String accessToken,
    int page = 1,
    int limit = 20,
    String? tab,
    String? q,
    DateTime? from,
    DateTime? to,
  }) async {
    var items = List.of(historyOrders);
    if (tab == 'DELIVERED') {
      items = items.where((o) => o.status == 'DELIVERED').toList();
    } else if (tab == 'CANCELLED') {
      items = items
          .where((o) => o.status == 'CANCELLED' || o.status == 'FAILED')
          .toList();
    }
    if (from != null) {
      items = items
          .where(
            (o) =>
                o.finishedAt.isAfter(from) ||
                o.finishedAt.isAtSameMomentAs(from),
          )
          .toList();
    }
    if (to != null) {
      items = items
          .where(
            (o) =>
                o.finishedAt.isBefore(to) ||
                o.finishedAt.isAtSameMomentAs(to),
          )
          .toList();
    }
    if (q != null && q.trim().isNotEmpty) {
      final needle = q.trim().toLowerCase();
      items = items
          .where(
            (o) =>
                o.id.toLowerCase().contains(needle) ||
                (o.customerName?.toLowerCase().contains(needle) ?? false),
          )
          .toList();
    }
    return MerchantHistoryPage(
      items: items,
      page: page,
      limit: limit,
      total: items.length,
      deliveredCount: historyOrders
          .where((o) => o.status == 'DELIVERED')
          .length,
      deliveredRevenueVnd: historyOrders
          .where((o) => o.status == 'DELIVERED')
          .fold<int>(0, (sum, o) => sum + o.totalVnd),
    );
  }

  @override
  Future<List<MerchantMenuCategory>> reorderMenuCategories({
    required String accessToken,
    required List<String> orderedIds,
  }) async {
    final next = <MerchantMenuCategory>[];
    for (var i = 0; i < orderedIds.length; i++) {
      final prev = menuCategories.firstWhere((c) => c.id == orderedIds[i]);
      next.add(
        MerchantMenuCategory(
          id: prev.id,
          name: prev.name,
          description: prev.description,
          position: i,
          itemCount: prev.itemCount,
        ),
      );
    }
    menuCategories
      ..clear()
      ..addAll(next);
    return List.of(menuCategories);
  }

  @override
  Future<FoodMenuItem> uploadItemImage({
    required String accessToken,
    required String itemId,
    required String contentBase64,
    String? contentType,
  }) async {
    uploadImageCalls.add(itemId);
    final handler = onUpdateItem;
    if (handler == null) {
      final url = '/v1/public/menu-items/$itemId/fake.jpg';
      return FoodMenuItem(
        id: itemId,
        name: 'Item',
        priceVnd: 1000,
        available: true,
        imageUrl: url,
        imageUrls: [url],
      );
    }
    final url = '/v1/public/menu-items/$itemId/fake.jpg';
    final prev = handler(itemId, null, null);
    return prev.copyWith(imageUrl: url, imageUrls: [...prev.imageUrls, url]);
  }

  final uploadImageCalls = <String>[];

  @override
  Future<FoodMenuItem> clearItemImage({
    required String accessToken,
    required String itemId,
  }) async {
    final handler = onUpdateItem;
    if (handler == null) {
      return FoodMenuItem(
        id: itemId,
        name: 'Item',
        priceVnd: 1000,
        available: true,
        imageUrls: const [],
      );
    }
    return handler(
      itemId,
      null,
      null,
    ).copyWith(clearImageUrl: true, imageUrls: const []);
  }
}
