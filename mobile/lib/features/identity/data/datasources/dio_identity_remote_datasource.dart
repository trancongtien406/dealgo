import 'package:dio/dio.dart';

import '../../../../core/network/api_envelope.dart';
import '../../../../core/network/api_paths.dart';
import '../../../../core/network/dealgo_dio.dart';
import '../../../../core/network/dio_mapper.dart';
import '../models/phone_challenge_model.dart';
import '../models/user_profile_model.dart';
import '../models/verified_session_model.dart';
import 'identity_remote_datasource.dart';

class DioIdentityRemoteDataSource implements IdentityRemoteDataSource {
  DioIdentityRemoteDataSource({required this.dio});

  final Dio dio;

  @override
  Future<PhoneChallengeModel> createPhoneChallenge(String phone) {
    return _request(
      () =>
          dio.post<Object?>(ApiPaths.phoneChallenges, data: {'phone': phone}),
      PhoneChallengeModel.fromJson,
    );
  }

  @override
  Future<VerifiedSessionModel> verifyPhoneChallenge({
    required String challengeId,
    required String code,
  }) {
    return _request(
      () => dio.post<Object?>(
        ApiPaths.phoneChallengeVerify(challengeId),
        data: {'code': code},
      ),
      VerifiedSessionModel.fromJson,
    );
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
  Future<UserProfileModel> fetchMe(String accessToken) {
    return _request(
      () => dio.get<Object?>(
        ApiPaths.me,
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      ),
      UserProfileModel.fromJson,
    );
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
