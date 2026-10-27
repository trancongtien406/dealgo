import 'package:flutter/foundation.dart';

/// Delivery state of a line the user sees. The backend has no delivered/read
/// receipts, so "sent" = the server stored it.
enum ChatDelivery { sending, sent, failed }

/// One renderable chat line: a server message or a local pending one.
@immutable
class ChatLine {
  const ChatLine({
    required this.key,
    required this.senderUserId,
    required this.body,
    required this.at,
    this.delivery = ChatDelivery.sent,
    this.clientId,
  });

  /// Server id, or `local:<clientId>` for a pending line.
  final String key;
  final String senderUserId;
  final String body;

  /// Always device-local time (server sends UTC).
  final DateTime at;
  final ChatDelivery delivery;
  final String? clientId;

  /// Server-written call notes ("📞 Cuộc gọi nhỡ") render as system rows.
  bool get isSystem => body.startsWith('📞');

  /// System text without the leading emoji.
  String get systemText => body.replaceFirst('📞', '').trim();
}

sealed class ChatTimelineItem {
  const ChatTimelineItem();
}

/// "Hôm nay" / "Hôm qua" / date header before the first line of a day.
final class ChatDaySeparator extends ChatTimelineItem {
  const ChatDaySeparator(this.day);

  /// Local midnight of that day.
  final DateTime day;
}

final class ChatSystemItem extends ChatTimelineItem {
  const ChatSystemItem(this.line);

  final ChatLine line;
}

/// A bubble. [first]/[last] mark its position in a run of consecutive
/// messages from the same sender (tail + time go on the last one).
final class ChatBubbleItem extends ChatTimelineItem {
  const ChatBubbleItem({
    required this.line,
    required this.mine,
    required this.first,
    required this.last,
  });

  final ChatLine line;
  final bool mine;
  final bool first;
  final bool last;
}

/// Messages from the same sender closer than this form one group.
const chatGroupGap = Duration(minutes: 3);

DateTime _day(DateTime at) => DateTime(at.year, at.month, at.day);

/// Builds the rendered timeline (oldest → newest) from ordered [lines].
List<ChatTimelineItem> buildChatTimeline(
  List<ChatLine> lines, {
  required String? currentUserId,
}) {
  final items = <ChatTimelineItem>[];
  DateTime? lastDay;
  for (var i = 0; i < lines.length; i += 1) {
    final line = lines[i];
    final day = _day(line.at);
    if (lastDay == null || day != lastDay) {
      items.add(ChatDaySeparator(day));
      lastDay = day;
    }
    if (line.isSystem) {
      items.add(ChatSystemItem(line));
      continue;
    }
    final prev = i > 0 ? lines[i - 1] : null;
    final next = i + 1 < lines.length ? lines[i + 1] : null;
    items.add(
      ChatBubbleItem(
        line: line,
        mine: _isMine(line, currentUserId),
        first: prev == null || !_sameGroup(prev, line),
        last: next == null || !_sameGroup(line, next),
      ),
    );
  }
  return items;
}

bool _isMine(ChatLine line, String? currentUserId) =>
    line.clientId != null ||
    (currentUserId != null && line.senderUserId == currentUserId);

bool _sameGroup(ChatLine a, ChatLine b) =>
    !a.isSystem &&
    !b.isSystem &&
    a.senderUserId == b.senderUserId &&
    _day(a.at) == _day(b.at) &&
    b.at.difference(a.at).abs() < chatGroupGap &&
    (a.delivery == ChatDelivery.failed) == (b.delivery == ChatDelivery.failed);

/// `HH:mm` in local time.
String chatClock(DateTime at) {
  final local = at.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(local.hour)}:${two(local.minute)}';
}
