import 'package:flutter/material.dart' show DateUtils;

import 'package:dio/dio.dart';

import '../../../core/network/api_envelope.dart';
import '../../../core/network/api_paths.dart';
import '../../../core/network/dio_mapper.dart';
import '../domain/driver_history.dart';

class DioDriverHistoryRemoteDataSource implements DriverHistoryRepository {
  DioDriverHistoryRemoteDataSource({required this.dio});

  final Dio dio;

  Options _auth(String token) =>
      Options(headers: {'Authorization': 'Bearer $token'});

  @override
  Future<DriverHistorySummary> summary({required String accessToken}) async {
    try {
      final response = await dio.get<Object?>(
        ApiPaths.driverHistorySummary,
        options: _auth(accessToken),
      );
      return decodeDriverHistorySummary(requireSuccessData(response.data));
    } on DioException catch (error) {
      throw apiExceptionFromDio(error);
    }
  }

  @override
  Future<DriverHistoryPage> list({
    required String accessToken,
    DriverHistoryFilter kind,
    String? cursor,
    int limit = 20,
  }) async {
    try {
      final response = await dio.get<Object?>(
        ApiPaths.driverHistory,
        queryParameters: {
          'limit': limit,
          'kind': kind?.wire ?? 'ALL',
          'cursor': ?cursor,
        },
        options: _auth(accessToken),
      );
      final data = requireSuccessData(response.data);
      final rawItems = data['items'];
      final next = data['nextCursor'];
      return DriverHistoryPage(
        items: [
          if (rawItems is List)
            for (final raw in rawItems) ?decodeDriverHistoryItem(raw),
        ],
        nextCursor: next is String && next.isNotEmpty ? next : null,
      );
    } on DioException catch (error) {
      throw apiExceptionFromDio(error);
    }
  }
}

int _int(Object? raw) => raw is num ? raw.toInt() : 0;

DriverHistoryItem? decodeDriverHistoryItem(Object? raw) {
  final map = asJsonMap(raw);
  if (map == null) {
    return null;
  }
  final kind = DriverJobKind.fromWire(map['kind']);
  final id = map['id'];
  final finishedAt = DateTime.tryParse('${map['finishedAt']}');
  if (kind == null || id is! String || finishedAt == null) {
    return null;
  }
  final stars = map['driverStars'];
  final pickup = map['pickupLabel'];
  final store = map['storeName'];
  final feePercent = map['feePercent'];
  return DriverHistoryItem(
    kind: kind,
    id: id,
    outcome: DriverJobOutcome.fromWire(map['outcome']),
    fareVnd: _int(map['fareVnd']),
    earningsVnd: _int(map['earningsVnd']),
    feeVnd: _int(map['feeVnd']),
    feePercent: feePercent is num ? feePercent.toDouble() : null,
    pickupLabel: pickup is String ? pickup : null,
    dropoffLabel: '${map['dropoffLabel'] ?? ''}',
    storeName: store is String ? store : null,
    finishedAt: finishedAt.toLocal(),
    driverStars: stars is num ? stars.toInt() : null,
  );
}

DriverDaySummary _day(Object? raw) {
  final map = asJsonMap(raw) ?? const <String, Object?>{};
  return DriverDaySummary(
    date: DateTime.tryParse('${map['date']}') ?? DateTime(1970),
    completedJobs: _int(map['completedJobs']),
    grossVnd: _int(map['grossVnd']),
    feeVnd: _int(map['feeVnd']),
    earningsVnd: _int(map['earningsVnd']),
  );
}

DriverHistorySummary decodeDriverHistorySummary(Map<String, Object?> data) {
  final week = asJsonMap(data['week']) ?? const <String, Object?>{};
  final rating = asJsonMap(data['rating']) ?? const <String, Object?>{};
  final days = data['days'];
  final average = rating['average'];
  return DriverHistorySummary(
    today: _day(data['today']),
    days: [
      if (days is List)
        for (final day in days) _day(day),
    ],
    weekCompletedJobs: _int(week['completedJobs']),
    weekCancelledJobs: _int(week['cancelledJobs']),
    weekGrossVnd: _int(week['grossVnd']),
    weekFeeVnd: _int(week['feeVnd']),
    weekEarningsVnd: _int(week['earningsVnd']),
    weekRideEarningsVnd: _int(week['rideEarningsVnd']),
    weekFoodEarningsVnd: _int(week['foodEarningsVnd']),
    ratingAverage: average is num ? average.toDouble() : null,
    ratingCount: _int(rating['count']),
  );
}

/// In-memory history for tests, screenshots and `useMockData`.
class FakeDriverHistoryRemoteDataSource implements DriverHistoryRepository {
  FakeDriverHistoryRemoteDataSource({List<DriverHistoryItem>? seed, this.now})
    : _items = [...?seed]..sort((a, b) => b.finishedAt.compareTo(a.finishedAt));

  final List<DriverHistoryItem> _items;

  /// Fixed clock for tests; defaults to the device clock.
  final DateTime? now;

  /// Throws on the next call (tests of the error state).
  Object? failNext;

  static List<DriverHistoryItem> sample(DateTime now) {
    final today = DateTime(now.year, now.month, now.day, 10, 45);
    return [
      DriverHistoryItem(
        kind: DriverJobKind.ride,
        id: '7d1f0c2a-0000-4000-8000-000000000001',
        outcome: DriverJobOutcome.completed,
        fareVnd: 42000,
        feeVnd: 4200,
        feePercent: 10,
        earningsVnd: 37800,
        pickupLabel: '12 Bạch Đằng, Hải Châu',
        dropoffLabel: 'Sân bay Đà Nẵng',
        finishedAt: today,
        driverStars: 5,
      ),
      DriverHistoryItem(
        kind: DriverJobKind.food,
        id: '7d1f0c2a-0000-4000-8000-000000000002',
        outcome: DriverJobOutcome.completed,
        fareVnd: 18000,
        feeVnd: 1800,
        feePercent: 10,
        earningsVnd: 16200,
        pickupLabel: 'Bún chả cá Bà Lữ',
        storeName: 'Bún chả cá Bà Lữ',
        dropoffLabel: '45 Nguyễn Văn Linh',
        finishedAt: today.subtract(const Duration(hours: 2)),
      ),
      DriverHistoryItem(
        kind: DriverJobKind.food,
        id: '7d1f0c2a-0000-4000-8000-000000000003',
        outcome: DriverJobOutcome.cancelled,
        fareVnd: 15000,
        earningsVnd: 0,
        pickupLabel: 'Cơm gà A Hải',
        storeName: 'Cơm gà A Hải',
        dropoffLabel: '8 Lê Duẩn',
        finishedAt: today.subtract(const Duration(days: 1, hours: 1)),
      ),
      DriverHistoryItem(
        kind: DriverJobKind.ride,
        id: '7d1f0c2a-0000-4000-8000-000000000004',
        outcome: DriverJobOutcome.completed,
        fareVnd: 35000,
        feeVnd: 3500,
        feePercent: 10,
        earningsVnd: 31500,
        pickupLabel: 'Chợ Hàn',
        dropoffLabel: 'Cầu Rồng',
        finishedAt: today.subtract(const Duration(days: 3)),
        driverStars: 4,
      ),
    ];
  }

  void _maybeFail() {
    final error = failNext;
    if (error != null) {
      failNext = null;
      throw error;
    }
  }

  @override
  Future<DriverHistorySummary> summary({required String accessToken}) async {
    _maybeFail();
    final now = this.now ?? DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final days = [
      for (var offset = 6; offset >= 0; offset--)
        start.subtract(Duration(days: offset)),
    ];
    final buckets = <DriverDaySummary>[];
    for (final day in days) {
      final done = _items.where(
        (item) =>
            item.outcome == DriverJobOutcome.completed &&
            DateUtils.isSameDay(item.finishedAt, day),
      );
      buckets.add(
        DriverDaySummary(
          date: day,
          completedJobs: done.length,
          grossVnd: done.fold(0, (sum, item) => sum + item.fareVnd),
          feeVnd: done.fold(0, (sum, item) => sum + item.feeVnd),
          earningsVnd: done.fold(0, (sum, item) => sum + item.earningsVnd),
        ),
      );
    }
    final week = _items.where((item) => !item.finishedAt.isBefore(days.first));
    final completed = week.where(
      (item) => item.outcome == DriverJobOutcome.completed,
    );
    int earned(DriverJobKind kind) => completed
        .where((item) => item.kind == kind)
        .fold(0, (sum, item) => sum + item.earningsVnd);
    final stars = [for (final item in _items) ?item.driverStars];
    return DriverHistorySummary(
      today: buckets.last,
      days: buckets,
      weekCompletedJobs: completed.length,
      weekCancelledJobs: week.length - completed.length,
      weekGrossVnd: completed.fold(0, (sum, item) => sum + item.fareVnd),
      weekFeeVnd: completed.fold(0, (sum, item) => sum + item.feeVnd),
      weekEarningsVnd: earned(DriverJobKind.ride) + earned(DriverJobKind.food),
      weekRideEarningsVnd: earned(DriverJobKind.ride),
      weekFoodEarningsVnd: earned(DriverJobKind.food),
      ratingAverage: stars.isEmpty
          ? null
          : stars.reduce((a, b) => a + b) / stars.length,
      ratingCount: stars.length,
    );
  }

  @override
  Future<DriverHistoryPage> list({
    required String accessToken,
    DriverHistoryFilter kind,
    String? cursor,
    int limit = 20,
  }) async {
    _maybeFail();
    final filtered = [
      for (final item in _items)
        if (kind == null || item.kind == kind) item,
    ];
    final start = cursor == null ? 0 : int.parse(cursor);
    final end = (start + limit).clamp(0, filtered.length);
    return DriverHistoryPage(
      items: filtered.sublist(start, end),
      nextCursor: end < filtered.length ? '$end' : null,
    );
  }
}
