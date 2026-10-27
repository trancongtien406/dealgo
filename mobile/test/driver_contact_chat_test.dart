import 'package:dealgo/features/chat/presentation/widgets/transaction_chat_sheet.dart';
import 'package:dealgo/core/realtime/fake_snapshot_realtime.dart';
import 'package:dealgo/core/realtime/snapshot_realtime.dart';
import 'package:dealgo/features/chat/presentation/model/chat_unread.dart';
import 'package:dealgo/features/driver/presentation/utils/driver_routes.dart';
import 'package:dealgo/features/identity/domain/entities/user_profile.dart';
import 'package:dealgo/features/ride/domain/entities/ride_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'support/auth_test_harness.dart';
import 'support/fake_ride_client.dart';

const _driver = UserProfile(
  id: 'driver-1',
  phone: '+84933333333',
  email: null,
  phoneVerifiedAt: '2026-10-13T16:00:00.000Z',
  emailVerifiedAt: null,
  grants: [RoleGrant(role: 'DRIVER', status: 'ACTIVE')],
);

/// Regression: the driver chat button read VoiceCallCubit with listen: true
/// inside onPressed; the debug assert aborted the handler, so no sheet opened.
void main() {
  testWidgets(
    'driver chat button opens the chat sheet (no listening lookup in onPressed)',
    (tester) async {
      final realtime = FakeSnapshotRealtime();
      final rides = FakeRideClient()..onGet = (_) => _ride(RideStatus.assigned);
      await tester.binding.setSurfaceSize(const Size(400, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await pumpSignedIn(
        tester,
        profile: _driver,
        rideClient: rides,
        realtime: realtime,
      );
      final context = tester.element(find.byType(Scaffold).first);
      GoRouter.of(context).push(DriverRoutes.active('ride-1'));
      await tester.pumpAndSettle();
      final btn = find.byKey(const Key('driver-contact-chat'));
      expect(btn, findsOneWidget);
      await tester.tap(btn);
      await tester.pumpAndSettle();
      expect(find.byType(TransactionChatSheet), findsOneWidget);
    },
  );
  testWidgets('opening the chat clears the unread badge on the trip page', (
    tester,
  ) async {
    addTearDown(ChatUnread.instance.resetForTest);
    final realtime = FakeSnapshotRealtime();
    final rides = FakeRideClient()..onGet = (_) => _ride(RideStatus.assigned);
    await tester.binding.setSurfaceSize(const Size(400, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpSignedIn(
      tester,
      profile: _driver,
      rideClient: rides,
      realtime: realtime,
    );
    final context = tester.element(find.byType(Scaffold).first);
    GoRouter.of(context).push(DriverRoutes.active('ride-1'));
    await tester.pumpAndSettle();
    for (final id in ['m1', 'm2']) {
      realtime.emitChatMessage(
        ChatMessageHint(
          aggregateType: 'Ride',
          aggregateId: 'ride-1',
          id: id,
          threadId: 't1',
          senderUserId: 'customer-1',
          body: 'hi',
          createdAt: DateTime.utc(2026, 10, 26, 16),
        ),
      );
    }
    await tester.pump();
    await tester.pump();
    Badge badge() =>
        tester.widget<Badge>(find.byKey(const Key('chat-unread-Ride:ride-1')));
    expect(badge().isLabelVisible, isTrue);

    await tester.tap(find.byKey(const Key('driver-contact-chat')));
    await tester.pumpAndSettle();
    expect(find.byType(TransactionChatSheet), findsOneWidget);
    expect(tester.takeException(), isNull);
    Navigator.of(tester.element(find.byType(TransactionChatSheet))).pop();
    await tester.pumpAndSettle();
    expect(find.byType(TransactionChatSheet), findsNothing);
    expect(badge().isLabelVisible, isFalse);
  });
}

RideView _ride(RideStatus status) => RideView(
  id: 'ride-1',
  status: status,
  pickup: const RidePoint(lat: 16.0544, lng: 108.2022, label: 'Hải Châu'),
  dropoff: const RidePoint(lat: 16.0439, lng: 108.1994, label: 'Sân bay'),
  offeredFareVnd: 42000,
  referenceFareVnd: 40000,
  agreedFareVnd: 42000,
  assignedDriverId: 'driver-1',
  selectedOfferId: null,
  expiresAt: '2030-01-01T00:00:00.000Z',
  offers: const [],
  vehicleClassCode: 'MOTORBIKE',
);
