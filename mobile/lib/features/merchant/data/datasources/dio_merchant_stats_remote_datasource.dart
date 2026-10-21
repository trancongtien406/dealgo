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
