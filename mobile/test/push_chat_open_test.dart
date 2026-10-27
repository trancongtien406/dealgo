import 'package:dealgo/core/notifications/push_route_resolver.dart';
import 'package:dealgo/features/chat/presentation/widgets/open_chat_on_arrival.dart';
import 'package:dealgo/features/identity/domain/entities/app_role.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// A "new message" push lands in the conversation, not just on the job page.
void main() {
  group('chat push location', () {
    test('keeps the server ?chat=1 flag', () {
      expect(
        resolvePushLocation(
          {
            'path': '/driver/rides/r1/active?chat=1',
            'role': 'DRIVER',
            'eventType': 'Chat.message',
          },
          const [AppRole.driver],
        ),
        '/driver/rides/r1/active?chat=1',
      );
    });

    test('adds it when only the aggregate is known', () {
      Map<String, Object?> chat(String type, String role) => {
        'aggregateType': type,
        'aggregateId': 'x1',
        'status': 'IN_TRIP',
        'role': role,
        'eventType': 'Chat.message',
      };
      expect(
        resolvePushLocation(chat('Ride', 'CUSTOMER'), const [AppRole.customer]),
        '/customer/ride/tracking/x1?chat=1',
      );
      expect(
        resolvePushLocation(chat('Ride', 'DRIVER'), const [AppRole.driver]),
        '/driver/rides/x1/active?chat=1',
      );
      expect(
        resolvePushLocation(chat('FoodOrder', 'CUSTOMER'), const [
          AppRole.customer,
        ]),
        '/customer/food/orders/x1?chat=1',
      );
    });

    test('a food missed call opens that order chat (both roles)', () {
      Map<String, Object?> missed(String role, String status) => {
        'aggregateType': 'FoodOrder',
        'aggregateId': 'f1',
        'status': status,
        'role': role,
        'eventType': 'Call.missed',
        'callId': 'c1',
      };
      expect(
        resolvePushLocation(missed('DRIVER', 'PICKED_UP'), const [
          AppRole.driver,
        ]),
        '/driver/food/f1?chat=1',
      );
      expect(
        resolvePushLocation(missed('CUSTOMER', 'ASSIGNED'), const [
          AppRole.customer,
        ]),
        '/customer/food/orders/f1?chat=1',
      );
      // Server path (chatPushPathFor) is kept as-is.
      expect(
        resolvePushLocation(
          {...missed('DRIVER', 'PICKED_UP'), 'path': '/driver/food/f1?chat=1'},
          const [AppRole.driver],
        ),
        '/driver/food/f1?chat=1',
      );
    });

    test('status pushes do not open the chat', () {
      expect(
        resolvePushLocation(
          {
            'aggregateType': 'Ride',
            'aggregateId': 'x1',
            'status': 'DRIVER_ARRIVED',
            'role': 'CUSTOMER',
            'eventType': 'Ride.status.DRIVER_ARRIVED',
          },
          const [AppRole.customer],
        ),
        '/customer/ride/tracking/x1',
      );
    });
  });

  group('OpenChatOnArrival', () {
    Future<List<String>> pumpAt(WidgetTester tester, String location) async {
      final opened = <String>[];
      final router = GoRouter(
        initialLocation: location,
        routes: [
          GoRoute(path: '/', builder: (context, state) => const SizedBox()),
          GoRoute(
            path: '/job/:id',
            builder: (context, state) => OpenChatOnArrival(
              onOpen: () => opened.add(state.pathParameters['id']!),
              child: const Text('job'),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      return opened;
    }

    testWidgets('opens the chat once when reached with ?chat=1', (
      tester,
    ) async {
      final opened = await pumpAt(tester, '/job/r1?chat=1');
      await tester.pump();
      expect(opened, ['r1']);
    });

    testWidgets('a plain job link leaves the chat closed', (tester) async {
      final opened = await pumpAt(tester, '/job/r1');
      expect(opened, isEmpty);
    });
  });
}
