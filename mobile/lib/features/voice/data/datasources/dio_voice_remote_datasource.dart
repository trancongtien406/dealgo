import 'package:dio/dio.dart';

import '../../../../core/network/api_envelope.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/api_paths.dart';
import '../../../../core/network/dio_mapper.dart';
import '../../domain/entities/voice_models.dart';
import 'voice_remote_datasource.dart';

class DioVoiceRemoteDataSource implements VoiceRemoteDataSource {
  DioVoiceRemoteDataSource({required this._dio});

  final Dio _dio;

  @override
  Future<VoiceSession> createRideVoiceSession({
    required String accessToken,
    required String rideId,
  }) {
    return _create(
      path: ApiPaths.rideVoiceSession(rideId),
      accessToken: accessToken,
    );
  }

  @override
  Future<VoiceSession> createFoodOrderVoiceSession({
    required String accessToken,
    required String orderId,
  }) {
    return _create(
      path: ApiPaths.foodOrderVoiceSession(orderId),
      accessToken: accessToken,
    );
  }

  Future<VoiceSession> _create({
    required String path,
    required String accessToken,
  }) async {
    try {
      final response = await _dio.post<Object?>(
        path,
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );
      return decodeVoiceSession(response.data);
    } on DioException catch (error) {
      throw apiExceptionFromDio(error);
    }
  }
}

VoiceSession decodeVoiceSession(Object? body) {
  final data = requireSuccessData(body);
  final room =
      data['roomName'] as String? ??
      data['room'] as String? ??
      data['roomId'] as String?;
  final token = data['token'] as String? ?? data['accessToken'] as String?;
  if (room == null || room.isEmpty || token == null || token.isEmpty) {
    throw const ApiException(
      statusCode: 200,
      message: 'Invalid voice session',
      errorCode: 'INVALID_VOICE_SESSION',
    );
  }
  final url = data['url'] as String? ?? data['livekitUrl'] as String?;
  return VoiceSession(roomName: room, token: token, url: url);
}

typedef DioVoiceClient = DioVoiceRemoteDataSource;
