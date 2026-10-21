import 'package:dio/dio.dart';

import '../../../../core/network/api_envelope.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/api_paths.dart';
import '../../../../core/network/dio_mapper.dart';
import '../../domain/entities/inbox_notification.dart';

abstract interface class InboxRemoteDataSource {
  Future<InboxPage> list({required String accessToken, int page, int limit});

  Future<void> markRead({required String accessToken, required String id});

  Future<int> markAllRead({required String accessToken});
}

class DioInboxRemoteDataSource implements InboxRemoteDataSource {
  DioInboxRemoteDataSource({required this.dio});

  final Dio dio;

  Options _auth(String token) =>
      Options(headers: {'Authorization': 'Bearer $token'});

  @override
  Future<InboxPage> list({
    required String accessToken,
    int page = 1,
    int limit = 30,
  }) async {
    try {
      final response = await dio.get<Object?>(
        ApiPaths.meNotifications,
        queryParameters: {'page': page, 'limit': limit},
        options: _auth(accessToken),
      );
      return decodeInboxPage(response.data);
    } on DioException catch (error) {
      throw apiExceptionFromDio(error);
    }
  }

  @override
  Future<void> markRead({
    required String accessToken,
    required String id,
  }) async {
    try {
      await dio.post<Object?>(
        ApiPaths.meNotificationRead(id),
        options: _auth(accessToken),
      );
    } on DioException catch (error) {
      throw apiExceptionFromDio(error);
    }
  }

  @override
  Future<int> markAllRead({required String accessToken}) async {
    try {
      final response = await dio.post<Object?>(
        ApiPaths.meNotificationsReadAll,
        options: _auth(accessToken),
      );
      final updated = requireSuccessData(response.data)['updated'];
      return updated is num ? updated.toInt() : 0;
    } on DioException catch (error) {
      throw apiExceptionFromDio(error);
    }
  }
}

InboxPage decodeInboxPage(Object? body) {
  final data = requireSuccessData(body);
  final rawItems = data['items'];
  if (rawItems is! List) {
    throw const ApiException(
      statusCode: 200,
      message: 'Invalid response',
      errorCode: 'INVALID_RESPONSE',
    );
  }
  final items = <InboxNotification>[
    for (final raw in rawItems) ?_decodeItem(raw),
  ];
  final total = data['total'];
  final unread = data['unreadCount'];
  return InboxPage(
    items: List.unmodifiable(items),
    total: total is num ? total.toInt() : items.length,
    unreadCount: unread is num
        ? unread.toInt()
        : items.where((item) => !item.read).length,
  );
}

InboxNotification? _decodeItem(Object? raw) {
  final map = asJsonMap(raw);
  if (map == null) {
    return null;
  }
  final id = map['id'];
  final title = map['title'];
  final body = map['body'];
  final createdAt = DateTime.tryParse('${map['createdAt']}');
  if (id is! String ||
      title is! String ||
      body is! String ||
      createdAt == null) {
    return null;
  }
  final data = asJsonMap(map['data']);
  String? text(String key) {
    final value = data?[key];
    return value is String && value.isNotEmpty ? value : null;
  }

  return InboxNotification(
    id: id,
    category: InboxCategory.fromWire(map['category']),
    title: title,
    body: body,
    read: map['read'] == true || map['readAt'] is String,
    createdAt: createdAt.toLocal(),
    aggregateType: text('aggregateType'),
    aggregateId: text('aggregateId'),
    status: text('status'),
  );
}

/// Offline/mock inbox used by tests and `useMockData` builds.
class FakeInboxRemoteDataSource implements InboxRemoteDataSource {
  FakeInboxRemoteDataSource({List<InboxNotification>? seed, DateTime? now})
    : _items = [...(seed ?? _defaultSeed(now ?? DateTime.now()))];

  final List<InboxNotification> _items;

  static List<InboxNotification> _defaultSeed(DateTime now) => [
    InboxNotification(
      id: 'n1',
      category: InboxCategory.ride,
      title: 'Tài xế đã đến điểm đón',
      body: 'Hãy ra điểm đón và đọc mã cho tài xế.',
      read: false,
      createdAt: now.subtract(const Duration(minutes: 2)),
      aggregateType: 'Ride',
      aggregateId: 'ride-1',
      status: 'DRIVER_ARRIVED',
    ),
    InboxNotification(
      id: 'n2',
      category: InboxCategory.food,
      title: 'Quán đang chuẩn bị món',
      body: 'Đơn của bạn đã được quán xác nhận.',
      read: false,
      createdAt: now.subtract(const Duration(minutes: 14)),
      aggregateType: 'FoodOrder',
      aggregateId: 'food-order-1',
      status: 'PREPARING',
    ),
    InboxNotification(
      id: 'n3',
      category: InboxCategory.promotion,
      title: 'Giảm 20.000đ cho đơn đồ ăn',
      body: 'Nhập DEALGO10 khi thanh toán. Áp dụng đến hết tuần.',
      read: true,
      createdAt: now.subtract(const Duration(days: 1, hours: 2)),
    ),
    InboxNotification(
      id: 'n4',
      category: InboxCategory.ride,
      title: 'Chuyến đi hoàn thành',
      body: 'Cảm ơn bạn đã đi cùng DealGo.',
      read: true,
      createdAt: now.subtract(const Duration(days: 3)),
      aggregateType: 'Ride',
      aggregateId: 'ride-0',
      status: 'COMPLETED',
    ),
  ];

  @override
  Future<InboxPage> list({
    required String accessToken,
    int page = 1,
    int limit = 30,
  }) async {
    final start = (page - 1) * limit;
    final slice = _items.skip(start).take(limit).toList();
    return InboxPage(
      items: List.unmodifiable(slice),
      total: _items.length,
      unreadCount: _items.where((item) => !item.read).length,
    );
  }

  @override
  Future<void> markRead({
    required String accessToken,
    required String id,
  }) async {
    final index = _items.indexWhere((item) => item.id == id);
    if (index >= 0) {
      _items[index] = _items[index].markedRead();
    }
  }

  @override
  Future<int> markAllRead({required String accessToken}) async {
    var updated = 0;
    for (var i = 0; i < _items.length; i++) {
      if (!_items[i].read) {
        _items[i] = _items[i].markedRead();
        updated++;
      }
    }
    return updated;
  }
}
