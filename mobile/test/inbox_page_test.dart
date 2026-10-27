import 'package:dealgo/features/inbox/data/datasources/inbox_remote_datasource.dart';
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
    expect(find.text('Tài xế đã đến điểm đón'), findsOneWidget);
    expect(find.text('Quán đang chuẩn bị món'), findsOneWidget);
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
}
