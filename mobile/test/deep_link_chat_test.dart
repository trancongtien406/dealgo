import 'package:dealgo/core/deeplink/deep_link_gate.dart';
import 'package:dealgo/core/notifications/notification_router.dart';
import 'package:dealgo/features/chat/presentation/widgets/open_chat_on_arrival.dart';
import 'package:dealgo/features/identity/domain/entities/app_role.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// `dealgo://…?chat=1` lands on the trip page with the chat open from a
/// cold start, from background and while the app is in the foreground.
void main() {
  group('canonicalDeepLinkLocation', () {
    test('driver ride chat link opens the active trip', () {
      expect(
        canonicalDeepLinkLocation('/driver/rides/r1?chat=1'),
        '/driver/rides/r1/active?chat=1',
      );
      expect(canonicalDeepLinkLocation('/driver/rides/r1'), '/driver/rides/r1');
      expect(
        canonicalDeepLinkLocation('/driver/food/f1?chat=1'),
        '/driver/food/f1?chat=1',
      );
    });

    test('customer short links open tracking', () {
      expect(
        canonicalDeepLinkLocation('/customer/rides/r1?chat=1'),
        '/customer/ride/tracking/r1?chat=1',
      );
      expect(
        canonicalDeepLinkLocation('/customer/ride/tracking/r1?chat=1'),
        '/customer/ride/tracking/r1?chat=1',
      );
      expect(
        canonicalDeepLinkLocation('/customer/food/orders/o1?chat=1'),
        '/customer/food/orders/o1?chat=1',
      );
      expect(
        canonicalDeepLinkLocation('/app/driver/rides/r1?chat=1'),
        '/driver/rides/r1/active?chat=1',
      );
    });
  });

  group('DeepLinkGate', () {
    test('in-app locations pass through', () {
      final gate = DeepLinkGate(notifications: NotificationRouter());
      expect(gate.intercept(Uri.parse('/driver/jobs')), isNull);
    });

    test('ready session opens at once and claims navigation', () {
      final router = NotificationRouter()
        ..bindReadiness(() => const [AppRole.driver]);
      final gate = DeepLinkGate(notifications: router);
      expect(
        gate.intercept(Uri.parse('dealgo://driver/rides/r1?chat=1')),
        '/driver/rides/r1/active?chat=1&dl=1',
      );
      expect(router.claimsNavigation, isTrue);
    });

    test('cold start parks the link until the session is ready', () {
      List<AppRole>? roles;
      final opened = <String>[];
      final router = NotificationRouter()
        ..bindReadiness(() => roles)
        ..bindNavigator(opened.add);
      final gate = DeepLinkGate(notifications: router);
      expect(
        gate.intercept(Uri.parse('dealgo://customer/food/orders/o1?chat=1')),
        '/splash',
      );
      expect(router.hasPending, isTrue);
      roles = const [AppRole.customer];
      router.flushPending();
      expect(opened, ['/customer/food/orders/o1?chat=1&dl=1']);
    });
  });

  group('trip page opens the chat', () {
    Future<(GoRouter, List<String>, NotificationRouter)> pump(
      WidgetTester tester, {
      required String initial,
      required List<AppRole>? Function() roles,
    }) async {
      final opened = <String>[];
      final notifications = NotificationRouter()..bindReadiness(roles);
      final gate = DeepLinkGate(notifications: notifications);
      Widget trip(GoRouterState state) => OpenChatOnArrival(
        onOpen: () => opened.add(state.uri.path),
        child: Text('trip ${state.pathParameters['id']}'),
      );
      final router = GoRouter(
        initialLocation: initial,
        redirect: (context, state) => gate.intercept(state.uri),
        routes: [
          GoRoute(
            path: '/splash',
            builder: (context, state) => const Text('splash'),
          ),
          GoRoute(
            path: '/driver/jobs',
            builder: (context, state) => const Text('jobs'),
          ),
          GoRoute(
            path: '/driver/rides/:id/active',
            builder: (context, state) => trip(state),
          ),
          GoRoute(
            path: '/driver/food/:id',
            builder: (context, state) => trip(state),
          ),
          GoRoute(
            path: '/customer/ride/tracking/:id',
            builder: (context, state) => trip(state),
          ),
        ],
      );
      notifications.bindNavigator(router.go);
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      return (router, opened, notifications);
    }

    Future<void> platformLink(WidgetTester tester, String url) async {
      const codec = JSONMethodCodec();
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        'flutter/navigation',
        codec.encodeMethodCall(
          MethodCall('pushRouteInformation', {'location': url, 'state': null}),
        ),
        (_) {},
      );
      await tester.pumpAndSettle();
    }

    testWidgets('cold start: opens after the session restores', (tester) async {
      List<AppRole>? roles;
      final (_, opened, notifications) = await pump(
        tester,
        initial: 'dealgo://driver/rides/r1?chat=1',
        roles: () => roles,
      );
      expect(find.text('splash'), findsOneWidget);
      roles = const [AppRole.driver];
      notifications.flushPending();
      await tester.pumpAndSettle();
      expect(find.text('trip r1'), findsOneWidget);
      expect(opened, ['/driver/rides/r1/active']);
    });

    testWidgets('background / foreground: platform link opens the chat, '
        'a repeat link on the same page reopens it', (tester) async {
      final (_, opened, _) = await pump(
        tester,
        initial: '/driver/jobs',
        roles: () => const [AppRole.driver],
      );
      await platformLink(tester, 'dealgo://driver/food/f1?chat=1');
      expect(find.text('trip f1'), findsOneWidget);
      expect(opened, ['/driver/food/f1']);
      await platformLink(tester, 'dealgo://driver/food/f1?chat=1');
      expect(opened, ['/driver/food/f1', '/driver/food/f1']);
    });

    testWidgets('customer ride link opens tracking with chat', (tester) async {
      final (_, opened, _) = await pump(
        tester,
        initial: '/splash',
        roles: () => const [AppRole.customer],
      );
      await platformLink(tester, 'dealgo://customer/ride/tracking/r9?chat=1');
      expect(find.text('trip r9'), findsOneWidget);
      expect(opened, ['/customer/ride/tracking/r9']);
    });
  });
}
