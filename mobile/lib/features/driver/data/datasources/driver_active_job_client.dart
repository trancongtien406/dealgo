import 'package:dio/dio.dart';

import '../../../../core/network/api_envelope.dart';
import '../../../../core/network/api_paths.dart';
import '../../presentation/utils/driver_routes.dart';

/// The driver's in-progress job from `GET /v1/driver/active-job`.
class DriverActiveJob {
  const DriverActiveJob({required this.kind, required this.id});

  /// `RIDE` or `FOOD_ORDER`.
  final String kind;
  final String id;

  bool get isRide => kind == 'RIDE';

  /// Screen to resume on: the active ride page or the delivery page.
  String get route => isRide ? DriverRoutes.active(id) : DriverRoutes.food(id);

  static DriverActiveJob? fromData(Map<String, Object?> data) {
    final job = data['job'];
    if (job is! Map) {
      return null;
    }
    final kind = job['kind'];
    final id = job['id'];
    if ((kind != 'RIDE' && kind != 'FOOD_ORDER') ||
        id is! String ||
        id.isEmpty) {
      return null;
    }
    return DriverActiveJob(kind: kind as String, id: id);
  }
}

abstract interface class DriverActiveJobSource {
  /// Null when the driver is idle. Throws when the lookup failed (network /
  /// 5xx) so the caller can retry.
  Future<DriverActiveJob?> fetch();
}

class DioDriverActiveJobSource implements DriverActiveJobSource {
  DioDriverActiveJobSource({required this._dio});

  final Dio _dio;

  @override
  Future<DriverActiveJob?> fetch() async {
    final response = await _dio.get<Object?>(ApiPaths.driverActiveJob);
    return DriverActiveJob.fromData(requireSuccessData(response.data));
  }
}

class FakeDriverActiveJobSource implements DriverActiveJobSource {
  FakeDriverActiveJobSource([this.job]);

  DriverActiveJob? job;
  int calls = 0;

  /// Number of upcoming calls that throw (simulates a network outage).
  int failures = 0;

  @override
  Future<DriverActiveJob?> fetch() async {
    calls++;
    if (failures > 0) {
      failures--;
      throw StateError('offline');
    }
    return job;
  }
}
