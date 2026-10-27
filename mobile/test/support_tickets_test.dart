import 'package:dealgo/core/network/api_exception.dart';
import 'package:dealgo/features/support/data/support_remote_datasource.dart';
import 'package:dealgo/features/support/domain/support_ticket.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'support/auth_test_harness.dart';
import 'support/fake_identity_client.dart';

SupportTicket _ticket(
  String id, {
  SupportStatus status = SupportStatus.open,
  bool awaitingRequester = false,
  List<SupportMessage>? messages,
}) {
  final created = DateTime.utc(2026, 10, 18, 3);
  return SupportTicket(
    id: id,
    code: 'DG-261018-${id.hashCode.abs() % 9000 + 1000}',
    category: SupportCategory.ride,
    subject: 'Tài xế thu sai tiền $id',
    status: status,
    priority: SupportPriority.normal,
    awaitingRequester: awaitingRequester,
    lastMessageAt: created,
    createdAt: created,
    resolvedAt:
        status == SupportStatus.resolved || status == SupportStatus.closed
        ? created.add(const Duration(hours: 2))
        : null,
    closedAt: status == SupportStatus.closed
        ? created.add(const Duration(hours: 3))
        : null,
    messages:
        messages ??
        [
          SupportMessage(
            id: '$id-m1',
            fromStaff: false,
            body: 'Tài xế thu thêm 10.000 đ so với giá hiển thị.',
            createdAt: created,
          ),
        ],
  );
}

void _tallPhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

Future<void> _go(WidgetTester tester, String path) async {
  GoRouter.of(tester.element(find.byType(Scaffold).first)).push(path);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('help center creates a real ticket and lands on the list', (
    tester,
  ) async {
    _tallPhone(tester);
    final support = FakeSupportRepository();
    await pumpSignedIn(tester, profile: customerProfile, support: support);
    await _go(tester, '/customer/account/help');
    expect(find.text('Bản nháp này chưa được gửi.'), findsNothing);

    await tester.tap(find.byKey(const Key('help-create-ticket')));
    await tester.pumpAndSettle();

    // Validation runs before anything is sent.
    await tester.tap(find.byKey(const Key('support-submit')));
    await tester.pumpAndSettle();
    expect(support.created, isEmpty);

    await tester.enterText(
      find.byKey(const Key('support-subject')),
      'Thu sai tiền',
    );
    await tester.enterText(
      find.byKey(const Key('support-description')),
      'Tài xế thu thêm tiền mặt so với giá trên ứng dụng.',
    );
    await tester.tap(find.byKey(const Key('support-submit')));
    await tester.pumpAndSettle();

    expect(support.created, hasLength(1));
    expect(support.created.single.role, 'CUSTOMER');
    expect(find.text('Thu sai tiền'), findsOneWidget);
    expect(find.text('Đã tiếp nhận'), findsWidgets);
  });

  testWidgets('limit reached shows the server rule instead of a fake success', (
    tester,
  ) async {
    _tallPhone(tester);
    final support = FakeSupportRepository()
      ..failNext = const ApiException(
        statusCode: 409,
        message: 'Too many',
        errorCode: 'SUPPORT_TICKET_LIMIT_REACHED',
      );
    await pumpSignedIn(tester, profile: customerProfile, support: support);
    await _go(tester, '/customer/account/help/tickets/new');
    await tester.enterText(
      find.byKey(const Key('support-subject')),
      'Hoàn tiền',
    );
    await tester.enterText(
      find.byKey(const Key('support-description')),
      'Tôi chưa nhận được tiền hoàn của đơn hôm qua.',
    );
    await tester.tap(find.byKey(const Key('support-submit')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('support-form-error')), findsOneWidget);
    expect(
      find.textContaining('nhiều yêu cầu chưa xử lý xong'),
      findsOneWidget,
    );
  });

  testWidgets('list filters by state and opens a staff-replied ticket', (
    tester,
  ) async {
    _tallPhone(tester);
    final support = FakeSupportRepository(
      seed: [
        _ticket(
          'a',
          status: SupportStatus.inProgress,
          awaitingRequester: true,
          messages: [
            SupportMessage(
              id: 'a1',
              fromStaff: false,
              body: 'Tài xế thu thêm tiền.',
              createdAt: DateTime.utc(2026, 10, 18, 3),
            ),
            SupportMessage(
              id: 'a2',
              fromStaff: true,
              body: 'DealGo đã ghi nhận và đang liên hệ tài xế.',
              createdAt: DateTime.utc(2026, 10, 18, 4),
            ),
          ],
        ),
        _ticket('b', status: SupportStatus.resolved),
      ],
    );
    await pumpSignedIn(tester, profile: customerProfile, support: support);
    await _go(tester, '/customer/account/help/tickets');
    expect(find.text('Đã phản hồi'), findsOneWidget);
    expect(find.text('Tất cả · 2'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('support-filter-done')));
    await tester.tap(find.byKey(const Key('support-filter-done')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('support-ticket-a')), findsNothing);
    expect(find.byKey(const Key('support-ticket-b')), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('support-filter-all')));
    await tester.tap(find.byKey(const Key('support-filter-all')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('support-ticket-a')));
    await tester.pumpAndSettle();

    final staffBody = find.text('DealGo đã ghi nhận và đang liên hệ tài xế.');
    await tester.scrollUntilVisible(
      staffBody,
      200,
      scrollable: find
          .descendant(
            of: find.byType(RefreshIndicator),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(staffBody, findsOneWidget);
    expect(find.text('Hỗ trợ DealGo'), findsWidgets);

    await tester.enterText(
      find.byKey(const Key('support-reply-field')),
      'Cảm ơn, tôi chờ phản hồi.',
    );
    await tester.tap(find.byKey(const Key('support-reply-send')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Cảm ơn, tôi chờ phản hồi.'),
      200,
      scrollable: find
          .descendant(
            of: find.byType(RefreshIndicator),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('Cảm ơn, tôi chờ phản hồi.'), findsOneWidget);
    expect(
      support.tickets.firstWhere((t) => t.id == 'a').messages,
      hasLength(3),
    );
  });

  testWidgets('closed ticket hides the composer', (tester) async {
    _tallPhone(tester);
    final support = FakeSupportRepository(
      seed: [_ticket('c', status: SupportStatus.closed)],
    );
    await pumpSignedIn(tester, profile: customerProfile, support: support);
    await _go(tester, '/customer/account/help/tickets/c');
    expect(find.byKey(const Key('support-closed-note')), findsOneWidget);
    expect(find.byKey(const Key('support-reply-field')), findsNothing);
    expect(find.text('Đã đóng'), findsWidgets);
  });
}
