import 'package:dio/dio.dart';

import '../../../../core/network/api_envelope.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/api_paths.dart';
import '../../../../core/network/dio_mapper.dart';
import '../../domain/entities/food_models.dart';
import '../models/place_food_order_body.dart';
import 'food_remote_datasource.dart';

class DioFoodRemoteDataSource implements FoodRemoteDataSource {
  DioFoodRemoteDataSource({required this.dio});

  final Dio dio;

  @override
  Future<List<ReadyFoodJob>> listReadyOrders(String accessToken) {
    return _send(
      () => dio.get<Object?>(
        ApiPaths.foodOrdersReady,
        options: _auth(accessToken),
      ),
      decodeReadyFoodJobs,
    );
  }

  @override
  Future<List<MerchantQueueOrder>> listOrderQueue(String accessToken) {
    return _send(
      () => dio.get<Object?>(
        ApiPaths.foodOrdersQueue,
        options: _auth(accessToken),
      ),
      decodeMerchantQueue,
    );
  }

  @override
  Future<MerchantOrderUpdate> acceptOrder({
    required String accessToken,
    required String orderId,
  }) {
    return _send(
      () => dio.post<Object?>(
        ApiPaths.foodOrderAccept(orderId),
        options: _auth(accessToken),
      ),
      decodeMerchantOrderUpdate,
    );
  }

  @override
  Future<MerchantOrderUpdate> markOrderReady({
    required String accessToken,
    required String orderId,
  }) {
    return _send(
      () => dio.post<Object?>(
        ApiPaths.foodOrderReady(orderId),
        options: _auth(accessToken),
      ),
      decodeMerchantOrderUpdate,
    );
  }

  @override
  Future<ClaimedFoodDelivery> claimOrder({
    required String accessToken,
    required String orderId,
  }) {
    return _send(
      () => dio.post<Object?>(
        ApiPaths.foodOrderClaim(orderId),
        options: _auth(accessToken),
      ),
      decodeClaimedFoodDelivery,
    );
  }

  @override
  Future<List<FoodStoreSummary>> listStores(String accessToken) {
    return _send(
      () => dio.get<Object?>(ApiPaths.foodStores, options: _auth(accessToken)),
      decodeFoodStoreList,
    );
  }

  @override
  Future<FoodStoreDetail> getStore(String accessToken, String storeId) {
    return _send(
      () => dio.get<Object?>(
        ApiPaths.foodStore(storeId),
        options: _auth(accessToken),
      ),
      decodeFoodStoreDetail,
    );
  }

  @override
  Future<FoodStoreDetail> getMerchantCatalog(String accessToken) {
    return _send(
      () => dio.get<Object?>(
        ApiPaths.foodMerchantCatalog,
        options: _auth(accessToken),
      ),
      decodeFoodStoreDetail,
    );
  }

  @override
  Future<FoodMenuItem> createMerchantItem({
    required String accessToken,
    required String name,
    required int priceVnd,
    bool? available,
  }) {
    return _send(
      () => dio.post<Object?>(
        ApiPaths.foodMerchantItems,
        data: {'name': name, 'priceVnd': priceVnd, 'available': ?available},
        options: _auth(accessToken),
      ),
      decodeFoodMenuItem,
    );
  }

  @override
  Future<FoodMenuItem> updateMerchantItem({
    required String accessToken,
    required String itemId,
    String? name,
    int? priceVnd,
  }) {
    return _send(
      () => dio.patch<Object?>(
        ApiPaths.foodMerchantItem(itemId),
        data: {'name': ?name, 'priceVnd': ?priceVnd},
        options: _auth(accessToken),
      ),
      decodeFoodMenuItem,
    );
  }

  @override
  Future<FoodMenuItem> setMerchantItemAvailability({
    required String accessToken,
    required String itemId,
    required bool available,
  }) {
    return _send(
      () => dio.patch<Object?>(
        ApiPaths.foodMerchantItemAvailability(itemId),
        data: {'available': available},
        options: _auth(accessToken),
      ),
      decodeFoodMenuItem,
    );
  }

  @override
  Future<FoodOrderDetail> getOrder({
    required String accessToken,
    required String orderId,
  }) {
    return _send(
      () => dio.get<Object?>(
        ApiPaths.foodOrder(orderId),
        options: _auth(accessToken),
      ),
      decodeFoodOrderDetail,
    );
  }

  @override
  Future<PlacedFoodOrder> placeOrder(PlaceFoodRequest request) {
    final key = request.idempotencyKey.trim();
    if (key.length < 8 || key.length > 200) {
      throw const ApiException(
        statusCode: 400,
        message: 'Idempotency-Key must be 8 to 200 characters',
        errorCode: 'VALIDATION_ERROR',
      );
    }
    return _send(
      () => dio.post<Object?>(
        ApiPaths.foodOrders,
        data: PlaceFoodOrderBody.fromParams(request).toJson(),
        options: Options(
          headers: {
            'Authorization': 'Bearer ${request.accessToken}',
            'Idempotency-Key': key,
          },
        ),
      ),
      decodePlacedFoodOrder,
    );
  }

  Future<T> _send<T>(
    Future<Response<Object?>> Function() send,
    T Function(Object? body) decode,
  ) async {
    try {
      final response = await send();
      return decode(response.data);
    } on DioException catch (error) {
      throw apiExceptionFromDio(error);
    }
  }
}

Options _auth(String accessToken) {
  return Options(headers: {'Authorization': 'Bearer $accessToken'});
}

List<ReadyFoodJob> decodeReadyFoodJobs(Object? body) {
  final data = readSuccessPayload(body);
  if (data is! List) {
    throw const ApiException(
      statusCode: 200,
      message: 'Phản hồi không hợp lệ',
      errorCode: 'INVALID_RESPONSE',
    );
  }
  final jobs = <ReadyFoodJob>[];
  for (final item in data) {
    final job = _readyJob(item);
    if (job != null) {
      jobs.add(job);
    }
  }
  return List.unmodifiable(jobs);
}

ReadyFoodJob? _readyJob(Object? raw) {
  final map = asJsonMap(raw);
  if (map == null) {
    return null;
  }
  final id = map['id'];
  final storeId = map['storeId'];
  final deliveryFareVnd = _asInt(map['deliveryFareVnd']);
  final subtotalVnd = _asInt(map['subtotalVnd']);
  final totalVnd = _asInt(map['totalVnd']);
  final dropoff = _dropoff(map['dropoff']);
  final lineCount = _asInt(map['lineCount']);
  if (id is! String ||
      id.isEmpty ||
      storeId is! String ||
      storeId.isEmpty ||
      deliveryFareVnd == null ||
      subtotalVnd == null ||
      totalVnd == null ||
      dropoff == null ||
      lineCount == null) {
    return null;
  }
  return ReadyFoodJob(
    id: id,
    storeId: storeId,
    deliveryFareVnd: deliveryFareVnd,
    subtotalVnd: subtotalVnd,
    totalVnd: totalVnd,
    dropoff: dropoff,
    lineCount: lineCount,
  );
}

FoodDropoff? _dropoff(Object? raw) {
  final map = asJsonMap(raw);
  if (map == null) {
    return null;
  }
  final lat = _asDouble(map['lat']);
  final lng = _asDouble(map['lng']);
  final label = map['label'];
  if (lat == null || lng == null || label is! String || label.isEmpty) {
    return null;
  }
  return FoodDropoff(lat: lat, lng: lng, label: label);
}

List<MerchantQueueOrder> decodeMerchantQueue(Object? body) {
  final data = readSuccessPayload(body);
  if (data is! List) {
    throw const ApiException(
      statusCode: 200,
      message: 'Phản hồi không hợp lệ',
      errorCode: 'INVALID_RESPONSE',
    );
  }
  final orders = <MerchantQueueOrder>[];
  for (final item in data) {
    final order = _queueOrder(item);
    if (order != null) {
      orders.add(order);
    }
  }
  return List.unmodifiable(orders);
}

MerchantQueueOrder? _queueOrder(Object? raw) {
  final map = asJsonMap(raw);
  if (map == null) {
    return null;
  }
  final id = map['id'];
  final storeId = map['storeId'];
  final status = map['status'];
  final deliveryFareVnd = _asInt(map['deliveryFareVnd']);
  final subtotalVnd = _asInt(map['subtotalVnd']);
  final totalVnd = _asInt(map['totalVnd']);
  final dropoff = _dropoff(map['dropoff']);
  final lineCount = _asInt(map['lineCount']);
  final createdAt = map['createdAt'];
  if (id is! String ||
      id.isEmpty ||
      storeId is! String ||
      storeId.isEmpty ||
      status is! String ||
      status.isEmpty ||
      deliveryFareVnd == null ||
      subtotalVnd == null ||
      totalVnd == null ||
      dropoff == null ||
      lineCount == null ||
      createdAt is! String ||
      createdAt.isEmpty) {
    return null;
  }
  return MerchantQueueOrder(
    id: id,
    storeId: storeId,
    status: status,
    deliveryFareVnd: deliveryFareVnd,
    subtotalVnd: subtotalVnd,
    totalVnd: totalVnd,
    dropoff: dropoff,
    lineCount: lineCount,
    createdAt: createdAt,
  );
}

MerchantOrderUpdate decodeMerchantOrderUpdate(Object? body) {
  final data = asJsonMap(readSuccessPayload(body));
  if (data == null) {
    throw const ApiException(
      statusCode: 200,
      message: 'Phản hồi không hợp lệ',
      errorCode: 'INVALID_RESPONSE',
    );
  }
  final id = data['id'];
  final status = data['status'];
  if (id is! String || id.isEmpty || status is! String || status.isEmpty) {
    throw const ApiException(
      statusCode: 200,
      message: 'Phản hồi không hợp lệ',
      errorCode: 'INVALID_RESPONSE',
    );
  }
  final storeId = data['storeId'];
  final createdAt = data['createdAt'];
  return MerchantOrderUpdate(
    id: id,
    status: status,
    storeId: storeId is String && storeId.isNotEmpty ? storeId : null,
    deliveryFareVnd: _asInt(data['deliveryFareVnd']),
    subtotalVnd: _asInt(data['subtotalVnd']),
    totalVnd: _asInt(data['totalVnd']),
    dropoff: _dropoff(data['dropoff']),
    lineCount: _lineCount(data),
    createdAt: createdAt is String && createdAt.isNotEmpty ? createdAt : null,
  );
}

int? _lineCount(Map<String, Object?> data) {
  if (data.containsKey('lineCount')) {
    return _asInt(data['lineCount']);
  }
  final lines = data['lines'];
  if (lines is List) {
    return lines.length;
  }
  return null;
}

ClaimedFoodDelivery decodeClaimedFoodDelivery(Object? body) {
  final data = asJsonMap(readSuccessPayload(body));
  if (data == null) {
    throw const ApiException(
      statusCode: 200,
      message: 'Phản hồi không hợp lệ',
      errorCode: 'INVALID_RESPONSE',
    );
  }
  final id = data['id'];
  final status = data['status'];
  if (id is! String || id.isEmpty || status is! String || status.isEmpty) {
    throw const ApiException(
      statusCode: 200,
      message: 'Phản hồi không hợp lệ',
      errorCode: 'INVALID_RESPONSE',
    );
  }
  return ClaimedFoodDelivery(id: id, status: status);
}

List<FoodStoreSummary> decodeFoodStoreList(Object? body) {
  // GET /v1/food/stores puts a JSON array in `data`, not an object.
  final data = _successPayload(body);
  if (data is! List) {
    throw const ApiException(
      statusCode: 200,
      message: 'Phản hồi không hợp lệ',
      errorCode: 'INVALID_RESPONSE',
    );
  }
  final stores = <FoodStoreSummary>[];
  for (final item in data) {
    final map = asJsonMap(item);
    if (map == null) {
      continue;
    }
    final id = map['id'];
    final name = map['name'];
    if (id is String && id.isNotEmpty && name is String && name.isNotEmpty) {
      stores.add(FoodStoreSummary(id: id, name: name));
    }
  }
  return List.unmodifiable(stores);
}

FoodStoreDetail decodeFoodStoreDetail(Object? body) {
  final data = asJsonMap(_successPayload(body));
  if (data == null) {
    throw const ApiException(
      statusCode: 200,
      message: 'Phản hồi không hợp lệ',
      errorCode: 'INVALID_RESPONSE',
    );
  }
  final id = data['id'];
  final name = data['name'];
  final rawItems = data['items'];
  if (id is! String ||
      id.isEmpty ||
      name is! String ||
      name.isEmpty ||
      rawItems is! List) {
    throw const ApiException(
      statusCode: 200,
      message: 'Phản hồi không hợp lệ',
      errorCode: 'INVALID_RESPONSE',
    );
  }
  final items = <FoodMenuItem>[];
  for (final raw in rawItems) {
    final item = _menuItem(raw);
    if (item != null) {
      items.add(item);
    }
  }
  return FoodStoreDetail(id: id, name: name, items: List.unmodifiable(items));
}

FoodMenuItem decodeFoodMenuItem(Object? body) {
  final item = _menuItem(_successPayload(body));
  if (item == null) {
    throw const ApiException(
      statusCode: 200,
      message: 'Phản hồi không hợp lệ',
      errorCode: 'INVALID_RESPONSE',
    );
  }
  return item;
}

FoodMenuItem? _menuItem(Object? raw) {
  final map = asJsonMap(raw);
  if (map == null) {
    return null;
  }
  final itemId = map['id'];
  final itemName = map['name'];
  final price = _asInt(map['priceVnd']);
  final available = map['available'];
  if (itemId is! String ||
      itemId.isEmpty ||
      itemName is! String ||
      itemName.isEmpty ||
      price == null ||
      available is! bool) {
    return null;
  }
  return FoodMenuItem(
    id: itemId,
    name: itemName,
    priceVnd: price,
    available: available,
  );
}

FoodOrderDetail decodeFoodOrderDetail(Object? body) {
  final data = asJsonMap(_successPayload(body));
  if (data == null) {
    throw const ApiException(
      statusCode: 200,
      message: 'Phản hồi không hợp lệ',
      errorCode: 'INVALID_RESPONSE',
    );
  }
  final id = data['id'];
  final status = data['status'];
  final subtotal = _asInt(data['subtotalVnd']);
  final delivery = _asInt(data['deliveryFareVnd']);
  final total = _asInt(data['totalVnd']);
  final dropoff = _dropoff(data['dropoff']);
  if (id is! String ||
      id.isEmpty ||
      status is! String ||
      status.isEmpty ||
      subtotal == null ||
      delivery == null ||
      total == null ||
      dropoff == null) {
    throw const ApiException(
      statusCode: 200,
      message: 'Phản hồi không hợp lệ',
      errorCode: 'INVALID_RESPONSE',
    );
  }
  return FoodOrderDetail(
    id: id,
    status: status,
    subtotalVnd: subtotal,
    deliveryFareVnd: delivery,
    totalVnd: total,
    dropoff: dropoff,
    lines: _decodeLines(data['lines']),
  );
}

PlacedFoodOrder decodePlacedFoodOrder(Object? body) {
  final data = asJsonMap(_successPayload(body));
  if (data == null) {
    throw const ApiException(
      statusCode: 200,
      message: 'Phản hồi không hợp lệ',
      errorCode: 'INVALID_RESPONSE',
    );
  }
  final id = data['id'];
  final status = data['status'];
  final subtotal = _asInt(data['subtotalVnd']);
  final delivery = _asInt(data['deliveryFareVnd']);
  final total = _asInt(data['totalVnd']);
  if (id is! String ||
      id.isEmpty ||
      status is! String ||
      subtotal == null ||
      delivery == null ||
      total == null) {
    throw const ApiException(
      statusCode: 200,
      message: 'Phản hồi không hợp lệ',
      errorCode: 'INVALID_RESPONSE',
    );
  }
  return PlacedFoodOrder(
    id: id,
    status: status,
    subtotalVnd: subtotal,
    deliveryFareVnd: delivery,
    totalVnd: total,
    lines: _decodeLines(data['lines']),
  );
}

List<FoodOrderLine> _decodeLines(Object? raw) {
  if (raw is! List) {
    return const [];
  }
  final lines = <FoodOrderLine>[];
  for (final item in raw) {
    final map = asJsonMap(item);
    if (map == null) {
      continue;
    }
    final itemId = map['itemId'];
    final name = map['name'];
    final unit = _asInt(map['unitPriceVnd']);
    final quantity = _asInt(map['quantity']);
    if (itemId is String &&
        name is String &&
        unit != null &&
        quantity != null) {
      lines.add(
        FoodOrderLine(
          itemId: itemId,
          name: name,
          unitPriceVnd: unit,
          quantity: quantity,
        ),
      );
    }
  }
  return List.unmodifiable(lines);
}

Object? _successPayload(Object? body) {
  final root = asJsonMap(body);
  if (root == null) {
    throw const ApiException(
      statusCode: 0,
      message: 'Phản hồi không hợp lệ',
      errorCode: 'INVALID_RESPONSE',
    );
  }
  if (root['success'] != true) {
    throw errorFromEnvelope(root, statusCode: _asInt(root['statusCode']) ?? 0);
  }
  if (!root.containsKey('data') || root['data'] == null) {
    throw const ApiException(
      statusCode: 200,
      message: 'Phản hồi không hợp lệ',
      errorCode: 'INVALID_RESPONSE',
    );
  }
  return root['data'];
}

int? _asInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num && value == value.roundToDouble()) {
    return value.toInt();
  }
  return null;
}

double? _asDouble(Object? value) {
  if (value is double) {
    return value;
  }
  if (value is num) {
    return value.toDouble();
  }
  return null;
}

typedef DioFoodClient = DioFoodRemoteDataSource;
