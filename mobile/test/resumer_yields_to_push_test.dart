import 'package:dealgo/core/notifications/notification_router.dart';
import 'package:dealgo/features/driver/data/datasources/driver_active_job_client.dart';
import 'package:dealgo/features/driver/presentation/utils/driver_job_resumer.dart';
import 'package:dealgo/features/driver/presentation/utils/driver_routes.dart';
import 'package:dealgo/features/identity/domain/entities/app_role.dart';
import 'package:dealgo/features/ride/data/datasources/customer_active_trip_client.dart';
import 'package:dealgo/features/ride/presentation/utils/customer_trip_resumer.dart';
import 'package:flutter_test/flutter_test.dart';

/// A tapped push owns navigation: relaunch resumers must not open the active
/// job / trip over the page the user picked (sim run 87: a driver with an
/// ASSIGNED ride tapped a notification and landed on the ride instead).
void main() {
  late DateTime now;
  late List<String> routes;
  late String location;
  late NotificationRouter push;

  setUp(() {
    now = DateTime(2026, 10, 26, 22);
    routes = [];
    location = '/splash';
    push = NotificationRouter(clock: () => now)
      ..bindNavigator((l) {
        routes.add(l);
        location = l;
      })
      ..bindReadiness(() => const [AppRole.driver]);
  });

  test('NotificationRouter claims navigation while pending or just opened', () {
    final cold = NotificationRouter(clock: () => now);
    expect(cold.claimsNavigation, isFalse);
    cold.handleTap({'path': '/driver/account/notifications'}); // not ready yet
    expect(cold.claimsNavigation, isTrue);

    push.openPath('/driver/account/notifications');
    expect(push.claimsNavigation, isTrue);
    now = now.add(const Duration(seconds: 29));
    expect(push.claimsNavigation, isTrue);
    now = now.add(const Duration(seconds: 2));
    expect(push.claimsNavigation, isFalse);
  });

  DriverJobResumer driver(FakeDriverActiveJobSource source, List<int> online) =>
      DriverJobResumer(
        source: source,
        ensureOnline: () => online.add(1),
        navigate: (r) {
          routes.add(r);
          location = r;
        },
        currentLocation: () => location,
        userNavigationClaimed: () => push.claimsNavigation,
      );

  test(
    'cold start from a push: driver stays on the tapped page but goes on duty',
    () async {
      final online = <int>[];
      final resumer = driver(
        FakeDriverActiveJobSource(
          const DriverActiveJob(kind: 'RIDE', id: 'r1'),
        ),
        online,
      );
      push.handleTap({'path': '/driver/account/notifications'});
      await resumer.onSignedIn(
        userId: 'd1',
        roles: const [AppRole.driver],
        profileDone: true,
      );
      expect(routes, ['/driver/account/notifications']);
      expect(location, '/driver/account/notifications');
      expect(online, [1]);
    },
  );

  test('resume from a push tap: recheck does not navigate over it', () async {
    final online = <int>[];
    final source = FakeDriverActiveJobSource();
    final resumer = driver(source, online);
    await resumer.onSignedIn(
      userId: 'd1',
      roles: const [AppRole.driver],
      profileDone: true,
    );
    source.job = const DriverActiveJob(kind: 'RIDE', id: 'r1');
    push.handleTap({'path': '/driver/account/notifications'});
    await resumer.recheck();
    expect(routes, ['/driver/account/notifications']);

    // Once the tap is old, a later recheck (e.g. a new ASSIGNED hint) opens it.
    now = now.add(const Duration(minutes: 1));
    location = '/driver/account';
    await resumer.recheck();
    expect(routes.last, DriverRoutes.active('r1'));
  });

  test('without a push the driver resumer still opens the job', () async {
    final online = <int>[];
    final resumer = driver(
      FakeDriverActiveJobSource(const DriverActiveJob(kind: 'RIDE', id: 'r1')),
      online,
    );
    await resumer.onSignedIn(
      userId: 'd1',
      roles: const [AppRole.driver],
      profileDone: true,
    );
    expect(routes, [DriverRoutes.active('r1')]);
  });

  test('customer resumer yields to a tapped push', () async {
    push.bindReadiness(() => const [AppRole.customer]);
    final resumer = CustomerTripResumer(
      source: FakeCustomerActiveTripSource(
        const CustomerActiveTrip(kind: 'RIDE', id: 'r1', status: 'ASSIGNED'),
      ),
      navigate: routes.add,
      currentLocation: () => '/customer/home',
      userNavigationClaimed: () => push.claimsNavigation,
    );
    push.openPath('/customer/account/notifications');
    await resumer.onSignedIn(
      userId: 'u1',
      roles: const [AppRole.customer],
      profileDone: true,
    );
    expect(routes, ['/customer/account/notifications']);
  });
}
