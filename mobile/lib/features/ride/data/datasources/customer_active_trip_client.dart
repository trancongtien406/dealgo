import 'package:dio/dio.dart';

import '../../../../core/network/api_envelope.dart';
import '../../../../core/network/api_paths.dart';

/// The customer's live ride or open food order from
/// `GET /v1/customer/active-trip` (DEC-PROD-057).
class CustomerActiveTrip {
  const CustomerActiveTrip({
    required this.kind,
    required this.id,
    required this.status,
  });

  /// `RIDE` or `FOOD_ORDER`.
  final String kind;
  final String id;
  final String status;

  bool get isRide => kind == 'RIDE';

  /// Screen to reopen: offer matching while negotiating, live tracking once a
  /// driver is assigned, or the food order page.
  String get route {
    if (!isRide) {
      return '/customer/food/orders/$id';
    }
    return status == 'NEGOTIATING'
        ? '/customer/ride/matching/$id'
        : '/customer/ride/tracking/$id';
  }

  static CustomerActiveTrip? fromData(Map<String, Object?> data) {
    final trip = data['trip'];
    if (trip is! Map) {
      return null;
    }
    final kind = trip['kind'];
    final id = trip['id'];
    final status = trip['status'];
    if ((kind != 'RIDE' && kind != 'FOOD_ORDER') ||
        id is! String ||
        id.isEmpty ||
        status is! String) {
      return null;
    }
    return CustomerActiveTrip(kind: kind as String, id: id, status: status);
  }
}

abstract interface class CustomerActiveTripSource {
  /// Null when nothing is live. Throws when the lookup failed so the caller
  /// can retry.
  Future<CustomerActiveTrip?> fetch();
}

class DioCustomerActiveTripSource implements CustomerActiveTripSource {
  DioCustomerActiveTripSource({required this._dio});

  final Dio _dio;

  @override
  Future<CustomerActiveTrip?> fetch() async {
    final response = await _dio.get<Object?>(ApiPaths.customerActiveTrip);
    return CustomerActiveTrip.fromData(requireSuccessData(response.data));
  }
}

class FakeCustomerActiveTripSource implements CustomerActiveTripSource {
  FakeCustomerActiveTripSource([this.trip]);

  CustomerActiveTrip? trip;
  int calls = 0;

  /// Number of upcoming calls that throw (simulates a network outage).
  int failures = 0;

  @override
  Future<CustomerActiveTrip?> fetch() async {
    calls++;
    if (failures > 0) {
      failures--;
      throw StateError('offline');
    }
    return trip;
  }
}
