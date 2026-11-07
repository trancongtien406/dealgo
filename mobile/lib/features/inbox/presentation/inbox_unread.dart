import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../core/realtime/snapshot_realtime.dart';
import '../../../l10n/app_localizations.dart';
import '../../identity/domain/entities/auth_state.dart';
import '../../identity/presentation/cubit/auth_cubit.dart';
import '../domain/usecases/inbox_usecases.dart';

/// Unread inbox count for the signed-in user. `GET /v1/me/notifications`
/// (`unreadCount`) is the snapshot on attach, reconnect and inbox load; the
/// realtime `inbox` push bumps it in between; reading clears it.
class InboxUnread extends ChangeNotifier {
  InboxUnread._();

  static final InboxUnread instance = InboxUnread._();

  int _count = 0;
  String? _userId;
  Future<int?> Function()? _fetch;
  SnapshotRealtime? _realtime;
  StreamSubscription<void>? _inboxSub;
  StreamSubscription<void>? _reconnectSub;
  DateTime? _fetchedAt;
  Future<void>? _refreshFlight;

  int get count => _count;

  /// Idempotent per user: a new user resets the count; a fresh attach
  /// refreshes at most every [_minRefresh].
  void attach({
    required String userId,
    required Future<int?> Function() fetch,
    SnapshotRealtime? realtime,
  }) {
    _fetch = fetch;
    if (userId != _userId) {
      _userId = userId;
      _fetchedAt = null;
      _set(0);
    }
    if (realtime != null && !identical(realtime, _realtime)) {
      unawaited(_inboxSub?.cancel());
      unawaited(_reconnectSub?.cancel());
      _realtime = realtime;
      _inboxSub = realtime.inboxEvents.listen((_) => _set(_count + 1));
      _reconnectSub = realtime.reconnects.listen((_) => unawaited(refresh()));
    }
    final last = _fetchedAt;
    if (last == null || DateTime.now().difference(last) > _minRefresh) {
      unawaited(refresh());
    }
  }

  static const _minRefresh = Duration(seconds: 30);

  Future<void> refresh() {
    return _refreshFlight ??=
        _performRefresh().whenComplete(() => _refreshFlight = null);
  }

  Future<void> _performRefresh() async {
    final fetch = _fetch;
    if (fetch == null) {
      return;
    }
    _fetchedAt = DateTime.now();
    try {
      final value = await fetch();
      if (value != null) {
        _set(value);
      }
    } on Object {
      // Keep the last known count; the next attach or reconnect retries.
    }
  }

  /// Server count after the inbox page loads or a read is applied.
  void set(int value) => _set(value);

  void _set(int value) {
    final next = value < 0 ? 0 : value;
    if (next == _count) {
      return;
    }
    _count = next;
    _notifyOutsideBuild();
  }

  void _notifyOutsideBuild() {
    SchedulerBinding? binding;
    try {
      binding = SchedulerBinding.instance;
    } on Object {
      binding = null;
    }
    if (binding != null &&
        binding.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      binding.addPostFrameCallback((_) => notifyListeners());
      binding.ensureVisualUpdate();
      return;
    }
    notifyListeners();
  }

  @visibleForTesting
  void resetForTest() {
    unawaited(_inboxSub?.cancel());
    unawaited(_reconnectSub?.cancel());
    _inboxSub = null;
    _reconnectSub = null;
    _realtime = null;
    _fetch = null;
    _userId = null;
    _fetchedAt = null;
    _refreshFlight = null;
    _count = 0;
  }
}

/// Attaches [InboxUnread] to the signed-in session found in [context]. No-op
/// when signed out or the inbox use case is not provided.
void attachInboxUnread(BuildContext context) {
  final AuthCubit auth;
  final ListInboxNotifications list;
  try {
    auth = context.read<AuthCubit>();
    list = context.read<ListInboxNotifications>();
  } on Object {
    return;
  }
  final state = auth.state;
  if (state is! AuthSignedIn) {
    return;
  }
  SnapshotRealtime? realtime;
  try {
    realtime = context.read<SnapshotRealtime>();
  } on Object {
    realtime = null;
  }
  InboxUnread.instance.attach(
    userId: state.profile.id,
    realtime: realtime,
    fetch: () async {
      final current = auth.state;
      if (current is! AuthSignedIn) {
        return null;
      }
      final page = await list(
        accessToken: current.tokens.accessToken,
        limit: 1,
      );
      return page.unreadCount;
    },
  );
}

/// Red count over [child] while the inbox has unread items; nothing otherwise.
class InboxUnreadBadge extends StatefulWidget {
  const InboxUnreadBadge({required this.child, super.key});

  final Widget child;

  @override
  State<InboxUnreadBadge> createState() => _InboxUnreadBadgeState();
}

class _InboxUnreadBadgeState extends State<InboxUnreadBadge> {
  @override
  void initState() {
    super.initState();
    attachInboxUnread(context);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: InboxUnread.instance,
      builder: (context, child) {
        final count = InboxUnread.instance.count;
        return Semantics(
          label: count > 0
              ? AppLocalizations.of(context).inboxUnreadCount(count)
              : null,
          child: Badge(
            key: const Key('inbox-unread-badge'),
            isLabelVisible: count > 0,
            backgroundColor: DealGoColors.danger,
            label: Text(count > 99 ? '99+' : '$count'),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
