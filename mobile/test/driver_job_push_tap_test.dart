import 'package:dealgo/core/notifications/notification_router.dart';
import 'package:dealgo/features/identity/domain/entities/app_role.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'tapping a "Cuốc xe mới" push opens jobs and asks the list to refresh',
    () async {
      final opened = <String>[];
      final router = NotificationRouter(
        onNavigate: opened.add,
        readyRoles: () => [AppRole.driver],
      );
      final taps = <String?>[];
      final sub = driverJobPushTaps.listen((t) => taps.add(t.jobId));
      router.handleTap({
        'aggregateType': 'Ride',
        'aggregateId': 'ride-1',
        'status': 'NEGOTIATING',
        'eventType': 'Ride.request.nearby',
        'role': 'DRIVER',
        'path': '/driver/jobs',
      });
      await Future<void>.delayed(Duration.zero);
      expect(opened, ['/driver/jobs']);
      expect(taps, ['ride-1']);
      await sub.cancel();
    },
  );
}
