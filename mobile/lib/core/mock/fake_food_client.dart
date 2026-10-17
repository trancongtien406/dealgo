import '../../features/food/data/datasources/food_remote_datasource.dart';
import '../../features/food/domain/entities/food_models.dart';
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
  final List<String> readyCalls = [];
  final List<String> claimCalls = [];
  final List<String> queueCalls = [];
  final List<String> acceptCalls = [];
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
  Future<List<FoodStoreSummary>> listStores(String accessToken) async {
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
  }) async {
    updateItemCalls.add((itemId: itemId, name: name, priceVnd: priceVnd));
    final error = catalogWriteError;
    if (error != null) {
      throw error;
    }
    if (name == null && priceVnd == null) {
      throw const ApiException(
        statusCode: 400,
        message: 'Provide name and/or priceVnd to update',
        errorCode: 'VALIDATION_ERROR',
      );
    }
    return _replaceOwnedItem(itemId, (item) {
      return FoodMenuItem(
        id: item.id,
        name: name ?? item.name,
        priceVnd: priceVnd ?? item.priceVnd,
        available: item.available,
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
      return FoodMenuItem(
        id: item.id,
        name: item.name,
        priceVnd: item.priceVnd,
        available: available,
      );
    });
  }

  FoodStoreDetail _ownedCatalog() {
    final owned = details[_mockOwnedStoreId];
    if (owned != null) {
      return owned;
    }
    if (details.isNotEmpty) {
      return details.values.first;
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
}
