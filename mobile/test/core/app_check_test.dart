import 'package:dealgo/core/app_check/app_check_service.dart';
import 'package:dealgo/core/network/dealgo_dio.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAppCheckService extends AppCheckService {
  _FakeAppCheckService(this.mockToken);

  final String? mockToken;

  @override
  Future<String?> getToken({bool forceRefresh = false}) async => mockToken;
}

class _CapturingAdapter implements HttpClientAdapter {
  RequestOptions? lastOptions;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastOptions = options;
    return ResponseBody.fromString('{"ok":true}', 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppCheckInterceptor', () {
    test('attaches x-firebase-appcheck header when token is available', () async {
      final dio = Dio();
      final adapter = _CapturingAdapter();
      dio.httpClientAdapter = adapter;
      dio.interceptors.add(AppCheckInterceptor(_FakeAppCheckService('mock-appcheck-token-123')));

      await dio.get('https://api.example.com/test');

      expect(adapter.lastOptions?.headers['x-firebase-appcheck'], 'mock-appcheck-token-123');
    });

    test('does not set header when token is null', () async {
      final dio = Dio();
      final adapter = _CapturingAdapter();
      dio.httpClientAdapter = adapter;
      dio.interceptors.add(AppCheckInterceptor(_FakeAppCheckService(null)));

      await dio.get('https://api.example.com/test');

      expect(adapter.lastOptions?.headers.containsKey('x-firebase-appcheck'), isFalse);
    });
  });
}
