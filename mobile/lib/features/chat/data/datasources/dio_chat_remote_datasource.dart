import 'package:dio/dio.dart';

import '../../../../core/network/api_envelope.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/api_paths.dart';
import '../../../../core/network/dio_mapper.dart';
import '../models/chat_models.dart';
import 'chat_remote_datasource.dart';

class DioChatRemoteDataSource implements ChatRemoteDataSource {
  DioChatRemoteDataSource({required this._dio});

  final Dio _dio;

  @override
  Future<ChatMessagePageModel> listRideMessages({
    required String accessToken,
    required String rideId,
    int page = 1,
    int limit = 50,
  }) {
    return _list(
      path: ApiPaths.rideMessages(rideId),
      accessToken: accessToken,
      page: page,
      limit: limit,
    );
  }

  @override
  Future<ChatMessageModel> postRideMessage({
    required String accessToken,
    required String rideId,
    required String body,
  }) {
    return _post(
      path: ApiPaths.rideMessages(rideId),
      accessToken: accessToken,
      body: body,
    );
  }

  @override
  Future<ChatMessagePageModel> listFoodOrderMessages({
    required String accessToken,
    required String orderId,
    int page = 1,
    int limit = 50,
  }) {
    return _list(
      path: ApiPaths.foodOrderMessages(orderId),
      accessToken: accessToken,
      page: page,
      limit: limit,
    );
  }

  @override
  Future<ChatMessageModel> postFoodOrderMessage({
    required String accessToken,
    required String orderId,
    required String body,
  }) {
    return _post(
      path: ApiPaths.foodOrderMessages(orderId),
      accessToken: accessToken,
      body: body,
    );
  }

  Future<ChatMessagePageModel> _list({
    required String path,
    required String accessToken,
    required int page,
    required int limit,
  }) async {
    try {
      final response = await _dio.get<Object?>(
        path,
        queryParameters: {'page': page, 'limit': limit},
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );
      final data = requireSuccessData(response.data);
      final rawItems = data['items'];
      if (rawItems is! List) {
        throw const ApiException(
          statusCode: 500,
          message: 'Invalid chat message list',
          errorCode: 'INVALID_RESPONSE',
        );
      }
      return ChatMessagePageModel(
        items: [
          for (final item in rawItems)
            if (item is Map) ChatMessageModel.fromJson(asJsonMap(item)!),
        ],
        page: (data['page'] as num?)?.toInt() ?? page,
        limit: (data['limit'] as num?)?.toInt() ?? limit,
        total: (data['total'] as num?)?.toInt() ?? 0,
      );
    } on DioException catch (error) {
      throw apiExceptionFromDio(error);
    }
  }

  Future<ChatMessageModel> _post({
    required String path,
    required String accessToken,
    required String body,
  }) async {
    try {
      final response = await _dio.post<Object?>(
        path,
        data: {'body': body},
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );
      return ChatMessageModel.fromJson(requireSuccessData(response.data));
    } on DioException catch (error) {
      throw apiExceptionFromDio(error);
    }
  }
}

typedef DioChatClient = DioChatRemoteDataSource;
