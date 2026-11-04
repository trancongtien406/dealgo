import 'package:dealgo/core/analytics/analytics_port.dart';
import 'package:dealgo/core/analytics/firebase_analytics_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FirebaseAnalyticsService', () {
    test('implements AnalyticsPort', () {
      expect(FirebaseAnalyticsService.instance, isA<AnalyticsPort>());
    });

    test('isReady returns false when Firebase is not initialized (unit test environment)', () {
      expect(FirebaseAnalyticsService.instance.isReady, isFalse);
    });

    test('soft-fails gracefully without throwing when Firebase is not initialized', () async {
      final service = FirebaseAnalyticsService.instance;

      // None of these should throw in a test environment
      await service.init();
      await service.logEvent('test_event', parameters: {'key': 'value', 'count': 1, 'nullable': null});
      await service.setUserId('user_123');
      await service.setUserRole('driver');
      await service.logLogin(method: 'phone');
      await service.logSignUp(method: 'email');
      await service.logRideRequested(vehicleClass: 'MOTORBIKE', fareVnd: 50000, distanceKm: 5.2);
      await service.logFoodOrderPlaced(orderId: 'order_1', totalVnd: 120000, itemCount: 3);
    });
  });
}

