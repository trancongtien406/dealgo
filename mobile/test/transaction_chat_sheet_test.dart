import 'package:dealgo/core/realtime/fake_snapshot_realtime.dart';
import 'package:dealgo/core/realtime/snapshot_realtime.dart';
import 'package:dealgo/features/chat/domain/usecases/list_food_order_chat_messages.dart';
import 'package:dealgo/features/chat/domain/usecases/list_ride_chat_messages.dart';
import 'package:dealgo/features/chat/domain/usecases/send_food_order_chat_message.dart';
import 'package:dealgo/features/chat/domain/usecases/send_ride_chat_message.dart';
import 'package:dealgo/features/chat/presentation/cubit/chat_cubit.dart';
import 'package:dealgo/features/chat/presentation/model/chat_timeline.dart';
import 'package:dealgo/features/chat/presentation/model/chat_unread.dart';
import 'package:dealgo/features/chat/presentation/widgets/transaction_chat_sheet.dart';
import 'package:dealgo/core/maps/map_lat_lng.dart';
import 'package:dealgo/core/maps/route_geometry.dart';
import 'package:dealgo/features/driver_card/domain/driver_card.dart';
import 'package:dealgo/features/live_location/presentation/pushed_route_eta.dart';
import 'package:dealgo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_chat_repository.dart';

ChatCubit _cubit(
  FakeChatRepository repo, {
  SnapshotRealtime? realtime,
  ChatThreadKind kind = ChatThreadKind.ride,
}) => ChatCubit(
  listRideChatMessages: ListRideChatMessages(repo),
  sendRideChatMessage: SendRideChatMessage(repo),
  listFoodOrderChatMessages: ListFoodOrderChatMessages(repo),
  sendFoodOrderChatMessage: SendFoodOrderChatMessage(repo),
  kind: kind,
  resourceId: 'r1',
  currentUserId: 'me',
  realtime: realtime,
);

ChatMessageHint _hint(String id, String sender, String body, DateTime at) =>
    ChatMessageHint(
      aggregateType: 'Ride',
      aggregateId: 'r1',
      id: id,
      threadId: 't1',
      senderUserId: sender,
      body: body,
      createdAt: at,
    );

Future<void> _flush() => Future<void>.delayed(Duration.zero);

void main() {
  final t0 = DateTime.utc(2026, 10, 26, 14, 0);

  group('ChatCubit (r25)', () {
    test('orders by time then id, converts to local time', () async {
      final repo = FakeChatRepository(
        messages: [
          chatMessage('b', 'drv', 'hai', t0.add(const Duration(minutes: 1))),
          chatMessage('a', 'me', 'một', t0),
        ],
      );
      final cubit = _cubit(repo);
      await cubit.start(accessToken: 'tok');
      expect(cubit.state.lines.map((l) => l.key), ['a', 'b']);
      expect(cubit.state.lines.first.at.isUtc, isFalse);
      expect(cubit.state.lines.first.at, t0.toLocal());
      await cubit.close();
    });

    test('live push merges by id; reconnect reload never duplicates', () async {
      final rt = FakeSnapshotRealtime();
      final repo = FakeChatRepository(
        messages: [chatMessage('a', 'drv', 'chào', t0)],
      );
      final cubit = _cubit(repo, realtime: rt);
      await cubit.start(accessToken: 'tok');
      final late = t0.add(const Duration(minutes: 2));
      rt.emitChatMessage(_hint('b', 'drv', 'tới rồi', late));
      rt.emitChatMessage(_hint('b', 'drv', 'tới rồi', late)); // replay
      // Other aggregate is ignored.
      rt.emitChatMessage(
        ChatMessageHint(
          aggregateType: 'FoodOrder',
          aggregateId: 'r1',
          id: 'x',
          threadId: 't9',
          senderUserId: 'drv',
          body: 'khác',
          createdAt: late,
        ),
      );
      await _flush();
      expect(cubit.state.lines.map((l) => l.key), ['a', 'b']);
      repo.messages.add(chatMessage('b', 'drv', 'tới rồi', late));
      rt.emitReconnect();
      await _flush();
      await _flush();
      expect(repo.listCalls, 2);
      expect(cubit.state.lines.map((l) => l.key), ['a', 'b']);
      await cubit.close();
      await rt.dispose();
    });

    test('optimistic send: sending → sent, no echo duplicate', () async {
      final rt = FakeSnapshotRealtime();
      final repo = FakeChatRepository();
      final cubit = _cubit(repo, realtime: rt);
      await cubit.start(accessToken: 'tok');
      final sending = cubit.send(accessToken: 'tok', body: '  Tôi ra ngay ');
      expect(cubit.state.lines.single.delivery, ChatDelivery.sending);
      expect(cubit.state.lines.single.body, 'Tôi ra ngay');
      await sending;
      final sent = cubit.state.lines.single;
      expect(sent.delivery, ChatDelivery.sent);
      // The push of our own message arrives after the POST reply.
      rt.emitChatMessage(
        _hint(sent.key, 'me', 'Tôi ra ngay', repo.messages.single.createdAt),
      );
      await _flush();
      expect(cubit.state.lines, hasLength(1));
      await cubit.close();
      await rt.dispose();
    });

    test('failed send stays visible and retries in place', () async {
      final repo = FakeChatRepository()..failBodies.add('Chờ tôi 2 phút');
      final cubit = _cubit(repo);
      await cubit.start(accessToken: 'tok');
      await cubit.send(accessToken: 'tok', body: 'Chờ tôi 2 phút');
      final failed = cubit.state.lines.single;
      expect(failed.delivery, ChatDelivery.failed);
      await cubit.retry(failed.clientId!, accessToken: 'tok');
      expect(cubit.state.lines.single.delivery, ChatDelivery.sent);
      expect(repo.posted, ['Chờ tôi 2 phút', 'Chờ tôi 2 phút']);
      await cubit.close();
    });
  });

  group('buildChatTimeline', () {
    ChatLine line(String key, String sender, DateTime at, {String? body}) =>
        ChatLine(key: key, senderUserId: sender, body: body ?? key, at: at);

    test('groups same sender within 3 min; day + system rows', () {
      final d = DateTime(2026, 10, 25, 23, 58);
      final items = buildChatTimeline([
        line('a', 'drv', d),
        line('b', 'drv', d.add(const Duration(minutes: 1))),
        line('c', 'me', DateTime(2026, 10, 26, 0, 1)),
        line('d', 'me', DateTime(2026, 10, 26, 0, 2)),
        line('e', 'me', DateTime(2026, 10, 26, 0, 9)),
        line(
          'call',
          'me',
          DateTime(2026, 10, 26, 0, 10),
          body: '📞 Cuộc gọi nhỡ',
        ),
      ], currentUserId: 'me');
      expect(items.whereType<ChatDaySeparator>(), hasLength(2));
      final bubbles = items.whereType<ChatBubbleItem>().toList();
      String shape(ChatBubbleItem b) =>
          '${b.line.key}:${b.mine ? 'M' : 'T'}${b.first ? 'f' : ''}${b.last ? 'l' : ''}';
      expect(bubbles.map(shape), ['a:Tf', 'b:Tl', 'c:Mf', 'd:Ml', 'e:Mfl']);
      final system = items.whereType<ChatSystemItem>().single;
      expect(system.line.systemText, 'Cuộc gọi nhỡ');
    });

    test('day labels', () {
      final l10n = lookupAppLocalizations(const Locale('vi'));
      final now = DateTime(2026, 10, 26, 9);
      expect(chatDayLabel(l10n, DateTime(2026, 10, 26, 1), now), 'Hôm nay');
      expect(chatDayLabel(l10n, DateTime(2026, 10, 25, 23), now), 'Hôm qua');
      expect(chatDayLabel(l10n, DateTime(2026, 10, 2), now), '02/10');
    });
  });

  group('ChatUnread', () {
    tearDown(ChatUnread.instance.resetForTest);

    test('counts others only, dedupes, open thread resets', () async {
      final rt = FakeSnapshotRealtime();
      final unread = ChatUnread.instance..attach(rt, currentUserId: 'me');
      final key = ChatUnread.keyFor('Ride', 'r1');
      rt
        ..emitChatMessage(_hint('1', 'drv', 'a', t0))
        ..emitChatMessage(_hint('1', 'drv', 'a', t0))
        ..emitChatMessage(_hint('2', 'me', 'b', t0));
      await _flush();
      expect(unread.count(key), 1);
      unread.markOpen(key);
      expect(unread.count(key), 0);
      rt.emitChatMessage(_hint('3', 'drv', 'c', t0));
      await _flush();
      expect(unread.count(key), 0);
      unread.markClosed(key);
      rt.emitChatMessage(_hint('4', 'drv', 'd', t0));
      await _flush();
      expect(unread.count(key), 1);
      await rt.dispose();
    });
  });

  group('route ETA from cached leg (no request)', () {
    const leg = RouteGeometry(
      available: true,
      provider: 'mapbox',
      coords: [
        MapLatLng(lat: 16.0, lng: 108.0),
        MapLatLng(lat: 16.0, lng: 108.01),
        MapLatLng(lat: 16.0, lng: 108.02),
      ],
      durationSec: 600,
    );

    test('scales the leg duration by the share still ahead', () {
      expect(remainingRouteSec(leg, null), 600);
      expect(
        remainingRouteSec(leg, const MapLatLng(lat: 16.0005, lng: 108.01)),
        closeTo(300, 5),
      );
      expect(
        remainingRouteFraction(leg.coords, const MapLatLng(lat: 16, lng: 108)),
        closeTo(1, 0.001),
      );
      // Never shows 0 min while still moving.
      expect(remainingRouteSec(leg, const MapLatLng(lat: 16, lng: 108.02)), 60);
      expect(remainingRouteSec(RouteGeometry.unavailable, null), isNull);
    });

    testWidgets('ETA counts down on driver pings', (tester) async {
      final rt = FakeSnapshotRealtime();
      await tester.pumpWidget(
        RepositoryProvider<SnapshotRealtime>.value(
          value: rt,
          child: MaterialApp(
            home: PushedRouteEta(
              aggregateType: 'Ride',
              id: 'r1',
              phase: 'APPROACH',
              fallbackSec: null,
              seedRoute: leg,
              builder: (_, sec) => Text('eta:$sec'),
            ),
          ),
        ),
      );
      expect(find.text('eta:600'), findsOneWidget);
      rt.emitDriverLocation(
        DriverLocationHint(
          aggregateType: 'Ride',
          aggregateId: 'r1',
          lat: 16,
          lng: 108.01,
          at: t0,
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.textContaining('eta:30'), findsOneWidget);
    });
  });

  group('TransactionChatSheet', () {
    tearDown(ChatUnread.instance.resetForTest);

    Future<FakeChatRepository> pumpSheet(
      WidgetTester tester, {
      required ChatViewer viewer,
      List<String>? calls,
      FakeDriverCards? cards,
    }) async {
      final repo = FakeChatRepository(
        messages: [
          chatMessage('m1', 'drv', 'Tôi đang tới', DateTime.now().toUtc()),
        ],
      );
      await tester.pumpWidget(
        chatProviders(
          repo,
          extra: [
            RepositoryProvider<DriverCardRepository>.value(
              value: cards ?? FakeDriverCards(),
            ),
          ],
          child: MaterialApp(
            locale: const Locale('vi'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: TextButton(
                    key: const Key('open'),
                    onPressed: () => showTransactionChatSheet(
                      context: context,
                      kind: ChatThreadKind.ride,
                      resourceId: 'r1',
                      accessToken: 'tok',
                      currentUserId: 'me',
                      viewer: viewer,
                      onCall: () => calls?.add('call'),
                    ),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('open')));
      await tester.pumpAndSettle();
      return repo;
    }

    testWidgets('customer: one handle, header, quick reply sends', (
      tester,
    ) async {
      final cards = FakeDriverCards(
        card: const DriverCard(
          driverId: 'drv',
          displayName: 'Nguyễn Văn An',
          vehicleType: 'Xe máy',
          vehiclePlate: '43A-123.45',
        ),
      );
      final repo = await pumpSheet(
        tester,
        viewer: ChatViewer.customer,
        cards: cards,
      );
      expect(find.byKey(const Key('chat-handle')), findsOneWidget);
      // Theme handle is off: exactly one grabber in the sheet.
      expect(find.byKey(const Key('chat-handle')), findsOneWidget);
      expect(find.text('Nguyễn Văn An'), findsOneWidget);
      expect(find.text('Tài xế · Xe máy · 43A-123.45'), findsOneWidget);
      expect(find.text('Tôi đang tới'), findsOneWidget);
      expect(find.text('Hôm nay'), findsOneWidget);
      await tester.tap(find.text('Tôi đứng ở cổng'));
      await tester.pumpAndSettle();
      expect(repo.posted, ['Tôi đứng ở cổng']);
      expect(find.text('Đã gửi'), findsOneWidget);
    });

    testWidgets('driver: failed send shows retry; call closes sheet', (
      tester,
    ) async {
      final calls = <String>[];
      final repo = await pumpSheet(
        tester,
        viewer: ChatViewer.driver,
        calls: calls,
        cards: FakeDriverCards(customerName: 'Chị Lan'),
      );
      expect(find.text('Chị Lan'), findsOneWidget);
      expect(find.text('Tôi đã đến'), findsOneWidget);
      repo.failBodies.add('Đợi chút');
      await tester.enterText(find.byKey(const Key('chat-input')), 'Đợi chút');
      await tester.pump();
      await tester.tap(find.byKey(const Key('chat-send')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('chat-failed-label')), findsOneWidget);
      await tester.tap(find.text('Đợi chút'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('chat-failed-label')), findsNothing);
      expect(repo.posted, ['Đợi chút', 'Đợi chút']);
      await tester.tap(find.byKey(const Key('chat-call')));
      await tester.pumpAndSettle();
      expect(calls, ['call']);
      expect(find.byKey(const Key('chat-sheet')), findsNothing);
    });
  });
}
