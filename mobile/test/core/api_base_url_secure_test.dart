import 'package:dealgo/core/config/api_base_url.dart';
import 'package:dealgo/core/config/app_env.dart';
import 'package:dealgo/core/network/dio_log.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('release builds reject http:// API base URLs', () {
    expect(
      () => assertSecureApiBaseUrl('http://api.dealgo.vn', isRelease: true),
      throwsStateError,
    );
    expect(
      () => assertSecureApiBaseUrl('http://localhost:3001', isRelease: true),
      throwsStateError,
    );
    assertSecureApiBaseUrl('https://api.dealgo.vn', isRelease: true);
  });

  test('debug allows http only for local hosts', () {
    assertSecureApiBaseUrl('http://localhost:3001', isRelease: false);
    assertSecureApiBaseUrl('http://10.0.2.2:3001', isRelease: false);
    expect(
      () => assertSecureApiBaseUrl('http://192.168.1.5:3001', isRelease: false),
      throwsStateError,
    );
  });

  test('production defaults point at the VPS domains', () {
    expect(prodApiBaseUrl, 'https://api-dealgo.laptrinhapp.com');
    assertSecureApiBaseUrl(prodApiBaseUrl, isRelease: true);
    // Tests run in debug: no API_BASE_URL define → local Nest.
    expect(apiBaseUrl, devApiBaseUrl);
    expect(appLinkHost, 'dealgo.laptrinhapp.com');
  });

  test('debug log redacts chat message body', () {
    expect(
      redactForLog('{"body":"anh ơi em ở cổng 2"}'),
      isNot(contains('cổng')),
    );
  });
}
