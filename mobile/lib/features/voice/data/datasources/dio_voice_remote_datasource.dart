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
  Future<VoiceCallConfig> config({required String accessToken}) async {
    final data = requireSuccessData(
      await _send('GET', ApiPaths.callsConfig, accessToken),
    );
    return VoiceCallConfig(
      enabled: data['enabled'] == true,
      ringSeconds: (data['ringSeconds'] as num?)?.toInt() ?? 40,
    );
  }

  @override
  Future<VoiceCallJoin> start({
    required String accessToken,
    required VoiceThreadKind kind,
    required String resourceId,
  }) async {
    final path = switch (kind) {
      VoiceThreadKind.ride => ApiPaths.rideCalls(resourceId),
      VoiceThreadKind.foodOrder => ApiPaths.foodOrderCalls(resourceId),
    };
    return decodeVoiceCallJoin(await _send('POST', path, accessToken));
  }

  @override
  Future<VoiceCall> get({
    required String accessToken,
    required String callId,
  }) async =>
      decodeVoiceCall(await _send('GET', ApiPaths.call(callId), accessToken));

  @override
  Future<VoiceCallJoin> accept({
    required String accessToken,
    required String callId,
  }) async => decodeVoiceCallJoin(
    await _send('POST', ApiPaths.callAction(callId, 'accept'), accessToken),
  );

  @override
  Future<VoiceCall> decline({
    required String accessToken,
    required String callId,
  }) async => decodeVoiceCall(
    await _send('POST', ApiPaths.callAction(callId, 'decline'), accessToken),
  );

  @override
  Future<VoiceCall> end({
    required String accessToken,
    required String callId,
  }) async => decodeVoiceCall(
    await _send('POST', ApiPaths.callAction(callId, 'end'), accessToken),
  );

  Future<Object?> _send(String method, String path, String accessToken) async {
    try {
      final response = await _dio.request<Object?>(
        path,
        options: Options(
          method: method,
          headers: {'Authorization': 'Bearer $accessToken'},
        ),
      );
      return response.data;
    } on DioException catch (error) {
      throw apiExceptionFromDio(error);
    }
  }
}

const _invalidCall = ApiException(
  statusCode: 200,
  message: 'Invalid call payload',
  errorCode: 'INVALID_RESPONSE',
);

VoiceCall decodeVoiceCall(Object? body) {
  return VoiceCall.tryParse(requireSuccessData(body)) ?? (throw _invalidCall);
}

VoiceCallJoin decodeVoiceCallJoin(Object? body) {
  final data = requireSuccessData(body);
  final call = VoiceCall.tryParse(data['call']);
  final session = decodeVoiceSession(data['session']);
  if (call == null || session == null) {
    throw _invalidCall;
  }
  return VoiceCallJoin(call: call, session: session);
}

VoiceSession? decodeVoiceSession(Object? raw) {
  if (raw is! Map) {
    return null;
  }
  final room = raw['roomName'];
  final token = raw['token'];
  if (room is! String || room.isEmpty || token is! String || token.isEmpty) {
    return null;
  }
  final url = raw['url'];
  return VoiceSession(
    roomName: room,
    token: token,
    url: url is String && url.isNotEmpty ? url : null,
  );
}

typedef DioVoiceClient = DioVoiceRemoteDataSource;
