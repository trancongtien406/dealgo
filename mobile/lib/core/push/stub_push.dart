import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../network/api_paths.dart';
import '../network/dio_mapper.dart';
import 'push_port.dart';

/// Legacy local-token push. Live DI uses [FcmPush]; keep for mid-flight tests.
class StubPush implements PushPort {
  StubPush({this._dio, String? seedToken})
    : _token = seedToken ?? _localStubToken();

  final Dio? _dio;
  final String _token;
  bool _registered = false;

  @override
  Future<String?> currentToken() async => _token;

  @override
  Future<void> ensureRegistered({required String accessToken}) async {
    if (_registered || accessToken.isEmpty) {
      return;
    }
    final dio = _dio;
    if (dio == null) {
      _registered = true;
      return;
    }
    try {
      await dio.post<Object?>(
        ApiPaths.mePushTokens,
        data: {'token': _token, 'platform': defaultTargetPlatform.name},
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );
      _registered = true;
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      // Endpoint may not exist yet — keep local token for mid-flight backend.
      if (status == 404 || status == 501) {
        return;
      }
      throw apiExceptionFromDio(error);
    }
  }
}

String _localStubToken() {
  final stamp = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
  return 'stub-push-$stamp';
}
