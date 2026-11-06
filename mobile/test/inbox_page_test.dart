import 'package:dealgo/core/realtime/fake_snapshot_realtime.dart';
import 'package:dealgo/features/inbox/data/datasources/inbox_remote_datasource.dart';
import 'package:dealgo/features/inbox/domain/entities/inbox_notification.dart';
import 'package:dealgo/features/inbox/presentation/inbox_unread.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/auth_test_harness.dart';
import 'support/fake_identity_client.dart';

Future<FakeInboxRemoteDataSource> _openInbox(WidgetTester tester) async {
  final inbox = FakeInboxRemoteDataSource(now: DateTime.now());
  await pumpSignedIn(tester, profile: customerProfile, inboxRemote: inbox);
  await tester.tap(navLabel('Tôi'));
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('Thông báo'));
  await tester.pumpAndSettle();
  return inbox;
}

void main() {
  testWidgets('inbox lists server notifications by day with unread state', (
    tester,
  ) async {
    await _openInbox(tester);

    expect(find.text('Hôm nay'), findsOneWidget);
    expect(find.text('Tài xế đã đến'), findsOneWidget);
    expect(find.text('Quán đang làm món'), findsOneWidget);
    expect(find.byKey(const Key('inbox-unread-dot')), findsNWidgets(2));
    expect(find.byKey(const Key('inbox-mark-all')), findsOneWidget);
  });

  testWidgets('mark all read clears unread markers and persists', (
    tester,
  ) async {
    final inbox = await _openInbox(tester);

    await tester.tap(find.byKey(const Key('inbox-mark-all')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('inbox-mark-all')), findsNothing);
    expect(find.byKey(const Key('inbox-unread-dot')), findsNothing);
    final page = await inbox.list(accessToken: 'access-token');
    expect(page.unreadCount, 0);
  });

  testWidgets('category filter narrows the list', (tester) async {
    await _openInbox(tester);

    await tester.tap(find.text('Ưu đãi').last);
    await tester.pumpAndSettle();

    expect(find.text('Giảm 20.000đ cho đơn đồ ăn'), findsOneWidget);
    expect(find.text('Tài xế đã đến điểm đón'), findsNothing);
  });

  testWidgets('bell badges follow the real unread count', (tester) async {
    final inbox = FakeInboxRemoteDataSource(now: DateTime.now());
    await pumpSignedIn(tester, profile: customerProfile, inboxRemote: inbox);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home-bell-unread')), findsOneWidget);

    await tester.tap(navLabel('Tôi'));
    await tester.pumpAndSettle();
    expect(InboxUnread.instance.count, 2);
    await tester.tap(find.byTooltip('Thông báo'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('inbox-mark-all')));
    await tester.pumpAndSettle();

    expect(InboxUnread.instance.count, 0);
    await tester.tap(navLabel('Trang'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home-bell-unread')), findsNothing);
  });

  test('an inbox push bumps the count and a reconnect re-reads it', () async {
    final realtime = FakeSnapshotRealtime();
    var server = 0;
    InboxUnread.instance.attach(
      userId: 'u1',
      realtime: realtime,
      fetch: () async => server,
    );
    await Future<void>.delayed(Duration.zero);
    expect(InboxUnread.instance.count, 0);

    realtime.emitInbox();
    await Future<void>.delayed(Duration.zero);
    expect(InboxUnread.instance.count, 1);

    server = 5;
    realtime.emitReconnect();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(InboxUnread.instance.count, 5);
    await realtime.dispose();
  });

  testWidgets('scrolling near the end loads older notifications', (
    tester,
  ) async {
    final now = DateTime.now();
    final inbox = FakeInboxRemoteDataSource(
      now: now,
      seed: [
        for (var i = 0; i < 35; i++)
          InboxNotification(
            id: 'p$i',
            category: InboxCategory.system,
            title: 'Thông báo $i',
            body: 'Nội dung $i',
            read: true,
            createdAt: now.subtract(Duration(minutes: i)),
          ),
      ],
    );
    await pumpSignedIn(tester, profile: customerProfile, inboxRemote: inbox);
    await tester.tap(navLabel('Tôi'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Thông báo'));
    await tester.pumpAndSettle();

    expect(find.text('Thông báo 0'), findsOneWidget);
    expect(find.text('Thông báo 34'), findsNothing);

    await tester.drag(find.byType(ListView).last, const Offset(0, -4000));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Thông báo 34'),
      400,
      scrollable: find
          .descendant(
            of: find.byType(ListView).last,
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('Thông báo 34'), findsOneWidget);
  });
}
