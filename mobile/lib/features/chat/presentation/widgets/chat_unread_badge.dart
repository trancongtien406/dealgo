import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../core/realtime/snapshot_realtime.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../identity/domain/entities/auth_state.dart';
import '../../../identity/presentation/cubit/auth_cubit.dart';
import '../model/chat_unread.dart';

/// Red count on a chat button, fed by the `chatMessage` push (no request).
class ChatUnreadBadge extends StatefulWidget {
  const ChatUnreadBadge({
    required this.aggregateType,
    required this.aggregateId,
    required this.child,
    super.key,
  });

  /// `Ride` | `FoodOrder`.
  final String aggregateType;
  final String aggregateId;
  final Widget child;

  @override
  State<ChatUnreadBadge> createState() => _ChatUnreadBadgeState();
}

class _ChatUnreadBadgeState extends State<ChatUnreadBadge> {
  @override
  void initState() {
    super.initState();
    SnapshotRealtime? realtime;
    String? userId;
    try {
      realtime = context.read<SnapshotRealtime>();
    } on Object {
      realtime = null;
    }
    try {
      final auth = context.read<AuthCubit>().state;
      userId = auth is AuthSignedIn ? auth.profile.id : null;
    } on Object {
      userId = null;
    }
    if (realtime != null) {
      ChatUnread.instance.attach(realtime, currentUserId: userId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final key = ChatUnread.keyFor(widget.aggregateType, widget.aggregateId);
    return ListenableBuilder(
      listenable: ChatUnread.instance,
      builder: (context, child) {
        final count = ChatUnread.instance.count(key);
        return Semantics(
          label: count > 0
              ? AppLocalizations.of(context).chatUnreadCount(count)
              : null,
          child: Badge(
            key: Key('chat-unread-$key'),
            isLabelVisible: count > 0,
            backgroundColor: DealGoColors.danger,
            label: Text(count > 9 ? '9+' : '$count'),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
