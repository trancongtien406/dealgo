import 'package:dealgo/core/auth/token_store.dart';
import 'package:dealgo/core/network/dealgo_dio.dart';
import 'package:dealgo/core/network/dio_log.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('redactForLog', () {
    test('masks Authorization bearer tokens', () {
      expect(
        redactForLog('Authorization: Bearer secret-access-token'),
        'Authorization: Bearer ***',
      );
      expect(
        redactForLog('{"Authorization":"Bearer abc.def.ghi"}'),
        '{"Authorization":"Bearer ***"}',
      );
    });

    test('masks auth payload fields', () {
      final raw =
          '{"accessToken":"a","refreshToken":"b","password":"p","otp":"123456"}';
      expect(
        redactForLog(raw),
        '{"accessToken":"***","refreshToken":"***","password":"***","otp":"***"}',
      );
    });
  });

  group('createDealGoDio logging', () {
    test('attaches LogInterceptor when logging is enabled', () {
      final dio = createDealGoDio(
        tokenStore: MemoryTokenStore(),
        onSessionRefreshed: (_) async {},
        onUnauthorized: () async {},
        enableLogging: true,
      );
      expect(dio.interceptors.whereType<LogInterceptor>(), isNotEmpty);
    });

    test('omits LogInterceptor when logging is disabled', () {
      final dio = createDealGoDio(
        tokenStore: MemoryTokenStore(),
        onSessionRefreshed: (_) async {},
        onUnauthorized: () async {},
        enableLogging: false,
      );
      expect(dio.interceptors.whereType<LogInterceptor>(), isEmpty);
    });
  });
}
