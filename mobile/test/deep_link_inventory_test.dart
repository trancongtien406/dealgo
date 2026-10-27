import 'package:dealgo/app/router/app_router.dart';
import 'package:dealgo/core/deeplink/deep_link_gate.dart';
import 'package:dealgo/core/mock/fake_identity_client.dart';
import 'package:dealgo/core/notifications/notification_router.dart';
import 'package:dealgo/core/notifications/push_route_resolver.dart';
import 'package:dealgo/features/identity/data/repositories/identity_repository_impl.dart';
import 'package:dealgo/features/identity/domain/entities/app_role.dart';
import 'package:dealgo/features/identity/domain/usecases/fetch_me.dart';
import 'package:dealgo/features/identity/presentation/cubit/auth_cubit.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'support/memory_token_store.dart';

/// Every link / push location the apps and the backend emit must name a real
/// page of the app router, and a bare, unknown or foreign-role link must fall
/// back to a real page (never not-found, never nothing).
void main() {
  late AuthCubit auth;
  late NotificationRouter notifications;
  late DeepLinkGate gate;
  late GoRouter router;
  List<AppRole>? ready;

  setUp(() {
    final repository = IdentityRepositoryImpl(
      FakeIdentityClient(profile: customerProfile),
    );
    auth = AuthCubit(
      fetchMe: FetchMe(repository),
      tokens: MemoryTokenStore(),
      identityRepository: repository,
    );
    ready = null;
    notifications = NotificationRouter(readyRoles: () => ready);
    gate = DeepLinkGate(notifications: notifications);
    router = createAppRouter(
      auth: auth,
      refreshListenable: ChangeNotifier(),
      deepLinks: gate,
    );
  });

  tearDown(() async {
    router.dispose();
    await auth.close();
  });

  bool exists(String location) => routeExists(router, location);

  test('every backend push path is a real page', () {
    // backend/src/modules/communication/notification/push-path.ts
    const paths = [
      '/driver/jobs',
      '/driver/rides/r1/active',
      '/driver/rides/r1/active?chat=1',
      '/driver/rides/r1/offer',
      '/driver/rides/r1/otp',
      '/driver/rides/r1',
      '/driver/food/o1',
      '/driver/food/o1?chat=1',
      '/customer/ride/offers/r1',
      '/customer/ride/tracking/r1',
      '/customer/ride/tracking/r1?chat=1',
      '/customer/ride/matching/r1',
      '/customer/ride/receipt/r1',
      '/customer/food/orders/o1',
      '/customer/food/orders/o1?chat=1',
      '/merchant/orders',
      '/merchant/orders/o1',
      '/merchant/orders/o1?chat=1',
      '/customer/account/help/tickets/t1',
      '/driver/account/help/tickets/t1',
      '/merchant/account/help/tickets/t1',
      '/merchant/kyb/status',
      '/driver/kyc/status',
      '/customer/account/notifications',
      '/driver/account/notifications',
      '/merchant/account/notifications',
      '/driver/notifications',
      '/customer',
      '/driver',
      '/merchant',
      '/customer/trips',
      '/customer/book',
      '/customer/shop',
      '/merchant/products',
      '/driver/earnings',
    ];
    for (final path in paths) {
      expect(exists(path), isTrue, reason: path);
    }
    expect(exists('/driver/foo'), isFalse);
    expect(exists('/customer/ride/nope/x/y'), isFalse);
  });

  test('every derived push path is a real page', () {
    final samples = <(Map<String, Object?>, AppRole)>[
      for (final role in AppRole.values)
        for (final type in [
          'Ride',
          'FoodOrder',
          'SupportTicket',
          'PartnerApplication',
          'NotificationCampaign',
        ])
          for (final status in [
            'REQUESTED',
            'NEGOTIATING',
            'ASSIGNED',
            'CANCELLED',
            'COMPLETED',
          ])
            for (final event in ['ride.request', 'ride.status', 'chat.message'])
              (
                {
                  'aggregateType': type,
                  'aggregateId': 'x1',
                  'status': status,
                  'event': event,
                  'role': role.name,
                },
                role,
              ),
    ];
    for (final (data, role) in samples) {
      final path = resolvePushLocation(data, [role]);
      if (path != null) {
        expect(exists(path), isTrue, reason: '$data → $path');
      }
    }
  });

  test('driver NEGOTIATING ride push opens the job feed (backend parity)', () {
    expect(
      derivePushPath({
        'aggregateType': 'Ride',
        'aggregateId': 'r1',
        'status': 'NEGOTIATING',
        'event': 'ride.status',
      }, AppRole.driver),
      '/driver/jobs',
    );
  });

  group('link inventory (signed in)', () {
    String open(String link, List<AppRole> roles) {
      ready = roles;
      final location = gate.intercept(Uri.parse(link));
      expect(location, isNotNull, reason: link);
      expect(exists(location!), isTrue, reason: '$link → $location');
      return location;
    }

    const driver = [AppRole.driver];
    const customer = [AppRole.customer];
    const merchant = [AppRole.merchant];

    test('bare and root links open the role home', () {
      expect(open('dealgo://driver', driver), '/driver');
      expect(open('dealgo://driver/', driver), '/driver');
      expect(open('dealgo://customer', customer), '/customer');
      expect(open('dealgo://merchant', merchant), '/merchant');
      expect(open('dealgo://app/driver', driver), '/driver');
      expect(open('https://dealgo.trancongtien.com/app/driver', driver), '/driver');
      // Nothing to open → splash, which forwards to the entry page.
      expect(open('dealgo://', driver), '/splash');
      expect(open('dealgo://app', driver), '/splash');
    });

    test('known pages open as is', () {
      expect(open('dealgo://driver/jobs', driver), '/driver/jobs');
      expect(open('dealgo://driver/jobs/', driver), '/driver/jobs');
      expect(open('dealgo://app/driver/jobs', driver), '/driver/jobs');
      expect(
        open('dealgo://driver/rides/r1?chat=1', driver),
        startsWith('/driver/rides/r1/active?chat=1&dl='),
      );
      expect(open('dealgo://driver/rides/r1', driver), '/driver/rides/r1');
      expect(open('dealgo://driver/food/o1', driver), '/driver/food/o1');
      expect(
        open('dealgo://customer/rides/r1', customer),
        '/customer/ride/tracking/r1',
      );
      expect(
        open('dealgo://customer/ride/r1', customer),
        '/customer/ride/tracking/r1',
      );
      expect(
        open('dealgo://customer/ride/tracking/r1?chat=1', customer),
        startsWith('/customer/ride/tracking/r1?chat=1&dl='),
      );
      expect(
        open('dealgo://customer/ride/offers/r1', customer),
        '/customer/ride/offers/r1',
      );
      expect(
        open('dealgo://customer/ride/fare', customer),
        '/customer/ride/fare',
      );
      expect(
        open('dealgo://customer/food/orders/o1', customer),
        '/customer/food/orders/o1',
      );
      expect(
        open('dealgo://customer/food/stores/s1', customer),
        '/customer/food/stores/s1',
      );
      expect(
        open('dealgo://merchant/orders/o1', merchant),
        '/merchant/orders/o1',
      );
      expect(
        open('dealgo://customer/account/help/tickets/t1', customer),
        '/customer/account/help/tickets/t1',
      );
      expect(
        open('https://dealgo.trancongtien.com/app/customer/food/orders/o1', customer),
        '/customer/food/orders/o1',
      );
    });

    test('unknown page in own shell opens that shell home', () {
      expect(open('dealgo://driver/foo', driver), '/driver');
      expect(open('dealgo://driver/jobs/x/y/z', driver), '/driver');
      expect(open('dealgo://customer/ride/nope/x', customer), '/customer');
    });

    test('foreign-role link opens the user entry page', () {
      expect(open('dealgo://driver', customer), '/customer');
      expect(open('dealgo://driver/jobs', customer), '/customer');
      expect(open('dealgo://merchant/orders/o1', driver), '/driver');
      expect(
        open('dealgo://driver/account/help/tickets/t1', customer),
        '/customer/account/help/tickets/t1',
      );
      expect(open('dealgo://somewhere', customer), '/customer');
      expect(
        open('dealgo://driver/jobs', const [
          AppRole.customer,
          AppRole.merchant,
        ]),
        '/customer',
      );
    });

    test('multi-role user keeps the link role', () {
      const both = [AppRole.customer, AppRole.driver];
      expect(open('dealgo://driver', both), '/driver');
      expect(open('dealgo://driver/foo', both), '/driver');
    });
  });

  group('cold start / signed out', () {
    test('link is parked and opened with the same rules after sign-in', () {
      final opened = <String>[];
      notifications.bindNavigator(opened.add);
      expect(gate.intercept(Uri.parse('dealgo://driver/foo')), '/splash');
      expect(notifications.hasPending, isTrue);
      ready = [AppRole.driver];
      notifications.flushPending();
      expect(opened, ['/driver']);
    });

    test('parked foreign link opens the user home, not the inbox', () {
      final opened = <String>[];
      notifications.bindNavigator(opened.add);
      gate.intercept(Uri.parse('dealgo://driver/jobs'));
      ready = [AppRole.customer];
      notifications.flushPending();
      expect(opened, ['/customer']);
    });

    test('bare link with no page is not parked', () {
      expect(gate.intercept(Uri.parse('dealgo://')), '/splash');
      expect(notifications.hasPending, isFalse);
    });
  });

  test('stale push path falls back to the shell inbox', () {
    final opened = <String>[];
    notifications
      ..bindNavigator(opened.add)
      ..bindReadiness(() => [AppRole.driver]);
    notifications.handleTap({'path': '/driver/old-page/x'});
    expect(opened, ['/driver/account/notifications']);
  });
}
