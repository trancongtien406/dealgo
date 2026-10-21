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
      if (method == null || id is! String) {
        throw _invalid();
      }
      return AccountDeletionChallenge(
        requestId: id,
        method: method,
        phoneMasked: data['phoneMasked'] is String
            ? data['phoneMasked'] as String
            : null,
        graceDays: _int(data['graceDays']),
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
  }) async {
    try {
      final response = await dio.post<Object?>(
        ApiPaths.meAccountDeletionConfirm(requestId),
        data: {'code': ?code, 'password': ?password},
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

/// In-memory twin for mock mode and widget tests. OTP is [code], password is [password].
class FakeAccountDeletionRepository implements AccountDeletionRepository {
  FakeAccountDeletionRepository({
    this.method = AccountDeletionMethod.phoneOtp,
    this.blockers = const [],
    this.graceDays = 7,
    this.code = '123456',
    this.password = 'password123',
    this.phoneMasked = '090***4567',
  });

  AccountDeletionMethod? method;
  List<AccountDeletionBlocker> blockers;
  final int graceDays;
  final String code;
  final String password;
  final String phoneMasked;
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
    );
  }

  @override
  Future<AccountDeletionScheduled> confirm({
    required String accessToken,
    required String requestId,
    String? code,
    String? password,
  }) async {
    calls.add('confirm:${code ?? password ?? ''}');
    if (_attempts >= 5) {
      throw const ApiException(
        statusCode: 429,
        message: 'locked',
        errorCode: 'AUTH_CODE_LOCKED',
      );
    }
    final ok = method == AccountDeletionMethod.phoneOtp
        ? code == this.code
        : password == this.password;
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
        errorCode: method == AccountDeletionMethod.phoneOtp
            ? 'AUTH_CODE_INVALID'
            : 'AUTH_PASSWORD_INVALID',
      );
    }
    status = 'SCHEDULED';
    return AccountDeletionScheduled(
      purgeAfter: DateTime(2026, 10, 26, 20, 0),
      graceDays: graceDays,
    );
  }
}
