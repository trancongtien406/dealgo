import 'package:dealgo/core/config/api_base_url.dart';
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

  test('debug log redacts chat message body', () {
    expect(
      redactForLog('{"body":"anh ơi em ở cổng 2"}'),
      isNot(contains('cổng')),
    );
  });
}
