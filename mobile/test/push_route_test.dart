import 'package:dealgo/core/notifications/notification_router.dart';
import 'package:dealgo/core/notifications/push_route_resolver.dart';
import 'package:dealgo/core/push/fake_push.dart';
import 'package:dealgo/core/push/push_port.dart';
import 'package:dealgo/features/identity/domain/entities/app_role.dart';
import 'package:dealgo/features/merchant/domain/repositories/merchant_orders_repository.dart';
import 'package:dealgo/features/merchant/domain/usecases/list_merchant_order_queue.dart';
import 'package:dealgo/features/merchant/presentation/cubit/merchant_queue_cubit.dart';
import 'package:dealgo/features/merchant/presentation/pages/merchant_order_resume_page.dart';
import 'package:dealgo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

const _c = [AppRole.customer];
const _d = [AppRole.driver];
const _m = [AppRole.merchant];

/// Every push type opens the right page for the user's role,
/// including cold start before the session is restored.
void main() {
  group('resolvePushLocation', () {
    test('keeps a server path the user may open', () {
      expect(
        resolvePushLocation({'path': '/customer/ride/offers/r1'}, _c),
        '/customer/ride/offers/r1',
      );
      expect(
        resolvePushLocation({'path': '/driver/jobs', 'role': 'DRIVER'}, _d),
        '/driver/jobs',
      );
    });

    test('rejects external paths and another role\'s shell', () {
      expect(
        resolvePushLocation({
          'path': 'https://evil.example',
          'aggregateType': 'Ride',
          'aggregateId': 'r1',
          'status': 'ASSIGNED',
        }, _c),
        '/customer/ride/tracking/r1',
      );
      // A driver-only account never opens a customer page from a push.
      expect(
        resolvePushLocation({
          'path': '/customer/food/orders/o1',
          'aggregateType': 'FoodOrder',
          'aggregateId': 'o1',
          'status': 'ASSIGNED',
        }, _d),
        '/driver/food/o1',
      );
    });

    test('moves account pages into a shell the user has', () {
      expect(
        resolvePushLocation({
          'path': '/customer/account/help/tickets/t1',
          'role': 'MERCHANT',
        }, _m),
        '/merchant/account/help/tickets/t1',
      );
    });

    test('derives each push type when the server sent no path (legacy)', () {
      Map<String, Object?> d(
        String type,
        String status, {
        String? role,
        String? event,
      }) => {
        'aggregateType': type,
        'aggregateId': 'x1',
        'status': status,
        'role': ?role,
        'eventType': ?event,
      };
      expect(
        resolvePushLocation(d('Ride', 'NEGOTIATING'), _c),
        '/customer/ride/offers/x1',
      );
      expect(
        resolvePushLocation(d('Ride', 'COMPLETED'), _c),
        '/customer/ride/tracking/x1',
      );
      expect(
        resolvePushLocation(
          d('Ride', 'NEGOTIATING', event: 'Ride.request.nearby'),
          _d,
        ),
        '/driver/jobs',
      );
      expect(
        resolvePushLocation(d('Ride', 'ASSIGNED', role: 'DRIVER'), _d),
        '/driver/rides/x1/active',
      );
      expect(
        resolvePushLocation(d('Ride', 'CANCELLED', role: 'DRIVER'), _d),
        '/driver/jobs',
      );
      expect(
        resolvePushLocation(d('FoodOrder', 'PREPARING'), _c),
        '/customer/food/orders/x1',
      );
      expect(
        resolvePushLocation(d('FoodOrder', 'PLACED', role: 'MERCHANT'), _m),
        '/merchant/orders/x1',
      );
      expect(
        resolvePushLocation(d('FoodOrder', 'CANCELLED', role: 'MERCHANT'), _m),
        '/merchant/orders',
      );
      expect(
        resolvePushLocation(d('FoodOrder', 'ASSIGNED', role: 'DRIVER'), _d),
        '/driver/food/x1',
      );
      expect(
        resolvePushLocation(
          d('FoodOrder', 'READY', event: 'FoodOrder.request.nearby'),
          _d,
        ),
        '/driver/jobs',
      );
      expect(
        resolvePushLocation(
          d('FoodOrder', 'CANCELLED', role: 'DRIVER', event: 'Chat.message'),
          _d,
        ),
        '/driver/food/x1?chat=1',
      );
      expect(
        resolvePushLocation(d('SupportTicket', 'ANSWERED', role: 'DRIVER'), _d),
        '/driver/account/help/tickets/x1',
      );
      expect(
        resolvePushLocation(
          {
            'aggregateType': 'PartnerApplication',
            'aggregateId': 'a1',
            'partnerRole': 'DRIVER',
          },
          const [AppRole.customer, AppRole.driver],
        ),
        '/driver/kyc/status',
      );
    });

    test('a multi-role user follows the role the push names', () {
      const both = [AppRole.customer, AppRole.driver];
      expect(
        resolvePushLocation({
          'aggregateType': 'Ride',
          'aggregateId': 'r1',
          'status': 'ASSIGNED',
          'role': 'DRIVER',
        }, both),
        '/driver/rides/r1/active',
      );
      expect(
        resolvePushLocation({
          'aggregateType': 'Ride',
          'aggregateId': 'r1',
          'status': 'ASSIGNED',
          'role': 'CUSTOMER',
        }, both),
        '/customer/ride/tracking/r1',
      );
    });

    test('falls back to the inbox; empty payload opens nothing', () {
      expect(
        resolvePushLocation({'aggregateType': 'Mystery'}, _m),
        '/merchant/account/notifications',
      );
      expect(
        resolvePushLocation({
          'aggregateType': 'Ride',
          'aggregateId': 'r1',
          'role': 'MERCHANT',
        }, _m),
        '/merchant/account/notifications',
      );
      expect(resolvePushLocation({}, _c), isNull);
    });
  });

  group('inboxTargetFor', () {
    test('opens the row in the inbox shell\'s role', () {
      expect(
        inboxTargetFor(
          shellPath: '/merchant/account',
          aggregateType: 'FoodOrder',
          aggregateId: 'o1',
          status: 'PLACED',
        ),
        '/merchant/orders/o1',
      );
      expect(
        inboxTargetFor(
          shellPath: '/driver',
          aggregateType: 'FoodOrder',
          aggregateId: 'o1',
          status: 'ASSIGNED',
        ),
        '/driver/food/o1',
      );
      expect(
        inboxTargetFor(
          shellPath: '/customer/account',
          aggregateType: 'Ride',
          aggregateId: 'r1',
          status: 'COMPLETED',
        ),
        '/customer/ride/tracking/r1',
      );
      expect(
        inboxTargetFor(
          shellPath: '/customer/account',
          aggregateType: 'NotificationCampaign',
          aggregateId: 'c1',
        ),
        isNull,
      );
    });
  });

  group('NotificationRouter', () {
    test('cold start: a tap before sign-in waits, then opens once', () {
      final opened = <String>[];
      List<AppRole>? roles;
      final router = NotificationRouter()
        ..bindNavigator(opened.add)
        ..bindReadiness(() => roles);
      router.handleTap({
        'path': '/driver/rides/r1/active',
        'role': 'DRIVER',
        'aggregateType': 'Ride',
        'aggregateId': 'r1',
      });
      expect(opened, isEmpty);
      expect(router.hasPending, isTrue);
      router.flushPending(); // still restoring
      expect(opened, isEmpty);
      roles = _d;
      router.flushPending();
      router.flushPending();
      expect(opened, ['/driver/rides/r1/active']);
      expect(router.hasPending, isFalse);
    });

    test('a stale pending tap is dropped', () {
      var now = DateTime(2026, 10, 26, 9);
      final opened = <String>[];
      List<AppRole>? roles;
      final router = NotificationRouter(clock: () => now)
        ..bindNavigator(opened.add)
        ..bindReadiness(() => roles);
      router.handleTap({'path': '/customer/food/orders/o1'});
      now = now.add(const Duration(minutes: 11));
      roles = _c;
      router.flushPending();
      expect(opened, isEmpty);
      expect(router.hasPending, isFalse);
    });

    test('background/foreground taps open at once via FakePush', () async {
      final opened = <String>[];
      final push = FakePush();
      final router = NotificationRouter()
        ..bindNavigator(opened.add)
        ..bindReadiness(() => _m);
      await push.listenForTaps(router.handleTap);
      push.emitTap({
        'aggregateType': 'FoodOrder',
        'aggregateId': 'o9',
        'status': 'PLACED',
        'role': 'MERCHANT',
        'path': '/merchant/orders/o9',
      });
      expect(opened, ['/merchant/orders/o9']);

      PushMessage? shown;
      await push.listenForeground((m) => shown = m);
      push.emitForeground(
        const PushMessage(title: 'Đơn mới', data: {'path': '/merchant/orders'}),
      );
      expect(shown?.title, 'Đơn mới');
    });
  });

  testWidgets(
    'merchant order deep link loads the queue before saying not found',
    (tester) async {
      final repo = _Repo();
      final cubit = MerchantQueueCubit(
        listMerchantOrderQueue: ListMerchantOrderQueue(repo),
      );
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('vi'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: BlocProvider.value(
            value: cubit,
            child: MerchantOrderResumePage(
              orderId: 'o1',
              accessToken: (_) => 'tok',
            ),
          ),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pump();
      await tester.pump();
      expect(repo.calls, 1);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Không tìm thấy đơn'), findsOneWidget);
      await cubit.close();
    },
  );

  testWidgets(
    'merchant order push refetches a queue loaded before the order existed',
    (tester) async {
      final repo = _Repo();
      final cubit = MerchantQueueCubit(
        listMerchantOrderQueue: ListMerchantOrderQueue(repo),
      );
      await cubit.load('tok');
      expect(cubit.state, isA<MerchantQueueReady>());
      expect(repo.calls, 1);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('vi'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: BlocProvider.value(
            value: cubit,
            child: MerchantOrderResumePage(
              orderId: 'new-order',
              accessToken: (_) => 'tok',
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(repo.calls, 2);
      expect(find.text('Không tìm thấy đơn'), findsOneWidget);
      await cubit.close();
    },
  );
}

class _Repo implements MerchantOrdersRepository {
  int calls = 0;
  @override
  Future<List<Never>> listOrderQueue(String accessToken) async {
    calls++;
    return const [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
