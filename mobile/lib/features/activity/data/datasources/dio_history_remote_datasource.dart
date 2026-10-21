import 'package:dio/dio.dart';

import '../../../../core/network/api_envelope.dart';
import '../../../../core/network/api_paths.dart';
import '../../../../core/network/dio_mapper.dart';
import '../../domain/entities/history_models.dart';
import 'history_remote_datasource.dart';

class DioHistoryRemoteDataSource implements HistoryRemoteDataSource {
  DioHistoryRemoteDataSource({required this._dio});

  final Dio _dio;

  @override
  Future<List<HistoryItem>> listRideHistory(String accessToken) {
    return _list(
      path: ApiPaths.meRides,
      accessToken: accessToken,
      kind: HistoryKind.ride,
    );
  }

  @override
  Future<List<HistoryItem>> listFoodHistory(String accessToken) {
    return _list(
      path: ApiPaths.meFoodOrders,
      accessToken: accessToken,
      kind: HistoryKind.food,
    );
  }

  Future<List<HistoryItem>> _list({
    required String path,
    required String accessToken,
    required HistoryKind kind,
  }) async {
    try {
      final response = await _dio.get<Object?>(
        path,
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );
      return decodeHistoryList(response.data, kind: kind);
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      if (status == 404 || status == 501) {
        return const [];
      }
      throw apiExceptionFromDio(error);
    }
  }
}

List<HistoryItem> decodeHistoryList(Object? body, {required HistoryKind kind}) {
  final payload = readSuccessPayload(body);
  final rows = payload is List ? payload : asJsonMap(payload)?['items'];
  if (rows is! List) {
    return const [];
  }
  final items = <HistoryItem>[];
  for (final row in rows) {
    final map = asJsonMap(row);
    if (map == null) {
      continue;
    }
    final id = map['id'] as String?;
    if (id == null || id.isEmpty) {
      continue;
    }
    final status = (map['status'] as String?) ?? '';
    final amount =
        _asInt(map['agreedFareVnd']) ??
        _asInt(map['totalVnd']) ??
        _asInt(map['amountVnd']);
    final title = switch (kind) {
      HistoryKind.ride =>
        (asJsonMap(map['dropoff'])?['label'] as String?) ??
            (map['title'] as String?) ??
            '',
      HistoryKind.food =>
        (map['storeName'] as String?) ?? (map['title'] as String?) ?? '',
    };
    final meta =
        (map['createdAt'] as String?) ??
        (map['completedAt'] as String?) ??
        (map['updatedAt'] as String?) ??
        id;
    items.add(
      HistoryItem(
        id: id,
        kind: kind,
        title: title,
        meta: meta,
        status: status,
        amountVnd: amount,
      ),
    );
  }
  return items;
}

int? _asInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return null;
}

typedef DioHistoryClient = DioHistoryRemoteDataSource;
