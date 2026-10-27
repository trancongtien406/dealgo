import 'package:dealgo/features/inbox/domain/entities/inbox_notification.dart';
import 'package:dealgo/features/shell/presentation/inbox_copy.dart';
import 'package:dealgo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

InboxNotification _notice(String status) => InboxNotification(
  id: 'n-$status',
  category: InboxCategory.system,
  title: 'server title',
  body: 'DealGo đã liên hệ tài xế.',
  read: false,
  createdAt: DateTime.utc(2026, 10, 19),
  aggregateType: 'SupportTicket',
  aggregateId: 'ticket-1',
  status: status,
);

void main() {
  test('support notices use localized titles and keep the reply preview', () {
    final vi = lookupAppLocalizations(const Locale('vi'));
    final en = lookupAppLocalizations(const Locale('en'));

    final reply = inboxCopy(vi, _notice('IN_PROGRESS'));
    expect(reply.title, vi.inboxSupportReplyTitle);
    expect(reply.body, 'DealGo đã liên hệ tài xế.');

    expect(
      inboxCopy(vi, _notice('RESOLVED')).title,
      vi.inboxSupportResolvedTitle,
    );
    expect(
      inboxCopy(en, _notice('RESOLVED')).title,
      en.inboxSupportResolvedTitle,
    );
    expect(en.inboxSupportResolvedTitle, isNot(vi.inboxSupportResolvedTitle));
  });

  // Sim run 89: the driver inbox showed the customer copy "Đã có tài xế nhận
  // chuyến" over the driver's own "Khách đã chọn bạn" row.
  test('driver / merchant rows keep their server copy', () {
    final vi = lookupAppLocalizations(const Locale('vi'));
    final driver = inboxCopy(vi, _jobNotice('Ride', 'ASSIGNED', 'DRIVER'));
    expect(driver.title, 'Khách đã chọn bạn');
    expect(driver.body, 'Chuyến #B4D2: hãy di chuyển đến điểm đón.');
    expect(
      inboxCopy(vi, _jobNotice('FoodOrder', 'PREPARING', 'MERCHANT')).title,
      'Khách đã chọn bạn',
    );
    expect(
      inboxCopy(vi, _jobNotice('Ride', 'ASSIGNED', 'CUSTOMER')).title,
      vi.inboxRideAssignedTitle,
    );
    expect(
      inboxCopy(vi, _jobNotice('Ride', 'ASSIGNED', null)).title,
      vi.inboxRideAssignedTitle,
    );
  });

  // the unassign notice (ASSIGNED → NEGOTIATING) and the driver's own
  // cancel / missed-call rows keep the driver copy the server wrote.
  test('driver rows for every ride status keep the driver copy', () {
    final vi = lookupAppLocalizations(const Locale('vi'));
    for (final status in [
      'NEGOTIATING',
      'CANCELLED',
      'DRIVER_EN_ROUTE',
      'COMPLETED',
    ]) {
      final copy = inboxCopy(vi, _jobNotice('Ride', status, 'DRIVER'));
      expect(copy.title, 'Khách đã chọn bạn', reason: status);
      expect(
        copy.body,
        'Chuyến #B4D2: hãy di chuyển đến điểm đón.',
        reason: status,
      );
    }
    expect(
      inboxCopy(vi, _jobNotice('FoodOrder', 'CANCELLED', 'DRIVER')).title,
      'Khách đã chọn bạn',
    );
  });
}

InboxNotification _jobNotice(String type, String status, String? role) =>
    InboxNotification(
      id: 'j-$type-$status-$role',
      category: type == 'Ride' ? InboxCategory.ride : InboxCategory.food,
      title: 'Khách đã chọn bạn',
      body: 'Chuyến #B4D2: hãy di chuyển đến điểm đón.',
      read: false,
      createdAt: DateTime.utc(2026, 10, 26),
      aggregateType: type,
      aggregateId: 'job-1',
      status: status,
      role: role,
    );
