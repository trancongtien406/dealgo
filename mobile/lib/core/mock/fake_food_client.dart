import '../../features/food/data/datasources/food_remote_datasource.dart';
import '../../features/food/domain/entities/food_models.dart';
import '../../features/merchant/domain/entities/merchant_menu_models.dart';
import '../network/api_exception.dart';

const _mockOwnedStoreId = 'store-bun-bo';

class FakeFoodClient implements FoodClient {
  FakeFoodClient({
    this.stores = const [],
    this.details = const {},
    this.placedOrder,
    this.placeError,
    this.readyOrders = const [],
    this.readyError,
    this.claimed,
    this.claimError,
    this.queueOrders = const [],
    this.queueError,
    this.accepted,
    this.acceptError,
    this.readied,
    this.readyMarkError,
    this.orderDetail,
    this.orderError,
    this.catalogError,
    this.catalogWriteError,
  });

  List<FoodStoreSummary> stores;
  Map<String, FoodStoreDetail> details;
  PlacedFoodOrder? placedOrder;
  Object? placeError;
  List<ReadyFoodJob> readyOrders;
  Object? readyError;
  ClaimedFoodDelivery? claimed;
  Object? claimError;
  List<MerchantQueueOrder> queueOrders;
  Object? queueError;
  MerchantOrderUpdate? accepted;
  Object? acceptError;
  MerchantOrderUpdate? readied;
  Object? readyMarkError;
  FoodOrderDetail? orderDetail;
  Object? orderError;
  Object? catalogError;
  Object? catalogWriteError;
  FoodOrderDetail Function(String orderId)? onGetOrder;
  final List<PlaceFoodRequest> placeCalls = [];
  final List<String> storeReads = [];

  /// One entry per listStores call: whether a GPS fix was sent.
  final List<bool> storeListGeo = [];
  final List<String> readyCalls = [];
  final List<String> claimCalls = [];
  final List<({String orderId, FoodDeliveryAction action})> advanceCalls = [];
  final List<String> cancelCalls = [];
  Object? advanceError;
  Object? cancelError;

  /// Codes sent with pickup / deliver, in order (DEC-PROD-036).
  final List<({FoodDeliveryAction action, String? code})> submittedCodes = [];

  /// When set, `deliver` fails like the backend unless this code is sent.
  String? expectedDeliveryCode;

  /// When set, `pickup` fails like the backend unless this code is sent.
  String? expectedHandoverCode;
  final List<String> queueCalls = [];
  final List<String> acceptCalls = [];
  final List<String> rejectCalls = [];
  final List<({FoodRejectReason reason, String? note})> rejectReasons = [];

  /// Thrown by [rejectOrder] when set (e.g. a 409 when the order moved on).
  Object? rejectError;
  final List<String> readyMarkCalls = [];
  final List<String> orderReads = [];
  final List<String> catalogCalls = [];
  final List<({String name, int priceVnd, bool? available})> createItemCalls =
      [];
  final List<({String itemId, String? name, int? priceVnd})> updateItemCalls =
      [];
  final List<({String itemId, bool available})> availabilityCalls = [];
  var _itemSeq = 0;

  @override
  Future<List<ReadyFoodJob>> listReadyOrders(String accessToken) async {
    readyCalls.add(accessToken);
    final error = readyError;
    if (error != null) {
      throw error;
    }
    return readyOrders;
  }

  @override
  Future<List<MerchantQueueOrder>> listOrderQueue(String accessToken) async {
    queueCalls.add(accessToken);
    final error = queueError;
    if (error != null) {
      throw error;
    }
    return queueOrders;
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
    final preset = accepted;
    if (preset != null) {
      return preset;
    }
    return _transition(orderId, 'PREPARING');
  }

  @override
  Future<MerchantOrderUpdate> rejectOrder({
    required String accessToken,
    required String orderId,
    required FoodRejectReason reason,
    String? note,
  }) async {
    rejectCalls.add(orderId);
    rejectReasons.add((reason: reason, note: note));
    final error = rejectError;
    if (error != null) {
      throw error;
    }
    return _transition(orderId, 'CANCELLED');
  }

  @override
  Future<MerchantOrderUpdate> markOrderReady({
    required String accessToken,
    required String orderId,
  }) async {
    readyMarkCalls.add(orderId);
    final error = readyMarkError;
    if (error != null) {
      throw error;
    }
    final preset = readied;
    if (preset != null) {
      return preset;
    }
    return _transition(orderId, 'READY');
  }

  MerchantOrderUpdate _transition(String orderId, String status) {
    for (final order in queueOrders) {
      if (order.id != orderId) {
        continue;
      }
      final update = MerchantOrderUpdate(
        id: order.id,
        status: status,
        storeId: order.storeId,
        deliveryFareVnd: order.deliveryFareVnd,
        subtotalVnd: order.subtotalVnd,
        totalVnd: order.totalVnd,
        dropoff: order.dropoff,
        lineCount: order.lineCount,
        createdAt: order.createdAt,
      );
      queueOrders = [
        for (final item in queueOrders)
          if (item.id == orderId) item.apply(update) else item,
      ];
      return update;
    }
    throw const ApiException(
      statusCode: 404,
      message: 'Food order not found',
      errorCode: 'FOOD_ORDER_NOT_FOUND',
    );
  }

  @override
  Future<ClaimedFoodDelivery> claimOrder({
    required String accessToken,
    required String orderId,
  }) async {
    claimCalls.add(orderId);
    final error = claimError;
    if (error != null) {
      throw error;
    }
    final order = claimed;
    if (order == null) {
      throw const ApiException(
        statusCode: 500,
        message: 'FakeFoodClient has no claim result',
        errorCode: 'FAKE_FOOD',
      );
    }
    return order;
  }

  @override
  Future<ClaimedFoodDelivery> advanceDelivery({
    required String accessToken,
    required String orderId,
    required FoodDeliveryAction action,
    /// DEC-PROD-036: handover code (pickup) or delivery code (deliver).
    String? code,
  }) async {
    advanceCalls.add((orderId: orderId, action: action));
    submittedCodes.add((action: action, code: code));
    final expected = switch (action) {
      FoodDeliveryAction.deliver => expectedDeliveryCode,
      FoodDeliveryAction.pickup => expectedHandoverCode,
      FoodDeliveryAction.fail => null,
    };
    if (expected != null && code != expected) {
      final prefix = action == FoodDeliveryAction.deliver
          ? 'FOOD_DELIVERY_CODE'
          : 'FOOD_HANDOVER_CODE';
      throw ApiException(
        statusCode: 422,
        message: 'Code required or wrong',
        errorCode: code == null ? '${prefix}_REQUIRED' : '${prefix}_INVALID',
      );
    }
    final error = advanceError;
    if (error != null) {
      throw error;
    }
    return ClaimedFoodDelivery(
      id: orderId,
      status: switch (action) {
        FoodDeliveryAction.pickup => 'PICKED_UP',
        FoodDeliveryAction.deliver => 'DELIVERED',
        FoodDeliveryAction.fail => 'FAILED',
      },
    );
  }

  @override
  Future<ClaimedFoodDelivery> cancelOrder({
    required String accessToken,
    required String orderId,
  }) async {
    cancelCalls.add(orderId);
    final error = cancelError;
    if (error != null) {
      throw error;
    }
    return ClaimedFoodDelivery(id: orderId, status: 'CANCELLED');
  }

  @override
  Future<List<FoodStoreSummary>> listStores(
    String accessToken, {
    double? lat,
    double? lng,
  }) async {
    storeListGeo.add(lat != null && lng != null);
    return stores;
  }

  @override
  Future<FoodStoreDetail> getStore(String accessToken, String storeId) async {
    storeReads.add(storeId);
    final detail = details[storeId];
    if (detail == null) {
      throw const ApiException(
        statusCode: 404,
        message: 'Store not found',
        errorCode: 'FOOD_STORE_NOT_FOUND',
      );
    }
    return detail;
  }

  @override
  Future<FoodStoreDetail> getMerchantCatalog(String accessToken) async {
    catalogCalls.add(accessToken);
    final error = catalogError;
    if (error != null) {
      throw error;
    }
    return _ownedCatalog();
  }

  /// M024 calls: (mode, resumeAfterMinutes).
  final storeStatusCalls = <(StoreServiceMode, int?)>[];
  StoreServiceMode _storeMode = StoreServiceMode.open;
  DateTime? _storeModeUntil;

  /// M023 saves.
  final storeHoursCalls = <StoreSchedule>[];
  StoreSchedule? _storeSchedule;

  /// M030 profile saves (DEC-PROD-045).
  final storeProfileCalls = <String>[];
  String? _storeName;
  String? _storeLogo;

  @override
  Future<FoodStoreDetail> updateStoreProfile({
    required String accessToken,
    required String name,
  }) async {
    storeProfileCalls.add(name);
    _storeName = name;
    return _ownedCatalog();
  }

  @override
  Future<FoodStoreDetail> uploadStoreLogo({
    required String accessToken,
    required String contentBase64,
    String? contentType,
  }) async {
    final store = _ownedCatalog();
    _storeLogo = '/v1/public/store-logos/${store.id}/fake.png';
    return _ownedCatalog();
  }

  @override
  Future<FoodStoreDetail> clearStoreLogo({required String accessToken}) async {
    _storeLogo = null;
    return _ownedCatalog();
  }

  /// M030 saves: (lat, lng, addressLabel).
  final storeLocationCalls = <(double, double, String?)>[];
  (double, double, String?)? _storeLocation;

  @override
  Future<FoodStoreDetail> updateStoreLocation({
    required String accessToken,
    required double lat,
    required double lng,
    String? addressLabel,
  }) async {
    final saved = (lat, lng, addressLabel);
    storeLocationCalls.add(saved);
    _storeLocation = saved;
    return _ownedCatalog();
  }

  @override
  Future<FoodStoreDetail> updateStoreHours({
    required String accessToken,
    required StoreSchedule schedule,
  }) async {
    final saved = StoreSchedule(
      hoursConfigured: true,
      lastOrderMinutes: schedule.lastOrderMinutes,
      weekly: schedule.weekly,
      closures: schedule.closures,
    );
    storeHoursCalls.add(saved);
    _storeSchedule = saved;
    return _ownedCatalog();
  }

  /// M024 BUSY extra minutes sent with each status save.
  final storeBusyExtraCalls = <int?>[];

  /// M022 saves: (settings, lastOrderMinutes).
  final storeAcceptCalls = <(StoreAcceptSettings, int)>[];
  StoreAcceptSettings _acceptSettings = const StoreAcceptSettings();

  @override
  Future<FoodStoreDetail> updateStoreAcceptSettings({
    required String accessToken,
    required StoreAcceptSettings settings,
    required int lastOrderMinutes,
  }) async {
    storeAcceptCalls.add((settings, lastOrderMinutes));
    _acceptSettings = settings.copyWith(
      busyExtraMinutes: _acceptSettings.busyExtraMinutes,
    );
    final schedule = _storeSchedule ?? const StoreSchedule();
    _storeSchedule = StoreSchedule(
      hoursConfigured: schedule.hoursConfigured,
      lastOrderMinutes: lastOrderMinutes,
      weekly: schedule.weekly,
      closures: schedule.closures,
    );
    return _ownedCatalog();
  }

  @override
  Future<FoodStoreDetail> updateStoreServiceMode({
    required String accessToken,
    required StoreServiceMode mode,
    int? resumeAfterMinutes,
    int? busyExtraMinutes,
  }) async {
    storeStatusCalls.add((mode, resumeAfterMinutes));
    storeBusyExtraCalls.add(busyExtraMinutes);
    if (busyExtraMinutes != null) {
      _acceptSettings = _acceptSettings.copyWith(
        busyExtraMinutes: busyExtraMinutes,
      );
    }
    _storeMode = mode;
    _storeModeUntil =
        mode == StoreServiceMode.open || resumeAfterMinutes == null
        ? null
        : DateTime.now().add(Duration(minutes: resumeAfterMinutes));
    return _ownedCatalog();
  }

  @override
  Future<FoodMenuItem> createMerchantItem({
    required String accessToken,
    required String name,
    required int priceVnd,
    bool? available,
  }) async {
    createItemCalls.add((name: name, priceVnd: priceVnd, available: available));
    final error = catalogWriteError;
    if (error != null) {
      throw error;
    }
    final store = _ownedCatalog();
    final item = FoodMenuItem(
      id: 'mock-item-${++_itemSeq}',
      name: name,
      priceVnd: priceVnd,
      available: available ?? true,
    );
    details = {
      ...details,
      store.id: FoodStoreDetail(
        id: store.id,
        name: store.name,
        items: List.unmodifiable([...store.items, item]),
      ),
    };
    return item;
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
  }) async {
    updateItemCalls.add((itemId: itemId, name: name, priceVnd: priceVnd));
    final error = catalogWriteError;
    if (error != null) {
      throw error;
    }
    if (name == null &&
        priceVnd == null &&
        available == null &&
        description == null &&
        prepMinutes == null &&
        imageUrl == null &&
        menuCategoryId == null) {
      throw const ApiException(
        statusCode: 400,
        message: 'Provide at least one field to update',
        errorCode: 'VALIDATION_ERROR',
      );
    }
    return _replaceOwnedItem(itemId, (item) {
      return item.copyWith(
        name: name,
        priceVnd: priceVnd,
        available: available,
        description: description,
        prepMinutes: prepMinutes,
        imageUrl: imageUrl,
        menuCategoryId: menuCategoryId,
      );
    });
  }

  @override
  Future<FoodMenuItem> setMerchantItemAvailability({
    required String accessToken,
    required String itemId,
    required bool available,
  }) async {
    availabilityCalls.add((itemId: itemId, available: available));
    final error = catalogWriteError;
    if (error != null) {
      throw error;
    }
    return _replaceOwnedItem(itemId, (item) {
      return item.copyWith(available: available);
    });
  }

  /// Records `PUT …/options` bodies (DEC-PROD-033) for tests.
  final List<({String itemId, List<FoodOptionGroup> groups})> optionCalls = [];

  @override
  Future<FoodMenuItem> replaceMerchantItemOptions({
    required String accessToken,
    required String itemId,
    required List<FoodOptionGroup> groups,
  }) async {
    optionCalls.add((itemId: itemId, groups: groups));
    final error = catalogWriteError;
    if (error != null) {
      throw error;
    }
    var seq = 0;
    String mint(String prefix) => '$prefix-$itemId-${seq++}';
    final saved = [
      for (final group in groups)
        FoodOptionGroup(
          id: group.id.isNotEmpty ? group.id : mint('g'),
          title: group.title,
          minSelect: group.minSelect,
          maxSelect: group.maxSelect,
          choices: [
            for (final choice in group.choices)
              FoodOptionChoice(
                id: choice.id.isNotEmpty ? choice.id : mint('o'),
                label: choice.label,
                extraVnd: choice.extraVnd,
                available: choice.available,
              ),
          ],
        ),
    ];
    return _replaceOwnedItem(itemId, (item) {
      return FoodMenuItem(
        id: item.id,
        name: item.name,
        priceVnd: item.priceVnd,
        available: item.available,
        optionGroups: saved,
      );
    });
  }

  FoodStoreDetail _ownedCatalog() {
    final owned =
        details[_mockOwnedStoreId] ??
        (details.isNotEmpty ? details.values.first : null);
    if (owned != null) {
      return owned.copyWith(
        lat: _storeLocation?.$1,
        lng: _storeLocation?.$2,
        addressLabel: _storeLocation?.$3,
        name: _storeName,
        logoUrl: _storeLogo,
        clearLogoUrl: _storeLogo == null,
        schedule: _storeSchedule,
        serviceMode: _storeMode,
        serviceModeUntil: _storeModeUntil,
        clearServiceModeUntil: _storeModeUntil == null,
        acceptSettings: _acceptSettings,
        estimatedPrepMinutes:
            _acceptSettings.defaultPrepMinutes +
            (_storeMode == StoreServiceMode.busy
                ? _acceptSettings.busyExtraMinutes
                : 0),
      );
    }
    throw const ApiException(
      statusCode: 404,
      message: 'Store not found',
      errorCode: 'FOOD_STORE_NOT_FOUND',
    );
  }

  FoodMenuItem _replaceOwnedItem(
    String itemId,
    FoodMenuItem Function(FoodMenuItem item) map,
  ) {
    final store = _ownedCatalog();
    FoodMenuItem? updated;
    final nextItems = <FoodMenuItem>[];
    for (final item in store.items) {
      if (item.id == itemId) {
        updated = map(item);
        nextItems.add(updated);
      } else {
        nextItems.add(item);
      }
    }
    if (updated == null) {
      throw const ApiException(
        statusCode: 404,
        message: 'Catalog item not found',
        errorCode: 'FOOD_ITEM_NOT_FOUND',
      );
    }
    details = {
      ...details,
      store.id: FoodStoreDetail(
        id: store.id,
        name: store.name,
        items: List.unmodifiable(nextItems),
      ),
    };
    return updated;
  }

  @override
  Future<FoodOrderDetail> getOrder({
    required String accessToken,
    required String orderId,
  }) async {
    orderReads.add(orderId);
    final error = orderError;
    if (error != null) {
      throw error;
    }
    final handler = onGetOrder;
    if (handler != null) {
      return handler(orderId);
    }
    final detail = orderDetail;
    if (detail != null) {
      return detail;
    }
    throw const ApiException(
      statusCode: 404,
      message: 'Food order not found',
      errorCode: 'FOOD_ORDER_NOT_FOUND',
    );
  }

  @override
  Future<PlacedFoodOrder> placeOrder(PlaceFoodRequest request) async {
    placeCalls.add(request);
    final error = placeError;
    if (error != null) {
      throw error;
    }
    final order = placedOrder;
    if (order == null) {
      throw StateError('FakeFoodClient has no placed order');
    }
    return order;
  }

  final _menuCategories = <MerchantMenuCategory>[
    const MerchantMenuCategory(id: 'cat-1', name: 'Món chính', position: 0, itemCount: 1),
  ];

  @override
  Future<List<MerchantMenuCategory>> listMerchantMenuCategories(String accessToken) async =>
      List.of(_menuCategories);

  @override
  Future<MerchantMenuCategory> createMerchantMenuCategory({
    required String accessToken,
    required String name,
    String? description,
  }) async {
    final cat = MerchantMenuCategory(
      id: 'cat-${_menuCategories.length + 1}',
      name: name,
      description: description,
      position: _menuCategories.length,
    );
    _menuCategories.add(cat);
    return cat;
  }

  @override
  Future<MerchantMenuCategory> updateMerchantMenuCategory({
    required String accessToken,
    required String categoryId,
    required String name,
    String? description,
  }) async {
    final i = _menuCategories.indexWhere((c) => c.id == categoryId);
    final prev = _menuCategories[i];
    final next = MerchantMenuCategory(
      id: categoryId,
      name: name,
      description: description,
      position: prev.position,
      itemCount: prev.itemCount,
    );
    _menuCategories[i] = next;
    return next;
  }

  @override
  Future<void> deleteMerchantMenuCategory({
    required String accessToken,
    required String categoryId,
  }) async {
    _menuCategories.removeWhere((c) => c.id == categoryId);
  }

  @override
  Future<MerchantHistoryPage> listMerchantOrderHistory({
    required String accessToken,
    int page = 1,
    int limit = 20,
    String? tab,
    String? q,
  }) async {
    return const MerchantHistoryPage(
      items: [],
      page: 1,
      limit: 20,
      total: 0,
      deliveredCount: 0,
      deliveredRevenueVnd: 0,
    );
  }

  @override
  Future<List<MerchantMenuCategory>> reorderMerchantMenuCategories({
    required String accessToken,
    required List<String> orderedIds,
  }) async {
    final next = <MerchantMenuCategory>[];
    for (var i = 0; i < orderedIds.length; i++) {
      final id = orderedIds[i];
      final prev = _menuCategories.firstWhere((c) => c.id == id);
      next.add(MerchantMenuCategory(
        id: prev.id,
        name: prev.name,
        description: prev.description,
        position: i,
        itemCount: prev.itemCount,
      ));
    }
    _menuCategories
      ..clear()
      ..addAll(next);
    return List.of(_menuCategories);
  }

  @override
  Future<FoodMenuItem> uploadMerchantItemImage({
    required String accessToken,
    required String itemId,
    required String contentBase64,
    String? contentType,
  }) async {
    return _replaceOwnedItem(itemId, (item) {
      return item.copyWith(
        imageUrl: '/v1/public/menu-items/$itemId/fake.jpg',
      );
    });
  }

  @override
  Future<FoodMenuItem> clearMerchantItemImage({
    required String accessToken,
    required String itemId,
  }) async {
    return _replaceOwnedItem(itemId, (item) {
      return item.copyWith(clearImageUrl: true);
    });
  }
}
