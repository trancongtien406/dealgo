import 'package:dealgo/features/identity/domain/entities/app_role.dart';
import 'package:dealgo/features/ride/data/datasources/customer_active_trip_client.dart';
import 'package:dealgo/features/ride/presentation/utils/customer_trip_resumer.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  CustomerTripResumer make(
    FakeCustomerActiveTripSource source,
    List<String> routes, {
    String location = '/customer/home',
  }) => CustomerTripResumer(
    source: source,
    navigate: routes.add,
    currentLocation: () => location,
    baseDelay: const Duration(seconds: 1),
  );

  test('parses the active-trip payload and picks the screen', () {
    final ride = CustomerActiveTrip.fromData({
      'trip': {'kind': 'RIDE', 'id': 'r1', 'status': 'IN_TRIP'},
    });
    expect(ride?.route, '/customer/ride/tracking/r1');
    final negotiating = CustomerActiveTrip.fromData({
      'trip': {'kind': 'RIDE', 'id': 'r2', 'status': 'NEGOTIATING'},
    });
    expect(negotiating?.route, '/customer/ride/matching/r2');
    final food = CustomerActiveTrip.fromData({
      'trip': {'kind': 'FOOD_ORDER', 'id': 'o1', 'status': 'PREPARING'},
    });
    expect(food?.route, '/customer/food/orders/o1');
    expect(CustomerActiveTrip.fromData({'trip': null}), isNull);
    expect(
      CustomerActiveTrip.fromData({
        'trip': {'kind': 'X', 'id': 'a', 'status': 'Y'},
      }),
      isNull,
    );
  });

  test('reopens the live trip once per signed-in customer', () async {
    final source = FakeCustomerActiveTripSource(
      const CustomerActiveTrip(kind: 'RIDE', id: 'r1', status: 'ASSIGNED'),
    );
    final routes = <String>[];
    final resumer = make(source, routes);
    await resumer.onSignedIn(
      userId: 'u1',
      roles: const [AppRole.customer],
      profileDone: true,
    );
    await resumer.onSignedIn(
      userId: 'u1',
      roles: const [AppRole.customer],
      profileDone: true,
    );
    expect(routes, ['/customer/ride/tracking/r1']);
    expect(source.calls, 1);
  });

  test(
    'skips non-customers, unfinished profiles and open trip screens',
    () async {
      final source = FakeCustomerActiveTripSource(
        const CustomerActiveTrip(
          kind: 'FOOD_ORDER',
          id: 'o1',
          status: 'PLACED',
        ),
      );
      final routes = <String>[];
      await make(source, routes).onSignedIn(
        userId: 'u1',
        roles: const [AppRole.driver],
        profileDone: true,
      );
      await make(source, routes).onSignedIn(
        userId: 'u1',
        roles: const [AppRole.customer],
        profileDone: false,
      );
      await make(source, routes, location: '/driver/home').onSignedIn(
        userId: 'u1',
        roles: const [AppRole.customer, AppRole.driver],
        profileDone: true,
      );
      await make(
        source,
        routes,
        location: '/customer/food/orders/o1',
      ).onSignedIn(
        userId: 'u1',
        roles: const [AppRole.customer],
        profileDone: true,
      );
      expect(routes, isEmpty);
    },
  );

  test('retries a failed lookup with backoff and stops on reset', () {
    fakeAsync((async) {
      final source = FakeCustomerActiveTripSource(
        const CustomerActiveTrip(kind: 'RIDE', id: 'r1', status: 'IN_TRIP'),
      )..failures = 1;
      final routes = <String>[];
      final resumer = make(source, routes);
      resumer.onSignedIn(
        userId: 'u1',
        roles: const [AppRole.customer],
        profileDone: true,
      );
      async.flushMicrotasks();
      expect(resumer.retryScheduled, isTrue);
      async.elapse(const Duration(seconds: 1));
      expect(routes, ['/customer/ride/tracking/r1']);

      final again = FakeCustomerActiveTripSource()..failures = 3;
      final stopped = make(again, routes);
      stopped.onSignedIn(
        userId: 'u2',
        roles: const [AppRole.customer],
        profileDone: true,
      );
      async.flushMicrotasks();
      stopped.reset();
      async.elapse(const Duration(seconds: 10));
      expect(again.calls, 1);
    });
  });
}
