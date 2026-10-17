import '../../../../core/network/api_exception.dart';
import '../../../food/domain/entities/food_models.dart';
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

  final queueCalls = <String>[];
  final acceptCalls = <String>[];
  final readyCalls = <String>[];
  final orderCalls = <String>[];
  final catalogCalls = <String>[];
  final createCalls = <({String name, int priceVnd, bool? available})>[];
  final updateCalls = <({String itemId, String? name, int? priceVnd})>[];
  final availabilityCalls = <({String itemId, bool available})>[];

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

  @override
  Future<FoodMenuItem> createCatalogItem({
    required String accessToken,
    required String name,
    required int priceVnd,
    bool? available,
  }) async {
    createCalls.add((name: name, priceVnd: priceVnd, available: available));
    final error = createError;
    if (error != null) {
      throw error;
    }
    final handler = onCreateItem;
    if (handler == null) {
      throw const ApiException(
        statusCode: 500,
        message: 'FakeMerchantOrdersClient has no create handler',
        errorCode: 'FAKE_MISSING_HANDLER',
      );
    }
    return handler(name, priceVnd, available);
  }

  @override
  Future<FoodMenuItem> updateCatalogItem({
    required String accessToken,
    required String itemId,
    String? name,
    int? priceVnd,
  }) async {
    updateCalls.add((itemId: itemId, name: name, priceVnd: priceVnd));
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
    return handler(itemId, name, priceVnd);
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
}
