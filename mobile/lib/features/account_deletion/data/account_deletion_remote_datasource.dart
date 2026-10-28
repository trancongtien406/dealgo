import 'package:dio/dio.dart';

import '../../../core/network/api_envelope.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/api_paths.dart';
import '../../../core/network/dio_mapper.dart';
import '../domain/account_deletion.dart';

class DioAccountDeletionRemoteDataSource implements AccountDeletionRepository {
  DioAccountDeletionRemoteDataSource({required this.dio});

  final Dio dio;

  Options _auth(String token) =>
      Options(headers: {'Authorization': 'Bearer $token'});

  @override
  Future<AccountDeletionOverview> overview({
    required String accessToken,
  }) async {
    try {
      final response = await dio.get<Object?>(
        ApiPaths.meAccountDeletion,
        options: _auth(accessToken),
      );
      final data = requireSuccessData(response.data);
      return AccountDeletionOverview(
        status: data['status'] is String ? data['status'] as String : 'NONE',
        graceDays: _int(data['graceDays']),
        method: decodeAccountDeletionMethod(data['method']),
        phoneMasked: data['phoneMasked'] is String
            ? data['phoneMasked'] as String
            : null,
        blockers: decodeAccountDeletionBlockers(data['blockers']),
      );
    } on DioException catch (error) {
      throw apiExceptionFromDio(error);
    }
  }

  @override
  Future<AccountDeletionChallenge> start({required String accessToken}) async {
    try {
      final response = await dio.post<Object?>(
        ApiPaths.meAccountDeletion,
        options: _auth(accessToken),
      );
      final data = requireSuccessData(response.data);
      final method = decodeAccountDeletionMethod(data['method']);
      final id = data['requestId'];
      final options = data['passkeyOptions'];
      if (method == null ||
          id is! String ||
          (method == AccountDeletionMethod.passkey && options is! Map)) {
        throw _invalid();
      }
      return AccountDeletionChallenge(
        requestId: id,
        method: method,
        phoneMasked: data['phoneMasked'] is String
            ? data['phoneMasked'] as String
            : null,
        graceDays: _int(data['graceDays']),
        passkeyOptions: options is Map
            ? Map<String, Object?>.from(options)
            : null,
      );
    } on DioException catch (error) {
      throw apiExceptionFromDio(error);
    }
  }

  @override
  Future<AccountDeletionScheduled> confirm({
    required String accessToken,
    required String requestId,
    String? code,
    String? password,
    Map<String, Object?>? passkey,
  }) async {
    try {
      final response = await dio.post<Object?>(
        ApiPaths.meAccountDeletionConfirm(requestId),
        data: {'code': ?code, 'password': ?password, 'passkey': ?passkey},
        options: _auth(accessToken),
      );
      final data = requireSuccessData(response.data);
      final purgeAfter = DateTime.tryParse('${data['purgeAfter']}');
      if (purgeAfter == null) {
        throw _invalid();
      }
      return AccountDeletionScheduled(
        purgeAfter: purgeAfter.toLocal(),
        graceDays: _int(data['graceDays']),
      );
    } on DioException catch (error) {
      throw apiExceptionFromDio(error);
    }
  }

  static int _int(Object? raw) => raw is num ? raw.toInt() : 0;

  static ApiException _invalid() => const ApiException(
    statusCode: 200,
    message: 'Invalid response',
    errorCode: 'INVALID_RESPONSE',
  );
}

/// In-memory twin for mock mode and widget tests. OTP is [code], password is [password],
/// a passkey assertion must come from [passkeyCredentialId].
class FakeAccountDeletionRepository implements AccountDeletionRepository {
  FakeAccountDeletionRepository({
    this.method = AccountDeletionMethod.phoneOtp,
    this.blockers = const [],
    this.graceDays = 7,
    this.code = '123456',
    this.password = 'password123',
    this.phoneMasked = '090***4567',
    this.passkeyCredentialId = 'fake-passkey-credential',
  });

  AccountDeletionMethod? method;
  List<AccountDeletionBlocker> blockers;
  final int graceDays;
  final String code;
  final String password;
  final String phoneMasked;
  final String passkeyCredentialId;
  final List<String> calls = [];
  String status = 'NONE';
  var _attempts = 0;
  var _seq = 0;

  @override
  Future<AccountDeletionOverview> overview({
    required String accessToken,
  }) async {
    calls.add('overview');
    return AccountDeletionOverview(
      status: status,
      graceDays: graceDays,
      method: method,
      phoneMasked: method == AccountDeletionMethod.phoneOtp
          ? phoneMasked
          : null,
      blockers: List.of(blockers),
    );
  }

  @override
  Future<AccountDeletionChallenge> start({required String accessToken}) async {
    calls.add('start');
    if (blockers.isNotEmpty) {
      throw ApiException(
        statusCode: 409,
        message: 'blocked',
        errorCode: 'ACCOUNT_DELETION_BLOCKED',
        details: {
          'blockers': [
            for (final b in blockers)
              {'code': b.code, 'count': ?b.count, 'amountVnd': ?b.amountVnd},
          ],
        },
      );
    }
    final current = method;
    if (current == null) {
      throw const ApiException(
        statusCode: 409,
        message: 'no reauth',
        errorCode: 'ACCOUNT_DELETION_REAUTH_UNAVAILABLE',
      );
    }
    _attempts = 0;
    status = 'PENDING';
    return AccountDeletionChallenge(
      requestId: 'del-${++_seq}',
      method: current,
      phoneMasked: current == AccountDeletionMethod.phoneOtp
          ? phoneMasked
          : null,
      graceDays: graceDays,
      passkeyOptions: current == AccountDeletionMethod.passkey
          ? {
              'challenge': 'fake-deletion-challenge-$_seq',
              'rpId': 'dealgo.vn',
              'userVerification': 'required',
              'allowCredentials': [
                {'id': passkeyCredentialId, 'type': 'public-key'},
              ],
            }
          : null,
    );
  }

  @override
  Future<AccountDeletionScheduled> confirm({
    required String accessToken,
    required String requestId,
    String? code,
    String? password,
    Map<String, Object?>? passkey,
  }) async {
    calls.add('confirm:${code ?? password ?? passkey?['id'] ?? ''}');
    if (_attempts >= 5) {
      throw const ApiException(
        statusCode: 429,
        message: 'locked',
        errorCode: 'AUTH_CODE_LOCKED',
      );
    }
    final ok = switch (method) {
      AccountDeletionMethod.passkey => passkey?['id'] == passkeyCredentialId,
      AccountDeletionMethod.phoneOtp => code == this.code,
      _ => password == this.password,
    };
    if (!ok) {
      _attempts += 1;
      if (_attempts >= 5) {
        throw const ApiException(
          statusCode: 429,
          message: 'locked',
          errorCode: 'AUTH_CODE_LOCKED',
        );
      }
      throw ApiException(
        statusCode: 401,
        message: 'wrong',
        errorCode: switch (method) {
          AccountDeletionMethod.passkey => 'AUTH_PASSKEY_INVALID',
          AccountDeletionMethod.phoneOtp => 'AUTH_CODE_INVALID',
          _ => 'AUTH_PASSWORD_INVALID',
        },
      );
    }
    status = 'SCHEDULED';
    return AccountDeletionScheduled(
      purgeAfter: DateTime(2026, 10, 26, 20, 0),
      graceDays: graceDays,
    );
  }
}
