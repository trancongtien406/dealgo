import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/config/api_base_url.dart';
import '../../../../core/design_system/icons/dealgo_icons.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../core/network/api_error_l10n.dart';
import '../../../../core/realtime/snapshot_realtime.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../driver_card/domain/driver_card.dart';
import '../../domain/usecases/list_food_order_chat_messages.dart';
import '../../domain/usecases/list_ride_chat_messages.dart';
import '../../domain/usecases/send_food_order_chat_message.dart';
import '../../domain/usecases/send_ride_chat_message.dart';
import '../cubit/chat_cubit.dart';
import '../model/chat_timeline.dart';
import '../model/chat_unread.dart';

/// Who is looking at the thread (header + quick replies).
enum ChatViewer { customer, driver }

/// The other party shown in the sheet header.
class ChatCounterpart {
  const ChatCounterpart({required this.name, this.detail, this.avatarUrl});

  final String name;

  /// Customer side: "Xe máy · 43A-123.45"; driver side: null.
  final String? detail;
  final String? avatarUrl;
}

T? _tryRead<T>(BuildContext context) {
  try {
    return context.read<T>();
  } on Object {
    return null;
  }
}

/// Opens the ride / food-order chat (r25 redesign: one handle, compact header
/// with call, grouped bubbles with time + send state, quick replies).
Future<void> showTransactionChatSheet({
  required BuildContext context,
  required ChatThreadKind kind,
  required String resourceId,
  required String? accessToken,
  String? currentUserId,
  ChatViewer viewer = ChatViewer.customer,
  VoidCallback? onCall,
}) {
  final realtime = _tryRead<SnapshotRealtime>(context);
  final cards = _tryRead<DriverCardRepository>(context);
  final listRide = context.read<ListRideChatMessages>();
  final sendRide = context.read<SendRideChatMessage>();
  final listFood = context.read<ListFoodOrderChatMessages>();
  final sendFood = context.read<SendFoodOrderChatMessage>();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    // The theme adds a drag handle to every sheet; this one draws its own.
    showDragHandle: false,
    useSafeArea: false,
    backgroundColor: DealGoColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(DealGoRadius.sheet),
      ),
    ),
    clipBehavior: Clip.antiAlias,
    builder: (sheetContext) {
      return BlocProvider(
        create: (_) => ChatCubit(
          listRideChatMessages: listRide,
          sendRideChatMessage: sendRide,
          listFoodOrderChatMessages: listFood,
          sendFoodOrderChatMessage: sendFood,
          kind: kind,
          resourceId: resourceId,
          currentUserId: currentUserId,
          realtime: realtime,
        )..start(accessToken: accessToken),
        child: TransactionChatSheet(
          kind: kind,
          resourceId: resourceId,
          accessToken: accessToken,
          currentUserId: currentUserId,
          viewer: viewer,
          onCall: onCall == null
              ? null
              : () {
                  Navigator.of(sheetContext).pop();
                  onCall();
                },
          cards: cards,
        ),
      );
    },
  );
}

class TransactionChatSheet extends StatefulWidget {
  const TransactionChatSheet({
    required this.kind,
    required this.resourceId,
    required this.accessToken,
    this.currentUserId,
    this.viewer = ChatViewer.customer,
    this.onCall,
    this.counterpart,
    this.cards,
    super.key,
  });

  final ChatThreadKind kind;
  final String resourceId;
  final String? accessToken;
  final String? currentUserId;
  final ChatViewer viewer;
  final VoidCallback? onCall;

  /// Preset header (tests / previews); otherwise loaded once per job.
  final ChatCounterpart? counterpart;
  final DriverCardRepository? cards;

  @override
  State<TransactionChatSheet> createState() => _TransactionChatSheetState();
}

/// One header lookup per job per app session (no request per open).
final _counterpartMemo = <String, ChatCounterpart>{};

class _TransactionChatSheetState extends State<TransactionChatSheet> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final _focus = FocusNode();
  ChatCounterpart? _counterpart;
  var _hasText = false;

  String get _unreadKey =>
      ChatUnread.keyFor(widget.kind.aggregateType, widget.resourceId);
  String get _memoKey => '${widget.viewer.name}:$_unreadKey';

  @override
  void initState() {
    super.initState();
    ChatUnread.instance.markOpen(_unreadKey);
    _counterpart = widget.counterpart ?? _counterpartMemo[_memoKey];
    if (_counterpart == null) {
      unawaited(_loadCounterpart());
    }
    _controller.addListener(() {
      final has = _controller.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
  }

  Future<void> _loadCounterpart() async {
    final cards = widget.cards;
    final token = widget.accessToken ?? '';
    if (cards == null || token.isEmpty) return;
    try {
      final ChatCounterpart value;
      if (widget.viewer == ChatViewer.customer) {
        final card = await cards.fetch(
          accessToken: token,
          job: widget.kind == ChatThreadKind.ride
              ? DriverCardJob.ride
              : DriverCardJob.foodOrder,
          jobId: widget.resourceId,
        );
        value = ChatCounterpart(
          name: card.displayName,
          detail: card.vehicleLine,
          avatarUrl: card.avatarUrl,
        );
      } else {
        final name = await cards.fetchCustomerName(
          accessToken: token,
          jobId: widget.resourceId,
          isFood: widget.kind == ChatThreadKind.foodOrder,
        );
        value = ChatCounterpart(name: name);
      }
      if (value.name.trim().isEmpty) return;
      _counterpartMemo[_memoKey] = value;
      if (mounted) setState(() => _counterpart = value);
    } on Object {
      // Header falls back to the role label.
    }
  }

  @override
  void dispose() {
    ChatUnread.instance.markClosed(_unreadKey);
    _controller.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _toBottom() {
    if (!_scroll.hasClients) return;
    unawaited(
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      ),
    );
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _controller.text).trim();
    if (text.isEmpty) return;
    if (preset == null) _controller.clear();
    _toBottom();
    await context.read<ChatCubit>().send(
      accessToken: widget.accessToken,
      body: text,
    );
  }

  List<String> _quickReplies(AppLocalizations l10n) {
    final food = widget.kind == ChatThreadKind.foodOrder;
    return widget.viewer == ChatViewer.driver
        ? [
            if (food)
              l10n.chatQuickDriverDelivering
            else
              l10n.chatQuickDriverComing,
            l10n.chatQuickDriverArrived,
            l10n.chatQuickDriverWait,
          ]
        : [
            if (!food) l10n.chatQuickCustomerGate,
            l10n.chatQuickCustomerComing,
            if (food) l10n.chatQuickCustomerLeaveAtGate,
            l10n.chatQuickCustomerWhere,
          ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final media = MediaQuery.of(context);
    final keyboard = media.viewInsets.bottom;
    final maxHeight = media.size.height - keyboard - media.padding.top - 8;
    final height = (media.size.height * 0.82).clamp(0.0, maxHeight);
    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: SizedBox(
        key: const Key('chat-sheet'),
        height: height,
        child: Column(
          children: [
            const _Handle(),
            _Header(
              viewer: widget.viewer,
              counterpart: _counterpart,
              onCall: widget.onCall,
            ),
            const Divider(height: 1, color: DealGoColors.divider),
            Expanded(
              child: ColoredBox(
                color: DealGoColors.canvas,
                child: BlocConsumer<ChatCubit, ChatState>(
                  listenWhen: (a, b) =>
                      a.lines.length != b.lines.length ||
                      (b.sendError != null && a.sendError != b.sendError),
                  listener: (context, state) {
                    final error = state.sendError;
                    if (error != null) {
                      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                        SnackBar(
                          content: Text(
                            localizedFailureMessage(context, error),
                          ),
                        ),
                      );
                      context.read<ChatCubit>().clearSendError();
                    }
                  },
                  builder: (context, state) => _Timeline(
                    state: state,
                    scroll: _scroll,
                    currentUserId: widget.currentUserId,
                    accessToken: widget.accessToken,
                  ),
                ),
              ),
            ),
            _QuickReplies(
              replies: _quickReplies(l10n),
              onTap: (text) => unawaited(_send(text)),
            ),
            _Composer(
              controller: _controller,
              focus: _focus,
              canSend: _hasText,
              onSend: () => unawaited(_send()),
              bottomInset: keyboard > 0 ? 0 : media.viewPadding.bottom,
            ),
          ],
        ),
      ),
    );
  }
}

class _Handle extends StatelessWidget {
  const _Handle();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: DealGoSpacing.s8),
    child: Container(
      key: const Key('chat-handle'),
      width: 36,
      height: 4,
      decoration: BoxDecoration(
        color: DealGoColors.border,
        borderRadius: BorderRadius.circular(DealGoRadius.pill),
      ),
    ),
  );
}

class _Header extends StatelessWidget {
  const _Header({required this.viewer, this.counterpart, this.onCall});

  final ChatViewer viewer;
  final ChatCounterpart? counterpart;
  final VoidCallback? onCall;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final role = viewer == ChatViewer.customer
        ? l10n.chatRoleDriver
        : l10n.chatRoleCustomer;
    final name = counterpart?.name ?? role;
    final detail = counterpart == null
        ? null
        : [role, ?counterpart?.detail].join(' · ');
    final avatar = resolveMediaUrl(counterpart?.avatarUrl);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DealGoSpacing.s16,
        DealGoSpacing.s8,
        DealGoSpacing.s4,
        DealGoSpacing.s8,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: DealGoColors.subtlePurple,
            foregroundImage: avatar == null ? null : NetworkImage(avatar),
            child: counterpart == null
                ? Icon(
                    viewer == ChatViewer.customer
                        ? DealGoIcons.car
                        : DealGoIcons.userRound,
                    size: 20,
                    color: DealGoColors.primary,
                  )
                : Text(
                    name.characters.first.toUpperCase(),
                    style: const TextStyle(
                      color: DealGoColors.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
          ),
          const SizedBox(width: DealGoSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  key: const Key('chat-header-name'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (detail != null)
                  Text(
                    detail,
                    key: const Key('chat-header-detail'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall?.copyWith(
                      color: DealGoColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          if (onCall != null)
            _RoundAction(
              key: const Key('chat-call'),
              icon: DealGoIcons.phone,
              tooltip: l10n.chatCallAction,
              filled: true,
              onPressed: onCall!,
            ),
          if (onCall != null)
            // 48 pt tap boxes around 44 pt circles: 8 + 2 × 2 = 12 pt visual gap.
            const SizedBox(width: 8),
          _RoundAction(
            key: const Key('chat-close'),
            icon: DealGoIcons.close,
            tooltip: l10n.chatCloseAction,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ],
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.filled = false,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: DealGoDimensions.minTapTarget,
    height: DealGoDimensions.minTapTarget,
    child: Center(
      child: Material(
        color: filled ? DealGoColors.subtlePurple : Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: Tooltip(
            message: tooltip,
            child: SizedBox(
              width: 44,
              height: 44,
              child: Icon(
                icon,
                size: 22,
                color: filled
                    ? DealGoColors.primary
                    : DealGoColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _Timeline extends StatelessWidget {
  const _Timeline({
    required this.state,
    required this.scroll,
    required this.currentUserId,
    required this.accessToken,
  });

  final ChatState state;
  final ScrollController scroll;
  final String? currentUserId;
  final String? accessToken;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    if (!state.loaded && state.loadError == null) {
      return const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2.4),
        ),
      );
    }
    if (!state.loaded && state.loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(DealGoSpacing.s24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                localizedFailureMessage(context, state.loadError!),
                key: const Key('chat-load-error'),
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  color: DealGoColors.textSecondary,
                ),
              ),
              const SizedBox(height: DealGoSpacing.s8),
              TextButton(
                key: const Key('chat-reload'),
                onPressed: () =>
                    context.read<ChatCubit>().load(accessToken: accessToken),
                child: Text(l10n.actionRetry),
              ),
            ],
          ),
        ),
      );
    }
    if (state.lines.isEmpty) {
      return Center(
        key: const Key('chat-empty'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: DealGoColors.subtlePurple,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                DealGoIcons.chatBubbles,
                color: DealGoColors.primary,
              ),
            ),
            const SizedBox(height: DealGoSpacing.s12),
            Text(l10n.chatEmpty, style: textTheme.titleSmall),
            const SizedBox(height: DealGoSpacing.s4),
            Text(
              l10n.chatEmptyBody,
              style: textTheme.bodySmall?.copyWith(
                color: DealGoColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }
    final items = buildChatTimeline(
      state.lines,
      currentUserId: currentUserId,
    ).reversed.toList();
    // Reversed list: offset 0 is the newest message, so new lines land in view
    // and a short thread sits right above the input (no dead gap).
    return ListView.builder(
      key: const Key('chat-list'),
      controller: scroll,
      reverse: true,
      padding: const EdgeInsets.fromLTRB(
        DealGoSpacing.s12,
        DealGoSpacing.s8,
        DealGoSpacing.s12,
        DealGoSpacing.s8,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) => switch (items[index]) {
        final ChatDaySeparator item => _DayChip(day: item.day),
        final ChatSystemItem item => _SystemRow(line: item.line),
        final ChatBubbleItem item => _Bubble(
          item: item,
          accessToken: accessToken,
        ),
      },
    );
  }
}

String chatDayLabel(AppLocalizations l10n, DateTime day, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final d = DateTime(day.year, day.month, day.day);
  final diff = today.difference(d).inDays;
  if (diff == 0) return l10n.chatToday;
  if (diff == 1) return l10n.chatYesterday;
  String two(int v) => v.toString().padLeft(2, '0');
  return d.year == today.year
      ? '${two(d.day)}/${two(d.month)}'
      : '${two(d.day)}/${two(d.month)}/${d.year}';
}

class _DayChip extends StatelessWidget {
  const _DayChip({required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      key: const Key('chat-day-separator'),
      padding: const EdgeInsets.symmetric(vertical: DealGoSpacing.s8),
      child: Center(
        child: Text(
          chatDayLabel(l10n, day, DateTime.now()),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: DealGoColors.textTertiary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _SystemRow extends StatelessWidget {
  const _SystemRow({required this.line});

  final ChatLine line;

  @override
  Widget build(BuildContext context) => Padding(
    key: const Key('chat-system-row'),
    padding: const EdgeInsets.symmetric(vertical: DealGoSpacing.s8),
    child: Center(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: DealGoSpacing.s12,
          vertical: DealGoSpacing.s6,
        ),
        decoration: BoxDecoration(
          color: DealGoColors.card,
          border: Border.all(color: DealGoColors.border),
          borderRadius: BorderRadius.circular(DealGoRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              DealGoIcons.phoneMissed,
              size: 14,
              color: DealGoColors.danger,
            ),
            const SizedBox(width: DealGoSpacing.s6),
            Flexible(
              child: Text(
                '${line.systemText} · ${chatClock(line.at)}',
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: DealGoColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.item, required this.accessToken});

  final ChatBubbleItem item;
  final String? accessToken;

  static const _big = Radius.circular(18);
  static const _small = Radius.circular(6);
  static const _tail = Radius.circular(2);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final line = item.line;
    final mine = item.mine;
    final failed = line.delivery == ChatDelivery.failed;
    final background = mine
        ? (failed ? DealGoColors.dangerSurface : DealGoColors.primary)
        : DealGoColors.card;
    final foreground = mine && !failed ? Colors.white : DealGoColors.text;
    // Grouped corners; the last bubble of a group gets the tail corner.
    final radius = mine
        ? BorderRadius.only(
            topLeft: _big,
            bottomLeft: _big,
            topRight: item.first ? _big : _small,
            bottomRight: item.last ? _tail : _small,
          )
        : BorderRadius.only(
            topRight: _big,
            bottomRight: _big,
            topLeft: item.first ? _big : _small,
            bottomLeft: item.last ? _tail : _small,
          );
    final maxWidth = MediaQuery.sizeOf(context).width * 0.74;
    final bubble = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: CustomPaint(
        painter: item.last
            ? _TailPainter(color: background, right: mine, border: !mine)
            : null,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: DealGoSpacing.s12,
            vertical: DealGoSpacing.s8,
          ),
          decoration: BoxDecoration(
            color: background,
            borderRadius: radius,
            border: mine ? null : Border.all(color: DealGoColors.border),
          ),
          child: Text(
            line.body,
            style: textTheme.bodyMedium?.copyWith(
              color: foreground,
              height: 1.3,
            ),
          ),
        ),
      ),
    );
    final meta = item.last ? _meta(context, l10n, textTheme) : null;
    return Padding(
      key: Key('chat-bubble-${line.key}'),
      padding: EdgeInsets.only(top: item.first ? DealGoSpacing.s8 : 2),
      child: Column(
        crossAxisAlignment: mine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          if (failed)
            GestureDetector(
              key: Key('chat-retry-${line.clientId}'),
              onTap: () => context.read<ChatCubit>().retry(
                line.clientId!,
                accessToken: accessToken,
              ),
              child: bubble,
            )
          else
            bubble,
          ?meta,
        ],
      ),
    );
  }

  Widget _meta(
    BuildContext context,
    AppLocalizations l10n,
    TextTheme textTheme,
  ) {
    final line = item.line;
    final style = textTheme.labelSmall?.copyWith(
      color: DealGoColors.textTertiary,
      fontWeight: FontWeight.w500,
    );
    final children = <Widget>[Text(chatClock(line.at), style: style)];
    if (item.mine) {
      switch (line.delivery) {
        case ChatDelivery.sending:
          children.addAll([
            const SizedBox(width: DealGoSpacing.s4),
            const Icon(
              DealGoIcons.clock,
              size: 12,
              color: DealGoColors.textTertiary,
            ),
            const SizedBox(width: 2),
            Text(l10n.chatStatusSending, style: style),
          ]);
        case ChatDelivery.sent:
          children.addAll([
            const SizedBox(width: DealGoSpacing.s4),
            const Icon(
              DealGoIcons.check,
              size: 12,
              color: DealGoColors.textTertiary,
            ),
            const SizedBox(width: 2),
            Text(l10n.chatStatusSent, style: style),
          ]);
        case ChatDelivery.failed:
          children
            ..clear()
            ..addAll([
              const Icon(
                DealGoIcons.alert,
                size: 12,
                color: DealGoColors.danger,
              ),
              const SizedBox(width: DealGoSpacing.s4),
              Text(
                l10n.chatStatusFailed,
                key: const Key('chat-failed-label'),
                style: style?.copyWith(
                  color: DealGoColors.danger,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ]);
      }
    }
    return Padding(
      padding: const EdgeInsets.only(top: 3, left: 4, right: 4),
      child: Row(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

/// Small curved tail under the last bubble's corner.
class _TailPainter extends CustomPainter {
  const _TailPainter({
    required this.color,
    required this.right,
    required this.border,
  });

  final Color color;
  final bool right;
  final bool border;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height;
    final path = Path();
    if (right) {
      final x = size.width;
      path
        ..moveTo(x - 12, y)
        ..quadraticBezierTo(x - 2, y, x + 5, y + 0.5)
        ..quadraticBezierTo(x - 1, y - 3, x - 1, y - 12)
        ..close();
    } else {
      path
        ..moveTo(12, y)
        ..quadraticBezierTo(2, y, -5, y + 0.5)
        ..quadraticBezierTo(1, y - 3, 1, y - 12)
        ..close();
    }
    if (border) {
      canvas.drawPath(
        path,
        Paint()
          ..color = DealGoColors.border
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_TailPainter old) =>
      old.color != color || old.right != right || old.border != border;
}

class _QuickReplies extends StatelessWidget {
  const _QuickReplies({required this.replies, required this.onTap});

  final List<String> replies;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelMedium?.copyWith(
      color: DealGoColors.primaryDeep,
      fontWeight: FontWeight.w600,
    );
    return Container(
      color: DealGoColors.card,
      height: 44,
      child: ListView.separated(
        key: const Key('chat-quick-replies'),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(
          DealGoSpacing.s12,
          DealGoSpacing.s8,
          DealGoSpacing.s12,
          0,
        ),
        itemCount: replies.length,
        separatorBuilder: (_, _) => const SizedBox(width: DealGoSpacing.s8),
        itemBuilder: (context, i) => Material(
          color: DealGoColors.subtlePurple,
          borderRadius: BorderRadius.circular(DealGoRadius.pill),
          child: InkWell(
            key: Key('chat-quick-$i'),
            borderRadius: BorderRadius.circular(DealGoRadius.pill),
            onTap: () => onTap(replies[i]),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: DealGoSpacing.s12,
              ),
              child: Center(child: Text(replies[i], style: style)),
            ),
          ),
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.focus,
    required this.canSend,
    required this.onSend,
    required this.bottomInset,
  });

  final TextEditingController controller;
  final FocusNode focus;
  final bool canSend;
  final VoidCallback onSend;
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    // Send counts as part of the field: tapping it keeps the keyboard up.
    return TextFieldTapRegion(
      child: Container(
        color: DealGoColors.card,
        padding: EdgeInsets.fromLTRB(
          DealGoSpacing.s12,
          DealGoSpacing.s8,
          DealGoSpacing.s12,
          DealGoSpacing.s8 + bottomInset,
        ),
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.only(left: DealGoSpacing.s16, right: 4),
          decoration: BoxDecoration(
            color: DealGoColors.canvas,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: DealGoColors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: TextField(
                    key: const Key('chat-input'),
                    controller: controller,
                    focusNode: focus,
                    minLines: 1,
                    maxLines: 4,
                    maxLength: 2000,
                    textCapitalization: TextCapitalization.sentences,
                    keyboardType: TextInputType.multiline,
                    style: textTheme.bodyMedium,
                    decoration: InputDecoration(
                      hintText: l10n.chatInputHint,
                      hintStyle: textTheme.bodyMedium?.copyWith(
                        color: DealGoColors.textTertiary,
                      ),
                      counterText: '',
                      isDense: true,
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Material(
                  color: canSend ? DealGoColors.primary : DealGoColors.border,
                  shape: const CircleBorder(),
                  child: InkWell(
                    key: const Key('chat-send'),
                    customBorder: const CircleBorder(),
                    onTap: canSend ? onSend : null,
                    child: Tooltip(
                      message: l10n.chatSendAction,
                      child: const SizedBox(
                        width: 36,
                        height: 36,
                        child: Icon(
                          DealGoIcons.send,
                          size: 18,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
