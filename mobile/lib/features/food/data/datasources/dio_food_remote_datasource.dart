import 'package:dio/dio.dart';

import '../../../../core/network/api_envelope.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/api_paths.dart';
import '../../../../core/network/dio_mapper.dart';
import '../../domain/entities/food_models.dart';
import '../../../merchant/domain/entities/merchant_menu_models.dart';
import '../models/place_food_order_body.dart';
import 'food_remote_datasource.dart';
import '../../../../core/maps/route_geometry.dart';

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
  Future<MerchantOrderUpdate> rejectOrder({
    required String accessToken,
    required String orderId,
    required FoodRejectReason reason,
    String? note,
  }) {
    return _send(
      () => dio.post<Object?>(
        ApiPaths.foodOrderReject(orderId),
        data: {'reasonCode': reason.wire, 'note': ?note},
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
  Future<ClaimedFoodDelivery> advanceDelivery({
    required String accessToken,
    required String orderId,
    required FoodDeliveryAction action,

    /// DEC-PROD-036: handover code (pickup) or delivery code (deliver).
    String? code,

    /// Why the delivery failed (FOOD_FAIL_REASONS) and the note for OTHER.
    String? failReason,
    String? failNote,
  }) {
    return _send(
      () => dio.post<Object?>(
        ApiPaths.foodOrderDeliveryAction(orderId, action.pathSegment),
        data: switch ((action, code)) {
          (FoodDeliveryAction.pickup, final String c) => {'handoverCode': c},
          (FoodDeliveryAction.deliver, final String c) => {'deliveryCode': c},
          // The server requires a reason to mark FAILED.
          (FoodDeliveryAction.fail, _) => {
            'reasonCode': failReason ?? 'OTHER',
            if (failNote != null && failNote.trim().isNotEmpty)
              'note': failNote.trim(),
          },
          _ => null,
        },
        options: _auth(accessToken),
      ),
      decodeClaimedFoodDelivery,
    );
  }

  @override
  Future<FoodOrderChange> proposeOrderChange({
    required String accessToken,
    required String orderId,
    required FoodOrderChangeReason reason,
    required Map<String, int> quantities,
    String? note,
  }) {
    final trimmed = note?.trim();
    return _send(
      () => dio.post<Object?>(
        ApiPaths.foodOrderChanges(orderId),
        data: {
          'reasonCode': reason.wire,
          if (trimmed != null && trimmed.isNotEmpty) 'note': trimmed,
          'lines': [
            for (final entry in quantities.entries)
              {'lineId': entry.key, 'toQuantity': entry.value},
          ],
        },
        options: _auth(accessToken),
      ),
      (body) {
        final change = decodeFoodOrderChange(
          asJsonMap(_successPayload(body))?['change'],
        );
        if (change == null) {
          throw const ApiException(
            statusCode: 200,
            message: 'Invalid response',
            errorCode: 'INVALID_RESPONSE',
          );
        }
        return change;
      },
    );
  }

  @override
  Future<FoodOrderDetail> answerOrderChange({
    required String accessToken,
    required String orderId,
    required String changeId,
    required bool accept,
  }) {
    return _send(
      () => dio.post<Object?>(
        ApiPaths.foodOrderChangeAnswer(
          orderId,
          changeId,
          accept ? 'accept' : 'reject',
        ),
        options: _auth(accessToken),
      ),
      (body) => decodeFoodOrderDetail({
        'success': true,
        'data': asJsonMap(_successPayload(body))?['order'],
      }),
    );
  }

  @override
  Future<ClaimedFoodDelivery> cancelOrder({
    required String accessToken,
    required String orderId,
  }) {
    return _send(
      () => dio.post<Object?>(
        ApiPaths.foodOrderCancel(orderId),
        options: _auth(accessToken),
      ),
      decodeClaimedFoodDelivery,
    );
  }

  @override
  Future<List<FoodStoreSummary>> listStores(
    String accessToken, {
    double? lat,
    double? lng,
    String? search,
  }) {
    final hasGeo = lat != null && lng != null;
    return _send(
      () => dio.get<Object?>(
        ApiPaths.foodStores,
        queryParameters: {
          if (hasGeo) ...{'lat': lat, 'lng': lng, 'sort_by': 'distance'},
          // QA C3 — name search runs on the server, not on the loaded page.
          if (search != null && search.trim().isNotEmpty)
            'search': search.trim(),
        },
        options: _auth(accessToken),
      ),
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
  Future<FoodStoreDetail> updateStoreHours({
    required String accessToken,
    required StoreSchedule schedule,
  }) {
    return _send(
      () => dio.put<Object?>(
        ApiPaths.foodMerchantStoreHours,
        data: {
          'weekly': [for (final day in schedule.weekly) day.toJson()],
          'closures': [for (final day in schedule.closures) day.toJson()],
          'lastOrderMinutes': schedule.lastOrderMinutes,
        },
        options: _auth(accessToken),
      ),
      decodeFoodStoreDetail,
    );
  }

  @override
  Future<FoodStoreDetail> updateStoreProfile({
    required String accessToken,
    String? name,
    String? category,
    int? minOrderVnd,
    String? description,
  }) {
    return _send(
      () => dio.patch<Object?>(
        ApiPaths.foodMerchantStoreProfile,
        data: {
          'name': ?name,
          'category': ?category,
          'minOrderVnd': ?minOrderVnd,
          'description': ?description,
        },
        options: _auth(accessToken),
      ),
      decodeFoodStoreDetail,
    );
  }

  @override
  Future<FoodStoreDetail> uploadStoreLogo({
    required String accessToken,
    required String contentBase64,
    String? contentType,
    bool cover = false,
  }) {
    return _send(
      () => dio.post<Object?>(
        cover
            ? ApiPaths.foodMerchantStoreCover
            : ApiPaths.foodMerchantStoreLogo,
        data: {'contentBase64': contentBase64, 'contentType': ?contentType},
        options: _auth(accessToken),
      ),
      decodeFoodStoreDetail,
    );
  }

  @override
  Future<FoodStoreDetail> clearStoreLogo({
    required String accessToken,
    bool cover = false,
  }) {
    return _send(
      () => dio.delete<Object?>(
        cover
            ? ApiPaths.foodMerchantStoreCover
            : ApiPaths.foodMerchantStoreLogo,
        options: _auth(accessToken),
      ),
      decodeFoodStoreDetail,
    );
  }

  @override
  Future<FoodStoreDetail> updateStoreLocation({
    required String accessToken,
    required double lat,
    required double lng,
    String? addressLabel,
  }) {
    return _send(
      () => dio.patch<Object?>(
        ApiPaths.foodMerchantStoreLocation,
        data: {'lat': lat, 'lng': lng, 'addressLabel': addressLabel},
        options: _auth(accessToken),
      ),
      decodeFoodStoreDetail,
    );
  }

  @override
  Future<FoodStoreDetail> updateStoreServiceMode({
    required String accessToken,
    required StoreServiceMode mode,
    int? resumeAfterMinutes,
    int? busyExtraMinutes,
  }) {
    return _send(
      () => dio.patch<Object?>(
        ApiPaths.foodMerchantStoreStatus,
        data: {
          'mode': mode.wire,
          if (mode != StoreServiceMode.open && resumeAfterMinutes != null)
            'resumeAfterMinutes': resumeAfterMinutes,
          'busyExtraMinutes': ?busyExtraMinutes,
        },
        options: _auth(accessToken),
      ),
      decodeFoodStoreDetail,
    );
  }

  @override
  Future<FoodStoreDetail> updateStoreAcceptSettings({
    required String accessToken,
    required StoreAcceptSettings settings,
    required int lastOrderMinutes,
  }) {
    return _send(
      () => dio.put<Object?>(
        ApiPaths.foodMerchantStoreAcceptSettings,
        data: {
          'acceptMode': settings.acceptMode.wire,
          'maxActiveOrders': settings.maxActiveOrders,
          'defaultPrepMinutes': settings.defaultPrepMinutes,
          'lastOrderMinutes': lastOrderMinutes,
        },
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
    bool? available,
    String? description,
    int? prepMinutes,
    String? imageUrl,
    String? menuCategoryId,
    int? originalPriceVnd,
    bool clearOriginalPrice = false,
  }) {
    return _send(
      () => dio.patch<Object?>(
        ApiPaths.foodMerchantItem(itemId),
        data: {
          'name': ?name,
          'priceVnd': ?priceVnd,
          'available': ?available,
          'description': ?description,
          'prepMinutes': ?prepMinutes,
          'imageUrl': ?imageUrl,
          'menuCategoryId': ?menuCategoryId,
          if (clearOriginalPrice)
            'originalPriceVnd': null
          else
            'originalPriceVnd': ?originalPriceVnd,
        },
        options: _auth(accessToken),
      ),
      decodeFoodMenuItem,
    );
  }

  @override
  Future<FoodMenuItem> replaceMerchantItemOptions({
    required String accessToken,
    required String itemId,
    required List<FoodOptionGroup> groups,
  }) {
    return _send(
      () => dio.put<Object?>(
        ApiPaths.foodMerchantItemOptions(itemId),
        data: {'groups': encodeFoodOptionGroups(groups)},
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
  Future<List<MerchantMenuCategory>> listMerchantMenuCategories(
    String accessToken,
  ) {
    return _send(
      () => dio.get<Object?>(
        ApiPaths.foodMerchantMenuCategories,
        options: _auth(accessToken),
      ),
      decodeMerchantMenuCategories,
    );
  }

  @override
  Future<MerchantMenuCategory> createMerchantMenuCategory({
    required String accessToken,
    required String name,
    String? description,
  }) {
    return _send(
      () => dio.post<Object?>(
        ApiPaths.foodMerchantMenuCategories,
        data: {'name': name, 'description': ?description},
        options: _auth(accessToken),
      ),
      decodeMerchantMenuCategoryRequired,
    );
  }

  @override
  Future<MerchantMenuCategory> updateMerchantMenuCategory({
    required String accessToken,
    required String categoryId,
    required String name,
    String? description,
  }) {
    return _send(
      () => dio.patch<Object?>(
        ApiPaths.foodMerchantMenuCategory(categoryId),
        data: {'name': name, 'description': ?description},
        options: _auth(accessToken),
      ),
      decodeMerchantMenuCategoryRequired,
    );
  }

  @override
  Future<void> deleteMerchantMenuCategory({
    required String accessToken,
    required String categoryId,
  }) {
    return _send<void>(
      () => dio.delete<Object?>(
        ApiPaths.foodMerchantMenuCategory(categoryId),
        options: _auth(accessToken),
      ),
      (_) {},
    );
  }

  @override
  Future<MerchantHistoryPage> listMerchantOrderHistory({
    required String accessToken,
    int page = 1,
    int limit = 20,
    String? tab,
    String? q,
  }) {
    return _send(
      () => dio.get<Object?>(
        ApiPaths.foodMerchantOrdersHistory,
        queryParameters: {'page': page, 'limit': limit, 'tab': ?tab, 'q': ?q},
        options: _auth(accessToken),
      ),
      decodeMerchantHistoryPage,
    );
  }

  @override
  Future<List<MerchantMenuCategory>> reorderMerchantMenuCategories({
    required String accessToken,
    required List<String> orderedIds,
  }) {
    return _send(
      () => dio.put<Object?>(
        ApiPaths.foodMerchantMenuCategoriesReorder,
        data: {'orderedIds': orderedIds},
        options: _auth(accessToken),
      ),
      decodeMerchantMenuCategories,
    );
  }

  @override
  Future<FoodMenuItem> uploadMerchantItemImage({
    required String accessToken,
    required String itemId,
    required String contentBase64,
    String? contentType,
  }) {
    return _send(
      () => dio.post<Object?>(
        ApiPaths.foodMerchantItemImage(itemId),
        data: {'contentBase64': contentBase64, 'contentType': ?contentType},
        options: _auth(accessToken),
      ),
      decodeFoodMenuItem,
    );
  }

  @override
  Future<FoodMenuItem> clearMerchantItemImage({
    required String accessToken,
    required String itemId,
  }) {
    return _send(
      () => dio.delete<Object?>(
        ApiPaths.foodMerchantItemImage(itemId),
        options: _auth(accessToken),
      ),
      decodeFoodMenuItem,
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
      message: 'Invalid response',
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
  final storeName = map['storeName'];
  final storeAddress = map['storeAddress'];
  final cleanName = storeName is String && storeName.trim().isNotEmpty
      ? storeName.trim()
      : null;
  final cleanAddress = storeAddress is String && storeAddress.trim().isNotEmpty
      ? storeAddress.trim()
      : null;
  return ReadyFoodJob(
    id: id,
    storeId: storeId,
    storeName: cleanName,
    storeAddress: cleanAddress,
    deliveryFareVnd: deliveryFareVnd,
    subtotalVnd: subtotalVnd,
    totalVnd: totalVnd,
    dropoff: dropoff,
    lineCount: lineCount,
    pickup: decodeFoodPickupPoint(
      map['pickup'] ?? map['store'],
      fallbackLabel: cleanAddress ?? cleanName ?? '',
    ),
    route: RouteGeometry.tryParse(map['route']),
  );
}

/// `pickup {lat,lng,label?}` (or the legacy `store {lat,lng}`) as a point.
FoodDropoff? decodeFoodPickupPoint(Object? raw, {String fallbackLabel = ''}) {
  final map = asJsonMap(raw);
  if (map == null) {
    return null;
  }
  final lat = _asDouble(map['lat']);
  final lng = _asDouble(map['lng']);
  if (lat == null || lng == null) {
    return null;
  }
  final label = map['label'];
  return FoodDropoff(
    lat: lat,
    lng: lng,
    label: label is String && label.trim().isNotEmpty
        ? label.trim()
        : fallbackLabel,
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
      message: 'Invalid response',
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
    customerName: _nonEmpty(map['customerName']),
    driverName: _nonEmpty(map['driverName']),
  );
}

String? _nonEmpty(Object? value) =>
    value is String && value.trim().isNotEmpty ? value.trim() : null;

MerchantOrderUpdate decodeMerchantOrderUpdate(Object? body) {
  final data = asJsonMap(readSuccessPayload(body));
  if (data == null) {
    throw const ApiException(
      statusCode: 200,
      message: 'Invalid response',
      errorCode: 'INVALID_RESPONSE',
    );
  }
  final id = data['id'];
  final status = data['status'];
  if (id is! String || id.isEmpty || status is! String || status.isEmpty) {
    throw const ApiException(
      statusCode: 200,
      message: 'Invalid response',
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
      message: 'Invalid response',
      errorCode: 'INVALID_RESPONSE',
    );
  }
  final id = data['id'];
  final status = data['status'];
  if (id is! String || id.isEmpty || status is! String || status.isEmpty) {
    throw const ApiException(
      statusCode: 200,
      message: 'Invalid response',
      errorCode: 'INVALID_RESPONSE',
    );
  }
  return ClaimedFoodDelivery(id: id, status: status);
}

List<FoodStoreSummary> decodeFoodStoreList(Object? body) {
  // Prefer paginated `{ items: [...] }`; keep bare array for older clients/tests.
  final data = _successPayload(body);
  final list = data is List
      ? data
      : (asJsonMap(data)?['items'] is List
            ? asJsonMap(data)!['items'] as List
            : null);
  if (list == null) {
    throw const ApiException(
      statusCode: 200,
      message: 'Invalid response',
      errorCode: 'INVALID_RESPONSE',
    );
  }
  final stores = <FoodStoreSummary>[];
  for (final item in list) {
    final map = asJsonMap(item);
    if (map == null) {
      continue;
    }
    final id = map['id'];
    final name = map['name'];
    if (id is String && id.isNotEmpty && name is String && name.isNotEmpty) {
      final category = map['category'];
      final distance = map['distanceKm'];
      final rating = asJsonMap(map['rating']);
      stores.add(
        FoodStoreSummary(
          id: id,
          name: name,
          category: category is String && category.isNotEmpty ? category : null,
          distanceKm: distance is num ? distance.toDouble() : null,
          closedReason: StoreClosedReason.fromWire(map['closedReason']),
          imageUrl: map['imageUrl'] is String
              ? map['imageUrl'] as String
              : null,
          logoUrl:
              map['logoUrl'] is String && (map['logoUrl'] as String).isNotEmpty
              ? map['logoUrl'] as String
              : null,
          ratingAverage: _asDouble(rating?['average']),
          ratingCount: rating == null ? null : (_asInt(rating['count']) ?? 0),
          etaMinutes: _asInt(map['etaMinutes']),
          deliveryFeeFromVnd: _asInt(map['deliveryFeeFromVnd']),
          offers: decodeStoreOffers(map['offers']),
          minOrderVnd: _asInt(map['minOrderVnd']) ?? 0,
          featuredItems: _decodeFeaturedItems(map['featuredItems']),
        ),
      );
    }
  }
  return List.unmodifiable(stores);
}

DateTime? _asLocalTime(Object? raw) =>
    raw is String ? DateTime.tryParse(raw)?.toLocal() : null;

/// Strike-through price only while it is above the selling price.
int? _shownOriginalPrice(int price, Object? raw) {
  final original = _asInt(raw);
  return original != null && original > price ? original : null;
}

List<FoodFeaturedItem> _decodeFeaturedItems(Object? raw) {
  if (raw is! List) return const [];
  final out = <FoodFeaturedItem>[];
  for (final row in raw) {
    final map = asJsonMap(row);
    if (map == null) continue;
    final id = map['id'];
    final name = map['name'];
    final price = _asInt(map['priceVnd']);
    if (id is! String || id.isEmpty || name is! String || price == null) {
      continue;
    }
    final image = map['imageUrl'];
    out.add(
      FoodFeaturedItem(
        id: id,
        name: name,
        priceVnd: price,
        originalPriceVnd: _shownOriginalPrice(price, map['originalPriceVnd']),
        imageUrl: image is String && image.isNotEmpty ? image : null,
        soldCount: _asInt(map['soldCount']) ?? 0,
        addedAt: _asLocalTime(map['addedAt']),
      ),
    );
  }
  return List.unmodifiable(out);
}

/// Store offers on list cards and the store page; malformed rows are skipped.
List<StoreOffer> decodeStoreOffers(Object? raw) {
  if (raw is! List) return const [];
  final out = <StoreOffer>[];
  for (final row in raw) {
    final map = asJsonMap(row);
    if (map == null) continue;
    final id = map['id'];
    final code = map['code'];
    final name = map['name'];
    final value = _asInt(map['discountValue']);
    final ends = map['endsAt'] is String
        ? DateTime.tryParse(map['endsAt'] as String)
        : null;
    final kind = switch (map['discountType']) {
      'FIXED_AMOUNT' => StoreOfferKind.fixedAmount,
      'PERCENTAGE' => StoreOfferKind.percentage,
      _ => null,
    };
    if (id is! String ||
        code is! String ||
        name is! String ||
        value == null ||
        value <= 0 ||
        ends == null ||
        kind == null) {
      continue;
    }
    out.add(
      StoreOffer(
        id: id,
        code: code,
        name: name,
        kind: kind,
        discountValue: value,
        maxDiscountVnd: _asInt(map['maxDiscountVnd']),
        minOrderVnd: _asInt(map['minOrderVnd']) ?? 0,
        endsAt: ends.toLocal(),
        remainingUses: _asInt(map['remainingUses']),
      ),
    );
  }
  return List.unmodifiable(out);
}

List<FoodMenuSection> _decodeMenuSections(Object? raw) {
  if (raw is! List) return const [];
  return List.unmodifiable([
    for (final row in raw)
      if (asJsonMap(row) case final map?)
        if (map['id'] is String && map['name'] is String)
          FoodMenuSection(id: map['id'] as String, name: map['name'] as String),
  ]);
}

FoodStoreDetail decodeFoodStoreDetail(Object? body) {
  final data = asJsonMap(_successPayload(body));
  if (data == null) {
    throw const ApiException(
      statusCode: 200,
      message: 'Invalid response',
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
      message: 'Invalid response',
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
  final category = data['category'];
  final addressLabel = data['addressLabel'];
  final logoUrl = data['logoUrl'];
  final coverUrl = data['coverUrl'];
  final description = data['description'];
  final until = data['serviceModeUntil'];
  return FoodStoreDetail(
    id: id,
    name: name,
    items: List.unmodifiable(items),
    category: category is String ? category : null,
    addressLabel: addressLabel is String ? addressLabel : null,
    logoUrl: logoUrl is String && logoUrl.isNotEmpty ? logoUrl : null,
    coverUrl: coverUrl is String && coverUrl.isNotEmpty ? coverUrl : null,
    description: description is String && description.trim().isNotEmpty
        ? description.trim()
        : null,
    lat: _asDouble(data['lat']),
    lng: _asDouble(data['lng']),
    serviceMode: StoreServiceMode.fromWire(data['serviceMode']),
    serviceModeUntil: until is String ? DateTime.tryParse(until) : null,
    closedReason: StoreClosedReason.fromWire(data['closedReason']),
    schedule: decodeStoreSchedule(data['schedule']),
    acceptSettings: decodeStoreAcceptSettings(data['acceptSettings']),
    estimatedPrepMinutes: _asInt(data['estimatedPrepMinutes']),
    offers: decodeStoreOffers(data['offers']),
    menuSections: _decodeMenuSections(data['menuSections']),
    minOrderVnd: _asInt(data['minOrderVnd']) ?? 0,
  );
}

/// M022 settings (merchant catalog only); missing → backend defaults.
StoreAcceptSettings decodeStoreAcceptSettings(Object? raw) {
  final data = asJsonMap(raw);
  if (data == null) {
    return const StoreAcceptSettings();
  }
  return StoreAcceptSettings(
    acceptMode: StoreAcceptMode.fromWire(data['acceptMode']),
    maxActiveOrders: _asInt(data['maxActiveOrders']),
    defaultPrepMinutes: _asInt(data['defaultPrepMinutes']) ?? 15,
    busyExtraMinutes: _asInt(data['busyExtraMinutes']) ?? 15,
  );
}

/// M023 schedule block; missing or malformed → always open (older backends).
StoreSchedule decodeStoreSchedule(Object? raw) {
  final map = asJsonMap(raw);
  if (map == null) {
    return const StoreSchedule();
  }
  final weekly = <StoreDayHours>[];
  final rawWeekly = map['weekly'];
  if (rawWeekly is List) {
    for (final entry in rawWeekly) {
      final row = asJsonMap(entry);
      final weekday = row?['weekday'];
      final opensAt = row?['opensAt'];
      final closesAt = row?['closesAt'];
      if (weekday is int && opensAt is String && closesAt is String) {
        weekly.add(
          StoreDayHours(weekday: weekday, opensAt: opensAt, closesAt: closesAt),
        );
      }
    }
  }
  final closures = <StoreClosureDay>[];
  final rawClosures = map['closures'];
  if (rawClosures is List) {
    for (final entry in rawClosures) {
      final row = asJsonMap(entry);
      final date = row?['date'];
      final note = row?['note'];
      if (date is String) {
        closures.add(
          StoreClosureDay(date: date, note: note is String ? note : null),
        );
      }
    }
  }
  final hoursConfigured = map['hoursConfigured'];
  final lastOrder = map['lastOrderMinutes'];
  return StoreSchedule(
    hoursConfigured: hoursConfigured == true,
    lastOrderMinutes: lastOrder is int ? lastOrder : 0,
    weekly: List.unmodifiable(weekly),
    closures: List.unmodifiable(closures),
  );
}

FoodMenuItem decodeFoodMenuItem(Object? body) {
  final item = _menuItem(_successPayload(body));
  if (item == null) {
    throw const ApiException(
      statusCode: 200,
      message: 'Invalid response',
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
    description: map['description'] is String
        ? map['description'] as String
        : null,
    prepMinutes: _asInt(map['prepMinutes']),
    imageUrl: map['imageUrl'] is String ? map['imageUrl'] as String : null,
    imageUrls: [
      if (map['imageUrls'] is List)
        for (final u in map['imageUrls'] as List)
          if (u is String && u.isNotEmpty) u,
    ],
    soldCount: map['soldCount'] is int ? map['soldCount'] as int : 0,
    menuCategoryId: map['menuCategoryId'] is String
        ? map['menuCategoryId'] as String
        : null,
    optionGroups: decodeFoodOptionGroups(map['optionGroups']),
    originalPriceVnd: _shownOriginalPrice(price, map['originalPriceVnd']),
    addedAt: _asLocalTime(map['addedAt']),
  );
}

/// DEC-PROD-036: only a well-formed 4-digit code is shown.
String? _fourDigits(Object? value) =>
    value is String && RegExp(r'^\d{4}$').hasMatch(value) ? value : null;

FoodOrderDetail decodeFoodOrderDetail(Object? body) {
  final data = asJsonMap(_successPayload(body));
  if (data == null) {
    throw const ApiException(
      statusCode: 200,
      message: 'Invalid response',
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
      message: 'Invalid response',
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
    storeName: data['storeName'] is String ? data['storeName'] as String : null,
    storeId: data['storeId'] is String ? data['storeId'] as String : null,
    assignedDriverId: data['assignedDriverId'] is String
        ? data['assignedDriverId'] as String
        : null,
    discountVnd: _asInt(data['discountVnd']) ?? 0,
    cancelReason: decodeFoodCancelReason(data['cancelReason']),
    prepMinutes: _asInt(data['prepMinutes']),
    deliveryCode: _fourDigits(data['deliveryCode']),
    handoverCode: _fourDigits(data['handoverCode']),
    estimatedReadyAt: data['estimatedReadyAt'] is String
        ? DateTime.tryParse(data['estimatedReadyAt'] as String)
        : null,
    pickup: decodeFoodPickupPoint(
      data['pickup'] ?? data['store'],
      fallbackLabel:
          data['storeAddress'] is String &&
              (data['storeAddress'] as String).trim().isNotEmpty
          ? (data['storeAddress'] as String).trim()
          : (data['storeName'] is String ? (data['storeName'] as String) : ''),
    ),
    route: RouteGeometry.tryParse(data['route']),
    approachRoute: RouteGeometry.tryParse(data['approachRoute']),
    pendingChange: decodeFoodOrderChange(data['pendingChange']),
  );
}

PlacedFoodOrder decodePlacedFoodOrder(Object? body) {
  final data = asJsonMap(_successPayload(body));
  if (data == null) {
    throw const ApiException(
      statusCode: 200,
      message: 'Invalid response',
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
      message: 'Invalid response',
      errorCode: 'INVALID_RESPONSE',
    );
  }
  return PlacedFoodOrder(
    id: id,
    status: status,
    subtotalVnd: subtotal,
    deliveryFareVnd: delivery,
    totalVnd: total,
    discountVnd: _asInt(data['discountVnd']) ?? 0,
    voucherCode: data['voucherCode'] is String
        ? data['voucherCode'] as String
        : null,
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
          id: map['id'] is String ? map['id'] as String : null,
          itemId: itemId,
          name: name,
          unitPriceVnd: unit,
          quantity: quantity,
          imageUrl: map['imageUrl'] is String
              ? map['imageUrl'] as String
              : null,
          options: decodeFoodLineOptions(map['options']),
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
      message: 'Invalid response',
      errorCode: 'INVALID_RESPONSE',
    );
  }
  if (root['success'] != true) {
    throw errorFromEnvelope(root, statusCode: _asInt(root['statusCode']) ?? 0);
  }
  if (!root.containsKey('data') || root['data'] == null) {
    throw const ApiException(
      statusCode: 200,
      message: 'Invalid response',
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

FoodCancelReason? decodeFoodCancelReason(Object? raw) {
  final map = asJsonMap(raw);
  if (map == null) return null;
  final note = map['note'];
  return FoodCancelReason(
    reason: FoodRejectReason.fromWire(map['code']),
    note: note is String && note.trim().isNotEmpty ? note.trim() : null,
  );
}

List<MerchantMenuCategory> decodeMerchantMenuCategories(Object? body) {
  final data = _successPayload(body);
  final list = data is List
      ? data
      : (asJsonMap(data)?['items'] is List
            ? asJsonMap(data)!['items'] as List
            : null);
  if (list == null) {
    throw const ApiException(
      statusCode: 200,
      message: 'Invalid response',
      errorCode: 'INVALID_RESPONSE',
    );
  }
  final out = <MerchantMenuCategory>[];
  for (final row in list) {
    final cat = decodeMerchantMenuCategory(row);
    if (cat != null) out.add(cat);
  }
  return List.unmodifiable(out);
}

MerchantMenuCategory? decodeMerchantMenuCategory(Object? raw) {
  final map = asJsonMap(raw);
  if (map == null) return null;
  final id = map['id'];
  final name = map['name'];
  final position = map['position'];
  if (id is! String || name is! String || name.isEmpty) return null;
  return MerchantMenuCategory(
    id: id,
    name: name,
    description: map['description'] is String
        ? map['description'] as String
        : null,
    position: position is int ? position : int.tryParse('$position') ?? 0,
    itemCount: map['itemCount'] is int
        ? map['itemCount'] as int
        : int.tryParse('${map['itemCount']}') ?? 0,
  );
}

MerchantMenuCategory decodeMerchantMenuCategoryRequired(Object? body) {
  final row = decodeMerchantMenuCategory(_successPayload(body));
  if (row == null) {
    throw const ApiException(
      statusCode: 200,
      message: 'Invalid response',
      errorCode: 'INVALID_RESPONSE',
    );
  }
  return row;
}

MerchantHistoryPage decodeMerchantHistoryPage(Object? body) {
  final data = asJsonMap(_successPayload(body));
  if (data == null) {
    throw const ApiException(
      statusCode: 200,
      message: 'Invalid response',
      errorCode: 'INVALID_RESPONSE',
    );
  }
  final rawItems = data['items'];
  final items = <MerchantHistoryOrder>[];
  if (rawItems is List) {
    for (final row in rawItems) {
      final map = asJsonMap(row);
      if (map == null) continue;
      final id = map['id'];
      final status = map['status'];
      if (id is! String || status is! String) continue;
      items.add(
        MerchantHistoryOrder(
          id: id,
          status: status,
          subtotalVnd: _asInt(map['subtotalVnd']) ?? 0,
          totalVnd: _asInt(map['totalVnd']) ?? 0,
          createdAt:
              DateTime.tryParse('${map['createdAt']}') ??
              DateTime.fromMillisecondsSinceEpoch(0),
          finishedAt:
              DateTime.tryParse('${map['finishedAt']}') ??
              DateTime.fromMillisecondsSinceEpoch(0),
          customerName: map['customerName'] is String
              ? map['customerName'] as String
              : null,
          lineSummary: map['lineSummary'] is String
              ? map['lineSummary'] as String
              : '',
        ),
      );
    }
  }
  return MerchantHistoryPage(
    items: items,
    page: _asInt(data['page']) ?? 1,
    limit: _asInt(data['limit']) ?? 20,
    total: _asInt(data['total']) ?? items.length,
    deliveredCount: _asInt(data['deliveredCount']) ?? 0,
    deliveredRevenueVnd: _asInt(data['deliveredRevenueVnd']) ?? 0,
  );
}

/// `{id,status,reasonCode,note,lines,…,expiresAt}`; null when absent/invalid.
FoodOrderChange? decodeFoodOrderChange(Object? raw) {
  final map = asJsonMap(raw);
  if (map == null) return null;
  final id = map['id'];
  final status = map['status'];
  final expiresAt = map['expiresAt'] is String
      ? DateTime.tryParse(map['expiresAt'] as String)
      : null;
  final oldSubtotal = _asInt(map['oldSubtotalVnd']);
  final newSubtotal = _asInt(map['newSubtotalVnd']);
  final newTotal = _asInt(map['newTotalVnd']);
  if (id is! String ||
      status is! String ||
      expiresAt == null ||
      oldSubtotal == null ||
      newSubtotal == null ||
      newTotal == null) {
    return null;
  }
  final lines = <FoodOrderChangeLine>[];
  final rawLines = map['lines'];
  if (rawLines is List) {
    for (final entry in rawLines) {
      final line = asJsonMap(entry);
      final lineId = line?['lineId'];
      final name = line?['name'];
      final unit = _asInt(line?['unitPriceVnd']);
      final from = _asInt(line?['fromQuantity']);
      final to = _asInt(line?['toQuantity']);
      if (lineId is String &&
          name is String &&
          unit != null &&
          from != null &&
          to != null) {
        lines.add(
          FoodOrderChangeLine(
            lineId: lineId,
            name: name,
            unitPriceVnd: unit,
            fromQuantity: from,
            toQuantity: to,
          ),
        );
      }
    }
  }
  final note = map['note'];
  return FoodOrderChange(
    id: id,
    status: status,
    reason: FoodOrderChangeReason.fromWire(map['reasonCode']),
    note: note is String && note.trim().isNotEmpty ? note.trim() : null,
    lines: List.unmodifiable(lines),
    oldSubtotalVnd: oldSubtotal,
    newSubtotalVnd: newSubtotal,
    newDiscountVnd: _asInt(map['newDiscountVnd']) ?? 0,
    newTotalVnd: newTotal,
    expiresAt: expiresAt,
  );
}
