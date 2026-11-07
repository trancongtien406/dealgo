import 'package:dealgo/core/device/device_id_service.dart';
import 'package:dealgo/core/network/dealgo_dio.dart';
import 'package:dealgo/features/account_settings/presentation/session_device.dart';
import 'package:dealgo/features/identity/data/datasources/dio_identity_remote_datasource.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _CapturingAdapter implements HttpClientAdapter {
  RequestOptions? lastOptions;
  Object? lastData;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastOptions = options;
    lastData = options.data;
    final isSession = options.path.contains('/verify') || options.path.contains('/login');
    final data = isSession
        ? '{"accessToken":"mock-access-token","refreshToken":"mock-refresh-token","expiresIn":900}'
        : '{"challengeId":"test-challenge-id","expiresAt":"2027-01-01T00:00:00.000Z"}';
    return ResponseBody.fromString(
      '{"success":true,"statusCode":200,"message":"OK","data":$data}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DeviceIdService', () {
    test('generates a valid UUID v4 when storage is empty and caches it', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final service = DeviceIdService(sharedPreferences: prefs);

      final id1 = await service.getDeviceId();
      expect(id1, isNotEmpty);
      expect(
        RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$').hasMatch(id1),
        isTrue,
      );

      final id2 = await service.getDeviceId();
      expect(id2, equals(id1));
      expect(service.currentDeviceId, equals(id1));
    });

    test('reads existing device ID from shared preferences', () async {
      SharedPreferences.setMockInitialValues({
        DeviceIdService.storageKey: 'existing-device-id-12345',
      });
      final prefs = await SharedPreferences.getInstance();
      final service = DeviceIdService(sharedPreferences: prefs);

      final id = await service.getDeviceId();
      expect(id, equals('existing-device-id-12345'));
      expect(service.currentDeviceId, equals('existing-device-id-12345'));
    });
  });

  group('DeviceIdInterceptor', () {
    test('adds x-device-id header to dio requests', () async {
      SharedPreferences.setMockInitialValues({
        DeviceIdService.storageKey: 'test-device-uuid-999',
      });
      final prefs = await SharedPreferences.getInstance();
      final service = DeviceIdService(sharedPreferences: prefs);

      final dio = Dio();
      final adapter = _CapturingAdapter();
      dio.httpClientAdapter = adapter;
      dio.interceptors.add(DeviceIdInterceptor(service));

      await dio.get<void>('https://api.dealgo.vn/v1/health');

      expect(adapter.lastOptions, isNotNull);
      expect(adapter.lastOptions!.headers['x-device-id'], equals('test-device-uuid-999'));
      final deviceLabel = adapter.lastOptions!.headers['x-device-label'] as String?;
      expect(deviceLabel, isNotNull);
      // Valid HTTP header must only have printable ASCII 32..126
      for (final codeUnit in deviceLabel!.codeUnits) {
        expect(codeUnit >= 32 && codeUnit <= 126, isTrue);
      }
    });

    test('toHeaderSafeAscii strips non-ascii and replaces middle dot', () {
      expect(toHeaderSafeAscii('iPhone 17 Pro · DealGo'), 'iPhone 17 Pro - DealGo');
      expect(toHeaderSafeAscii('Điện thoại của Tiến · DealGo'), 'in thoi ca Tin - DealGo');
      expect(toHeaderSafeAscii('📱 My Device ⚡'), 'My Device');
      expect(toHeaderSafeAscii(''), 'DealGo-App');
    });
  });

  group('DioIdentityRemoteDataSource with DeviceId', () {
    test('passes deviceId in body for createPhoneChallenge and verifyPhoneChallenge', () async {
      SharedPreferences.setMockInitialValues({
        DeviceIdService.storageKey: 'mock-phone-device-id',
      });
      final prefs = await SharedPreferences.getInstance();
      final service = DeviceIdService(sharedPreferences: prefs);

      final dio = Dio();
      final adapter = _CapturingAdapter();
      dio.httpClientAdapter = adapter;

      final ds = DioIdentityRemoteDataSource(
        dio: dio,
        deviceIdService: service,
      );

      await ds.createPhoneChallenge('+84901234567');
      expect(adapter.lastData, isA<Map<String, dynamic>>());
      final challengeBody = adapter.lastData as Map<String, dynamic>;
      expect(challengeBody['phone'], equals('+84901234567'));
      expect(challengeBody['deviceId'], equals('mock-phone-device-id'));

      await ds.verifyPhoneChallenge(
        challengeId: 'c-1',
        code: '123456',
      );
      final verifyBody = adapter.lastData as Map<String, dynamic>;
      expect(verifyBody['code'], equals('123456'));
      expect(verifyBody['deviceId'], equals('mock-phone-device-id'));
    });

    test('passes deviceId in body for registerWithEmail and loginWithEmail', () async {
      SharedPreferences.setMockInitialValues({
        DeviceIdService.storageKey: 'mock-email-device-id',
      });
      final prefs = await SharedPreferences.getInstance();
      final service = DeviceIdService(sharedPreferences: prefs);

      final dio = Dio();
      final adapter = _CapturingAdapter();
      dio.httpClientAdapter = adapter;

      final ds = DioIdentityRemoteDataSource(
        dio: dio,
        deviceIdService: service,
      );

      await ds.registerWithEmail(
        email: 'test@dealgo.vn',
        password: 'password123',
        displayName: 'Test User',
      );
      final registerBody = adapter.lastData as Map<String, dynamic>;
      expect(registerBody['email'], equals('test@dealgo.vn'));
      expect(registerBody['deviceId'], equals('mock-email-device-id'));
      expect(registerBody['displayName'], equals('Test User'));

      await ds.loginWithEmail(
        email: 'test@dealgo.vn',
        password: 'password123',
      );
      final loginBody = adapter.lastData as Map<String, dynamic>;
      expect(loginBody['email'], equals('test@dealgo.vn'));
      expect(loginBody['deviceId'], equals('mock-email-device-id'));
    });
  });
}
