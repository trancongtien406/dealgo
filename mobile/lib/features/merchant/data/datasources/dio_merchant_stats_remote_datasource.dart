import 'package:dio/dio.dart';

import '../../../../core/network/api_envelope.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/api_paths.dart';
import '../../../../core/network/dio_mapper.dart';
import '../../domain/merchant_stats.dart';

class DioMerchantStatsRemoteDataSource implements MerchantStatsRepository {
  DioMerchantStatsRemoteDataSource({required this.dio});

  final Dio dio;

  @override
  Future<MerchantStats> stats({
    required String accessToken,
    int days = 7,
  }) async {
    try {
      final response = await dio.get<Object?>(
        ApiPaths.foodMerchantStats,
        queryParameters: {'days': days},
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );
      return decodeMerchantStats(requireSuccessData(response.data));
    } on DioException catch (error) {
      throw apiExceptionFromDio(error);
    }
  }

  @override
  Future<MerchantStatement> statement({
    required String accessToken,
    String? from,
    String? to,
  }) async {
    try {
      final response = await dio.get<Object?>(
        ApiPaths.foodMerchantStatement,
        queryParameters: {'from': ?from, 'to': ?to},
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );
      return decodeMerchantStatement(requireSuccessData(response.data));
    } on DioException catch (error) {
      throw apiExceptionFromDio(error);
    }
  }
}

int _int(Object? value) => value is num ? value.toInt() : 0;

MerchantDayStats _day(Object? raw, {String fallbackDate = ''}) {
  final map = raw is Map ? raw : const {};
  final date = map['date'];
  return MerchantDayStats(
    date: date is String ? date : fallbackDate,
    deliveredCount: _int(map['deliveredCount']),
    cancelledCount: _int(map['cancelledCount']),
    salesVnd: _int(map['salesVnd']),
  );
}

MerchantStats decodeMerchantStats(Map<String, Object?> data) {
  final today = data['today'];
  final series = data['series'];
  final topItems = data['topItems'];
  if (today is! Map || series is! List) {
    throw const ApiException(
      statusCode: 502,
      message: 'Malformed merchant stats',
      errorCode: 'MALFORMED_RESPONSE',
    );
  }
  return MerchantStats(
    days: _int(data['days']),
    today: _day(today),
    openCount: _int(today['openCount']),
    totals: _day(data['totals']),
    series: [for (final day in series) _day(day)],
    topItems: [
      if (topItems is List)
        for (final item in topItems)
          if (item is Map && item['name'] is String)
            MerchantTopItem(
              name: item['name'] as String,
              quantity: _int(item['quantity']),
            ),
    ],
  );
}

MerchantStatement decodeMerchantStatement(Map<String, Object?> data) {
  final totals = data['totals'];
  if (totals is! Map) {
    throw const ApiException(
      statusCode: 502,
      message: 'Malformed merchant statement',
      errorCode: 'MALFORMED_RESPONSE',
    );
  }
  final settlements = data['settlements'];
  final percent = data['commissionPercentNow'];
  String str(Object? v) => v is String ? v : '';
  return MerchantStatement(
    from: str(data['from']),
    to: str(data['to']),
    commissionPercentNow: percent is num ? percent : 0,
    orderCount: _int(totals['orderCount']),
    cashReceivedVnd: _int(totals['cashReceivedVnd']),
    commissionVnd: _int(totals['commissionVnd']),
    netVnd: _int(totals['netVnd']),
    unsettledCommissionVnd: _int(data['unsettledCommissionVnd']),
    settlementCycleDays: _int(data['settlementCycleDays']),
    settlements: [
      if (settlements is List)
        for (final row in settlements)
          if (row is Map)
            MerchantSettlement(
              periodStart: str(row['periodStart']),
              periodEnd: str(row['periodEnd']),
              commissionVnd: _int(row['commissionVnd']),
              createdAt: DateTime.tryParse(str(row['createdAt'])),
            ),
    ],
  );
}
