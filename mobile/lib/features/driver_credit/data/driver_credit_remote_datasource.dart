import 'package:dio/dio.dart';

import '../../../core/network/api_envelope.dart';
import '../../../core/network/api_paths.dart';
import '../../../core/network/dio_mapper.dart';
import '../domain/driver_credit.dart';

class DioDriverCreditRemoteDataSource implements DriverCreditRepository {
  DioDriverCreditRemoteDataSource({required this.dio});

  final Dio dio;

  Options _auth(String token) =>
      Options(headers: {'Authorization': 'Bearer $token'});

  @override
  Future<DriverCredit> summary({required String accessToken}) async {
    try {
      final response = await dio.get<Object?>(
        ApiPaths.driverCredit,
        options: _auth(accessToken),
      );
      return decodeDriverCredit(requireSuccessData(response.data));
    } on DioException catch (error) {
      throw apiExceptionFromDio(error);
    }
  }

  @override
  Future<DriverTopUp> createTopUp({
    required String accessToken,
    required int amountVnd,
    String? idempotencyKey,
  }) async {
    try {
      final response = await dio.post<Object?>(
        ApiPaths.driverCreditTopUps,
        data: {'amountVnd': amountVnd},
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Idempotency-Key': ?idempotencyKey,
          },
        ),
      );
      return decodeDriverTopUp(requireSuccessData(response.data))!;
    } on DioException catch (error) {
      throw apiExceptionFromDio(error);
    }
  }

  @override
  Future<DriverTopUp> topUp({
    required String accessToken,
    required String id,
  }) async {
    try {
      final response = await dio.get<Object?>(
        ApiPaths.driverCreditTopUp(id),
        options: _auth(accessToken),
      );
      return decodeDriverTopUp(requireSuccessData(response.data))!;
    } on DioException catch (error) {
      throw apiExceptionFromDio(error);
    }
  }

  @override
  Future<DriverTopUp> cancelTopUp({
    required String accessToken,
    required String id,
  }) async {
    try {
      final response = await dio.post<Object?>(
        ApiPaths.driverCreditTopUpCancel(id),
        options: _auth(accessToken),
      );
      return decodeDriverTopUp(requireSuccessData(response.data))!;
    } on DioException catch (error) {
      throw apiExceptionFromDio(error);
    }
  }
}

int _int(Object? raw) => raw is num ? raw.toInt() : 0;

DriverTopUp? decodeDriverTopUp(Object? raw) {
  final map = asJsonMap(raw);
  if (map == null) {
    return null;
  }
  final id = map['id'];
  if (id is! String) {
    return null;
  }
  final expiresAt = DateTime.tryParse('${map['expiresAt']}');
  final paidAt = DateTime.tryParse('${map['paidAt']}');
  final createdAt = DateTime.tryParse('${map['createdAt']}');
  final checkoutUrl = map['checkoutUrl'];
  final qrCode = map['qrCode'];
  final provider = map['provider'];
  return DriverTopUp(
    id: id,
    amountVnd: _int(map['amountVnd']),
    remainingVnd: _int(map['remainingVnd']),
    consumedVnd: _int(map['consumedVnd']),
    refundedVnd: _int(map['refundedVnd']),
    orderCode: _int(map['orderCode']),
    provider: provider is String && provider.isNotEmpty ? provider : 'payos',
    status: DriverTopUpStatus.fromWire(map['status']),
    checkoutUrl: checkoutUrl is String && checkoutUrl.isNotEmpty
        ? checkoutUrl
        : null,
    qrCode: qrCode is String && qrCode.isNotEmpty ? qrCode : null,
    expiresAt: expiresAt?.toLocal(),
    paidAt: paidAt?.toLocal(),
    createdAt: createdAt?.toLocal() ?? DateTime.now(),
  );
}

DriverCredit decodeDriverCredit(Map<String, Object?> data) {
  final recent = data['recentTopUps'];
  return DriverCredit(
    creditVnd: _int(data['creditVnd']),
    owesVnd: _int(data['owesVnd']),
    limitVnd: _int(data['limitVnd']),
    blocked: data['blocked'] == true,
    enabled: data['enabled'] == true,
    minVnd: _int(data['minVnd']),
    maxVnd: _int(data['maxVnd']),
    dailyLimitVnd: _int(data['dailyLimitVnd']),
    maxCreditVnd: _int(data['maxCreditVnd']),
    pendingTopUp: decodeDriverTopUp(data['pendingTopUp']),
    recentTopUps: [
      if (recent is List)
        for (final raw in recent) ?decodeDriverTopUp(raw),
    ],
  );
}

/// In-memory credit for tests, screenshots and `useMockData`.
class FakeDriverCreditRemoteDataSource implements DriverCreditRepository {
  FakeDriverCreditRemoteDataSource({
    this.creditVnd = 120_000,
    this.owesVnd = 0,
    this.enabled = true,
    List<DriverTopUp>? topUps,
  }) : _topUps = [...?topUps];

  int creditVnd;
  int owesVnd;
  bool enabled;
  final List<DriverTopUp> _topUps;

  /// Throws on the next call (tests of the error state).
  Object? failNext;

  static const minVnd = 10_000;
  static const maxVnd = 2_000_000;

  void _maybeFail() {
    final error = failNext;
    if (error != null) {
      failNext = null;
      throw error;
    }
  }

  DriverTopUp? get _pending {
    for (final topUp in _topUps) {
      if (topUp.isPayable) {
        return topUp;
      }
    }
    return null;
  }

  @override
  Future<DriverCredit> summary({required String accessToken}) async {
    _maybeFail();
    return DriverCredit(
      creditVnd: creditVnd,
      owesVnd: owesVnd,
      limitVnd: 200_000,
      blocked: owesVnd > 200_000,
      enabled: enabled,
      minVnd: minVnd,
      maxVnd: maxVnd,
      dailyLimitVnd: 5_000_000,
      maxCreditVnd: 5_000_000,
      pendingTopUp: _pending,
      recentTopUps: List.unmodifiable(_topUps),
    );
  }

  @override
  Future<DriverTopUp> createTopUp({
    required String accessToken,
    required int amountVnd,
    String? idempotencyKey,
  }) async {
    _maybeFail();
    final existing = _pending;
    if (existing != null) {
      return existing;
    }
    final topUp = DriverTopUp(
      id: 'c0ffee00-0000-4000-8000-${_topUps.length.toString().padLeft(12, '0')}',
      amountVnd: amountVnd,
      status: DriverTopUpStatus.pending,
      createdAt: DateTime.now(),
      orderCode: 1_000_000_000 + _topUps.length,
      provider: 'payos',
      checkoutUrl: 'https://pay.payos.vn/web/mock',
      qrCode: 'MOCK-VIETQR-${1_000_000_000 + _topUps.length}',
      expiresAt: DateTime.now().add(const Duration(minutes: 15)),
    );
    _topUps.insert(0, topUp);
    return topUp;
  }

  @override
  Future<DriverTopUp> topUp({
    required String accessToken,
    required String id,
  }) async {
    _maybeFail();
    return _topUps.firstWhere((topUp) => topUp.id == id);
  }

  @override
  Future<DriverTopUp> cancelTopUp({
    required String accessToken,
    required String id,
  }) async {
    _maybeFail();
    final index = _topUps.indexWhere((topUp) => topUp.id == id);
    if (index < 0) {
      throw StateError('top-up $id not found');
    }
    final cancelled = DriverTopUp(
      id: _topUps[index].id,
      amountVnd: _topUps[index].amountVnd,
      status: DriverTopUpStatus.cancelled,
      createdAt: _topUps[index].createdAt,
      consumedVnd: _topUps[index].consumedVnd,
      refundedVnd: _topUps[index].refundedVnd,
      orderCode: _topUps[index].orderCode,
      provider: _topUps[index].provider,
    );
    _topUps[index] = cancelled;
    return cancelled;
  }

  /// Test hook: simulates the PSP callback crediting the driver.
  void markPaid(String id) {
    final index = _topUps.indexWhere((topUp) => topUp.id == id);
    if (index < 0) {
      return;
    }
    final row = _topUps[index];
    _topUps[index] = row.copyWith(
      status: DriverTopUpStatus.paid,
      remainingVnd: row.amountVnd,
      paidAt: DateTime.now(),
    );
    creditVnd += row.amountVnd;
  }

  /// Test hook: the driver let the payment link lapse.
  void markExpired(String id) {
    final index = _topUps.indexWhere((topUp) => topUp.id == id);
    if (index < 0) {
      return;
    }
    _topUps[index] = _topUps[index].copyWith(status: DriverTopUpStatus.expired);
  }
}
