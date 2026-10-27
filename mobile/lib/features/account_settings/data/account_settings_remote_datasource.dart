import 'package:dio/dio.dart';

import '../../../core/network/api_envelope.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/api_paths.dart';
import '../../../core/network/dio_mapper.dart';
import '../domain/account_settings.dart';

class DioAccountSettingsRemoteDataSource implements AccountSettingsRepository {
  DioAccountSettingsRemoteDataSource({required this.dio});

  final Dio dio;

  Options _auth(String token) =>
      Options(headers: {'Authorization': 'Bearer $token'});

  @override
  Future<NotificationPrefs> notificationPrefs({
    required String accessToken,
  }) async {
    try {
      final res = await dio.get<Object?>(
        ApiPaths.meNotificationPreferences,
        options: _auth(accessToken),
      );
      return decodeNotificationPrefs(requireSuccessData(res.data));
    } on DioException catch (error) {
      throw apiExceptionFromDio(error);
    }
  }

  @override
  Future<NotificationPrefs> saveNotificationPrefs({
    required String accessToken,
    required NotificationPrefs prefs,
  }) async {
    try {
      final res = await dio.patch<Object?>(
        ApiPaths.meNotificationPreferences,
        data: prefs.toJson(),
        options: _auth(accessToken),
      );
      return decodeNotificationPrefs(requireSuccessData(res.data));
    } on DioException catch (error) {
      throw apiExceptionFromDio(error);
    }
  }

  @override
  Future<List<AccountSession>> sessions({required String accessToken}) async {
    try {
      final res = await dio.get<Object?>(
        ApiPaths.meSessions,
        options: _auth(accessToken),
      );
      return decodeAccountSessions(readSuccessPayload(res.data));
    } on DioException catch (error) {
      throw apiExceptionFromDio(error);
    }
  }

  @override
  Future<void> revokeSession({
    required String accessToken,
    required String sessionId,
  }) async {
    try {
      await dio.delete<Object?>(
        ApiPaths.meSession(sessionId),
        options: _auth(accessToken),
      );
    } on DioException catch (error) {
      throw apiExceptionFromDio(error);
    }
  }

  @override
  Future<int> revokeOtherSessions({required String accessToken}) async {
    try {
      final res = await dio.delete<Object?>(
        ApiPaths.meSessionsOthers,
        options: _auth(accessToken),
      );
      final data = requireSuccessData(res.data);
      final revoked = data['revoked'];
      return revoked is num ? revoked.toInt() : 0;
    } on DioException catch (error) {
      throw apiExceptionFromDio(error);
    }
  }

  @override
  Future<void> changePassword({
    required String accessToken,
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await dio.post<Object?>(
        ApiPaths.mePassword,
        data: {'currentPassword': currentPassword, 'newPassword': newPassword},
        options: _auth(accessToken),
      );
    } on DioException catch (error) {
      throw apiExceptionFromDio(error);
    }
  }

  @override
  Future<void> updateProfile({
    required String accessToken,
    String? displayName,
    String? email,
    String? dateOfBirth,
    String? gender,
  }) async {
    try {
      await dio.patch<Object?>(
        ApiPaths.me,
        data: {
          'displayName': ?displayName,
          'email': ?email,
          'dateOfBirth': ?dateOfBirth,
          'gender': ?gender,
        },
        options: _auth(accessToken),
      );
    } on DioException catch (error) {
      throw apiExceptionFromDio(error);
    }
  }

  @override
  Future<Map<String, Object?>> passkeyRegistrationOptions({
    required String accessToken,
  }) async {
    try {
      final res = await dio.post<Object?>(
        ApiPaths.passkeyRegistrationOptions,
        options: _auth(accessToken),
      );
      return Map<String, Object?>.from(requireSuccessData(res.data));
    } on DioException catch (error) {
      throw apiExceptionFromDio(error);
    }
  }

  @override
  Future<void> verifyPasskeyRegistration({
    required String accessToken,
    required Map<String, Object?> response,
  }) async {
    try {
      await dio.post<Object?>(
        ApiPaths.passkeyRegistrationVerify,
        data: response,
        options: _auth(accessToken),
      );
    } on DioException catch (error) {
      throw apiExceptionFromDio(error);
    }
  }

  @override
  Future<void> touchCurrentDevice({
    required String accessToken,
    String? deviceLabel,
  }) async {
    try {
      await dio.patch<Object?>(
        ApiPaths.meSessionsCurrent,
        data: {'deviceLabel': ?deviceLabel},
        options: _auth(accessToken),
      );
    } on DioException catch (error) {
      throw apiExceptionFromDio(error);
    }
  }
}

class FakeAccountSettingsRepository implements AccountSettingsRepository {
  FakeAccountSettingsRepository({
    NotificationPrefs? prefs,
    List<AccountSession>? sessions,
    this.hasPassword = true,
  }) : prefs =
           prefs ??
           const NotificationPrefs(
             ride: true,
             food: true,
             chat: true,
             promotion: false,
             news: false,
           ),
       _sessions =
           sessions ??
           [
             AccountSession(
               id: 'sess-current',
               channel: 'CUSTOMER',
               current: true,
               createdAt: DateTime(2026, 10, 14, 21, 31),
               lastSeenAt: DateTime(2026, 10, 14, 21, 31),
               deviceLabel: 'iPhone · DealGo',
             ),
             AccountSession(
               id: 'sess-other',
               channel: 'CUSTOMER',
               current: false,
               createdAt: DateTime(2026, 10, 10),
               lastSeenAt: DateTime(2026, 10, 14),
               deviceLabel: 'MacBook · Safari',
             ),
           ];

  NotificationPrefs prefs;
  final List<AccountSession> _sessions;
  final bool hasPassword;
  final List<String> calls = [];

  /// Thrown by passkey options/verify to simulate server refusals.
  ApiException? passkeyError;
  int passkeysRegistered = 0;

  @override
  Future<NotificationPrefs> notificationPrefs({
    required String accessToken,
  }) async {
    calls.add('prefs');
    return prefs;
  }

  @override
  Future<NotificationPrefs> saveNotificationPrefs({
    required String accessToken,
    required NotificationPrefs prefs,
  }) async {
    calls.add('savePrefs');
    this.prefs = prefs;
    return prefs;
  }

  @override
  Future<List<AccountSession>> sessions({required String accessToken}) async {
    calls.add('sessions');
    return List.of(_sessions);
  }

  @override
  Future<void> revokeSession({
    required String accessToken,
    required String sessionId,
  }) async {
    calls.add('revoke:$sessionId');
    _sessions.removeWhere((s) => s.id == sessionId);
  }

  @override
  Future<int> revokeOtherSessions({required String accessToken}) async {
    calls.add('revokeOthers');
    final before = _sessions.length;
    _sessions.removeWhere((s) => !s.current);
    return before - _sessions.length;
  }

  @override
  Future<void> changePassword({
    required String accessToken,
    required String currentPassword,
    required String newPassword,
  }) async {
    calls.add('password');
    if (!hasPassword) {
      throw const ApiException(
        statusCode: 409,
        message: 'no password',
        errorCode: 'PASSWORD_NOT_SET',
      );
    }
    if (currentPassword != 'password123') {
      throw const ApiException(
        statusCode: 401,
        message: 'wrong',
        errorCode: 'AUTH_PASSWORD_INVALID',
      );
    }
  }

  @override
  Future<void> updateProfile({
    required String accessToken,
    String? displayName,
    String? email,
    String? dateOfBirth,
    String? gender,
  }) async {
    calls.add('profile:$displayName');
  }

  @override
  Future<void> touchCurrentDevice({
    required String accessToken,
    String? deviceLabel,
  }) async {
    calls.add('touch:$deviceLabel');
  }

  @override
  Future<Map<String, Object?>> passkeyRegistrationOptions({
    required String accessToken,
  }) async {
    calls.add('passkeyOptions');
    final error = passkeyError;
    if (error != null) throw error;
    return {
      'challenge': 'fake-challenge',
      'rp': {'name': 'DealGo', 'id': 'dealgo.trancongtien.com'},
      'user': {'id': 'dXNlcg', 'name': '+84900000000', 'displayName': 'DealGo'},
      'pubKeyCredParams': [
        {'type': 'public-key', 'alg': -7},
      ],
      'excludeCredentials': <Object?>[],
    };
  }

  @override
  Future<void> verifyPasskeyRegistration({
    required String accessToken,
    required Map<String, Object?> response,
  }) async {
    calls.add('passkeyVerify');
    passkeysRegistered += 1;
  }
}
