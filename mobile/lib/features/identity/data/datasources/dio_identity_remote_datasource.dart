import 'package:dio/dio.dart';

import '../../../../core/device/device_id_service.dart';
import '../../../../core/network/api_envelope.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/api_paths.dart';
import '../../../../core/network/dealgo_dio.dart';
import '../../../../core/network/dio_mapper.dart';
import '../models/auth_method_policy_model.dart';
import '../models/email_verification_model.dart';
import '../models/phone_challenge_model.dart';
import '../models/user_profile_model.dart';
import '../models/verified_session_model.dart';
import 'identity_remote_datasource.dart';

class DioIdentityRemoteDataSource implements IdentityRemoteDataSource {
  DioIdentityRemoteDataSource({
    required this.dio,
    DeviceIdService? deviceIdService,
  }) : _deviceIdService = deviceIdService ?? DeviceIdService();

  final Dio dio;
  final DeviceIdService _deviceIdService;

  @override
  Future<PhoneChallengeModel> createPhoneChallenge(String phone) async {
    final deviceId = await _deviceIdService.getDeviceId();
    final body = <String, Object?>{'phone': phone};
    if (deviceId.isNotEmpty) {
      body['deviceId'] = deviceId;
    }
    return _request(
      () => dio.post<Object?>(ApiPaths.phoneChallenges, data: body),
      PhoneChallengeModel.fromJson,
    );
  }

  @override
  Future<VerifiedSessionModel> verifyPhoneChallenge({
    required String challengeId,
    required String code,
  }) async {
    final deviceId = await _deviceIdService.getDeviceId();
    final body = <String, Object?>{'code': code};
    if (deviceId.isNotEmpty) {
      body['deviceId'] = deviceId;
    }
    return _request(
      () => dio.post<Object?>(
        ApiPaths.phoneChallengeVerify(challengeId),
        data: body,
      ),
      VerifiedSessionModel.fromJson,
    );
  }

  @override
  Future<PhoneChallengeModel> registerWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final deviceId = await _deviceIdService.getDeviceId();
    final body = <String, Object?>{'email': email, 'password': password};
    if (deviceId.isNotEmpty) {
      body['deviceId'] = deviceId;
    }
    final trimmedName = displayName?.trim();
    if (trimmedName != null && trimmedName.isNotEmpty) {
      body['displayName'] = trimmedName;
    }
    return _request(
      () => dio.post<Object?>(ApiPaths.emailRegister, data: body),
      PhoneChallengeModel.fromJson,
    );
  }

  @override
  Future<VerifiedSessionModel> verifyEmailRegistration({
    required String challengeId,
    required String code,
  }) async {
    final deviceId = await _deviceIdService.getDeviceId();
    final body = <String, Object?>{'code': code};
    if (deviceId.isNotEmpty) {
      body['deviceId'] = deviceId;
    }
    return _request(
      () => dio.post<Object?>(
        ApiPaths.emailRegisterVerify(challengeId),
        data: body,
      ),
      VerifiedSessionModel.fromJson,
    );
  }

  @override
  Future<PhoneChallengeModel> resendEmailRegistration(String challengeId) {
    return _request(
      () => dio.post<Object?>(ApiPaths.emailRegisterResend(challengeId)),
      PhoneChallengeModel.fromJson,
    );
  }

  @override
  Future<VerifiedSessionModel> loginWithEmail({
    required String email,
    required String password,
  }) async {
    final deviceId = await _deviceIdService.getDeviceId();
    final body = <String, Object?>{'email': email, 'password': password};
    if (deviceId.isNotEmpty) {
      body['deviceId'] = deviceId;
    }
    return _request(
      () => dio.post<Object?>(
        ApiPaths.emailLogin,
        data: body,
      ),
      VerifiedSessionModel.fromJson,
    );
  }

  @override
  Future<PhoneChallengeModel> requestPasswordReset(String email) {
    return _request(
      () => dio.post<Object?>(
        ApiPaths.emailPasswordResets,
        data: {'email': email},
      ),
      PhoneChallengeModel.fromJson,
    );
  }

  @override
  Future<PhoneChallengeModel> resendPasswordReset(String challengeId) {
    return _request(
      () => dio.post<Object?>(ApiPaths.emailPasswordResetResend(challengeId)),
      PhoneChallengeModel.fromJson,
    );
  }

  @override
  Future<void> confirmPasswordReset({
    required String challengeId,
    required String code,
    required String newPassword,
  }) async {
    try {
      await dio.post<Object?>(
        ApiPaths.emailPasswordResetConfirm(challengeId),
        data: {'code': code, 'password': newPassword},
      );
    } on DioException catch (error) {
      throw apiExceptionFromDio(error);
    }
  }

  @override
  Future<VerifiedSessionModel> refreshSession(String refreshToken) {
    return _request(
      () => dio.post<Object?>(
        ApiPaths.sessionsRefresh,
        data: {'refreshToken': refreshToken},
        options: Options(extra: const {skipAuthRefreshExtra: true}),
      ),
      VerifiedSessionModel.fromJson,
    );
  }

  @override
  Future<void> revokeSession(String accessToken) async {
    try {
      final response = await dio.post<Object?>(
        ApiPaths.sessionsRevoke,
        options: Options(
          headers: {'Authorization': 'Bearer $accessToken'},
          extra: const {skipAuthRefreshExtra: true},
        ),
      );
      readSuccessPayload(response.data);
    } on DioException catch (error) {
      throw apiExceptionFromDio(error);
    }
  }

  @override
  Future<UserProfileModel> fetchMe(String accessToken) {
    return _request(
      () => dio.get<Object?>(
        ApiPaths.me,
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      ),
      UserProfileModel.fromJson,
    );
  }

  @override
  Future<UserProfileModel> updateMe({
    required String accessToken,
    String? displayName,
    String? email,
    String? dateOfBirth,
    String? gender,
    String? contactPhone,
  }) {
    final body = <String, Object?>{};
    if (displayName != null) {
      body['displayName'] = displayName;
    }
    if (email != null) {
      body['email'] = email;
    }
    if (dateOfBirth != null) {
      body['dateOfBirth'] = dateOfBirth;
    }
    if (gender != null) {
      body['gender'] = gender;
    }
    if (contactPhone != null) {
      body['contactPhone'] = contactPhone;
    }
    return _request(
      () => dio.patch<Object?>(
        ApiPaths.me,
        data: body,
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      ),
      UserProfileModel.fromJson,
    );
  }

  @override
  Future<String> uploadAvatar({
    required String accessToken,
    String? contentBase64,
    String? dataUrl,
    String? contentType,
  }) async {
    final body = <String, Object?>{};
    if (contentBase64 != null) {
      body['contentBase64'] = contentBase64;
    }
    if (dataUrl != null) {
      body['dataUrl'] = dataUrl;
    }
    if (contentType != null) {
      body['contentType'] = contentType;
    }
    try {
      final response = await dio.post<Object?>(
        ApiPaths.meAvatar,
        data: body,
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );
      final data = requireSuccessData(response.data);
      final avatarUrl = data['avatarUrl'];
      if (avatarUrl is! String || avatarUrl.isEmpty) {
        throw const ApiException(
          statusCode: 200,
          message: 'Invalid response',
          errorCode: 'INVALID_RESPONSE',
        );
      }
      return avatarUrl;
    } on DioException catch (error) {
      throw apiExceptionFromDio(error);
    }
  }

  @override
  Future<EmailVerificationModel> requestEmailVerification({
    required String accessToken,
    required String email,
  }) {
    return _request(
      () => dio.post<Object?>(
        ApiPaths.emailVerifications,
        data: {'email': email},
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      ),
      EmailVerificationModel.fromJson,
    );
  }

  @override
  Future<void> confirmEmailVerification({
    required String verificationId,
    required String code,
  }) async {
    try {
      final response = await dio.post<Object?>(
        ApiPaths.emailVerificationConfirm(verificationId),
        data: {'code': code},
      );
      readSuccessPayload(response.data);
    } on DioException catch (error) {
      throw apiExceptionFromDio(error);
    }
  }

  @override
  Future<Map<String, Object?>> passkeyAuthenticationOptions() async {
    try {
      final response = await dio.post<Object?>(
        ApiPaths.passkeyAuthenticationOptions,
        data: const <String, Object?>{},
      );
      return requireSuccessData(response.data);
    } on DioException catch (error) {
      throw apiExceptionFromDio(error);
    }
  }

  @override
  Future<VerifiedSessionModel> passkeyAuthenticationVerify(
    Map<String, Object?> assertion,
  ) {
    return _request(
      () => dio.post<Object?>(
        ApiPaths.passkeyAuthenticationVerify,
        data: assertion,
      ),
      VerifiedSessionModel.fromJson,
    );
  }

  @override
  Future<Map<String, Object?>> passkeySignupOptions() async {
    try {
      final response = await dio.post<Object?>(
        ApiPaths.passkeySignupOptions,
        data: const <String, Object?>{},
      );
      return requireSuccessData(response.data);
    } on DioException catch (error) {
      throw apiExceptionFromDio(error);
    }
  }

  @override
  Future<VerifiedSessionModel> passkeySignupVerify(
    Map<String, Object?> credential,
  ) {
    return _request(
      () => dio.post<Object?>(ApiPaths.passkeySignupVerify, data: credential),
      VerifiedSessionModel.fromJson,
    );
  }

  @override
  Future<List<AuthMethodPolicyModel>> getAuthMethods() async {
    try {
      final response = await dio.get<Object?>(ApiPaths.authMethods);
      final payload = readSuccessPayload(response.data);
      if (payload is! List) {
        return const [];
      }
      return payload
          .whereType<Map<Object?, Object?>>()
          .map(
            (m) => AuthMethodPolicyModel.fromJson(
              m.map((k, v) => MapEntry(k.toString(), v)),
            ),
          )
          .toList();
    } on DioException catch (error) {
      throw apiExceptionFromDio(error);
    }
  }

  Future<T> _request<T>(
    Future<Response<Object?>> Function() send,
    T Function(Map<String, Object?> data) decode,
  ) async {
    try {
      final response = await send();
      return decode(requireSuccessData(response.data));
    } on DioException catch (error) {
      throw apiExceptionFromDio(error);
    }
  }
}

/// Backward-compatible name for DI and existing call sites.
typedef DioIdentityClient = DioIdentityRemoteDataSource;
