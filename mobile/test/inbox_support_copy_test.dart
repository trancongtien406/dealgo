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
}
