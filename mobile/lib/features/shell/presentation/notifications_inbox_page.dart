import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design_system/components/dealgo_card.dart';
import '../../../core/design_system/components/dealgo_haptics.dart';
import '../../../core/design_system/components/dealgo_pressable.dart';
import '../../../core/design_system/components/dealgo_refresh.dart';
import '../../../core/design_system/components/dealgo_segmented_control.dart';
import '../../../core/design_system/components/dealgo_skeleton.dart';
import '../../../core/design_system/components/dealgo_state_view.dart';
import '../../../core/design_system/icons/dealgo_icons.dart';
import '../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../core/network/request_failure.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/notifications/push_route_resolver.dart';
import '../../identity/domain/entities/auth_state.dart';
import '../../identity/presentation/cubit/auth_cubit.dart';
import '../../inbox/domain/entities/inbox_notification.dart';
import '../../inbox/domain/usecases/inbox_usecases.dart';
import 'account_widgets.dart';
import 'inbox_copy.dart';
import '../../../core/design_system/components/dealgo_app_header.dart';

enum _InboxFilter { all, orders, rides, promos }

sealed class _InboxState {
  const _InboxState();
}

class _Loading extends _InboxState {
  const _Loading();
}

class _Loaded extends _InboxState {
  const _Loaded(this.items, this.unreadCount);

  final List<InboxNotification> items;
  final int unreadCount;
}

class _Failed extends _InboxState {
  const _Failed({required this.cause});

  final Object cause;
}

class NotificationsInboxPage extends StatefulWidget {
  const NotificationsInboxPage({
    this.shellPath = '/customer/account',
    this.title,
    this.asTab = false,
    super.key,
  });

  /// Account shell the support-ticket links open in.
  final String shellPath;

  /// Defaults to the account "Thông báo" title.
  final String? title;

  /// Shown as a bottom-nav tab (driver), so there is no back button.
  final bool asTab;

  @override
  State<NotificationsInboxPage> createState() => _NotificationsInboxPageState();
}

class _NotificationsInboxPageState extends State<NotificationsInboxPage> {
  var _filter = _InboxFilter.all;
  _InboxState _state = const _Loading();

  String? get _token {
    final auth = context.read<AuthCubit>().state;
    return auth is AuthSignedIn ? auth.tokens.accessToken : null;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final token = _token;
    if (token == null) {
      setState(() => _state = const _Failed(cause: sessionExpiredFailure));
      return;
    }
    try {
      final page = await context.read<ListInboxNotifications>()(
        accessToken: token,
      );
      if (!mounted) {
        return;
      }
      setState(() => _state = _Loaded(page.items, page.unreadCount));
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _state = _Failed(cause: error));
    }
  }

  Future<void> _open(InboxNotification item) async {
    final state = _state;
    final token = _token;
    if (!item.read && state is _Loaded && token != null) {
      setState(() {
        _state = _Loaded([
          for (final entry in state.items)
            entry.id == item.id ? entry.markedRead() : entry,
        ], state.unreadCount > 0 ? state.unreadCount - 1 : 0);
      });
      // Best effort: the next refresh re-syncs from the server.
      context
          .read<MarkInboxNotificationRead>()(accessToken: token, id: item.id)
          .ignore();
    }
    // Same targets as a push tap, for this shell's role.
    final target = inboxTargetFor(
      shellPath: widget.shellPath,
      aggregateType: item.aggregateType,
      aggregateId: item.aggregateId,
      status: item.status,
      path: item.path,
    );
    if (target != null) {
      await context.push(target);
    }
  }

  Future<void> _markAllRead() async {
    final state = _state;
    final token = _token;
    if (state is! _Loaded || token == null) {
      return;
    }
    DealGoHaptics.selection();
    setState(() {
      _state = _Loaded([for (final item in state.items) item.markedRead()], 0);
    });
    try {
      await context.read<MarkAllInboxNotificationsRead>()(accessToken: token);
    } catch (_) {
      if (mounted) {
        await _load();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = _state;
    final unread = state is _Loaded ? state.unreadCount : 0;
    return ColoredBox(
      color: DealGoColors.canvas,
      child: SafeArea(
        bottom: dealGoSafeAreaBottom(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DealGoAppHeader(
              title: widget.title ?? l10n.accountNotifications,
              showBack: !widget.asTab,
              actions: unread > 0
                  ? TextButton(
                      key: const Key('inbox-mark-all'),
                      onPressed: _markAllRead,
                      style: TextButton.styleFrom(
                        foregroundColor: DealGoColors.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        visualDensity: VisualDensity.compact,
                      ),
                      child: Text(l10n.inboxMarkAllRead),
                    )
                  : null,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                DealGoDimensions.pageGutter,
                DealGoSpacing.s16,
                DealGoDimensions.pageGutter,
                0,
              ),
              child: _FilterRow(
                selected: _filter,
                onSelected: (filter) => setState(() => _filter = filter),
              ),
            ),
            Expanded(child: _body(context, state)),
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context, _InboxState state) {
    final l10n = AppLocalizations.of(context);
    const padding = EdgeInsets.fromLTRB(
      DealGoDimensions.pageGutter,
      DealGoSpacing.s16,
      DealGoDimensions.pageGutter,
      DealGoSpacing.s24,
    );
    switch (state) {
      case _Loading():
        return DealGoSkeletonList(
          padding: padding,
          thumbSize: 44,
          semanticLabel: l10n.inboxLoading,
        );
      case _Failed(:final cause):
        return ListView(
          padding: padding,
          children: [
            DealGoStateView.failure(
              context,
              onRetry: _retry,
              cause: cause,
              compact: true,
            ),
          ],
        );
      case _Loaded(:final items):
        final visible = [
          for (final item in items)
            if (_matches(item)) item,
        ];
        final now = DateTime.now();
        final groups = <_Section, List<InboxNotification>>{};
        for (final item in visible) {
          groups
              .putIfAbsent(_sectionFor(item.createdAt, now), () => [])
              .add(item);
        }
        return DealGoRefresh(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: padding,
            children: [
              if (visible.isEmpty)
                DealGoStateView(
                  art: DealGoStateArt.noNotifications,
                  title: l10n.notificationsEmptyTitle,
                  message: l10n.notificationsEmptyBody,
                  compact: true,
                )
              else
                for (final section in _Section.values)
                  if (groups[section] case final entries?) ...[
                    AccountSectionHeader(title: section.label(l10n)),
                    const SizedBox(height: DealGoSpacing.s12),
                    for (final item in entries) ...[
                      _NoticeCard(
                        item: item,
                        now: now,
                        onTap: () => _open(item),
                      ),
                      const SizedBox(height: DealGoSpacing.s12),
                    ],
                  ],
            ],
          ),
        );
    }
  }

  void _retry() {
    setState(() => _state = const _Loading());
    _load();
  }

  bool _matches(InboxNotification item) {
    return switch (_filter) {
      _InboxFilter.all => true,
      _InboxFilter.orders => item.category == InboxCategory.food,
      _InboxFilter.rides => item.category == InboxCategory.ride,
      _InboxFilter.promos =>
        item.category == InboxCategory.promotion ||
            item.category == InboxCategory.system,
    };
  }
}

enum _Section {
  today,
  yesterday,
  earlier;

  String label(AppLocalizations l10n) => switch (this) {
    _Section.today => l10n.inboxSectionToday,
    _Section.yesterday => l10n.inboxSectionYesterday,
    _Section.earlier => l10n.inboxSectionEarlier,
  };
}

_Section _sectionFor(DateTime at, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(at.year, at.month, at.day);
  final diff = today.difference(day).inDays;
  if (diff <= 0) {
    return _Section.today;
  }
  return diff == 1 ? _Section.yesterday : _Section.earlier;
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({required this.selected, required this.onSelected});

  final _InboxFilter selected;
  final ValueChanged<_InboxFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DealGoSegmentedControl(
      value: selected.name,
      scrollable: false,
      onChanged: (id) =>
          onSelected(_InboxFilter.values.firstWhere((e) => e.name == id)),
      items: [
        DealGoSegmentItem(id: 'all', label: l10n.filterAll),
        DealGoSegmentItem(id: 'orders', label: l10n.filterOrders),
        DealGoSegmentItem(id: 'rides', label: l10n.filterRides),
        DealGoSegmentItem(id: 'promos', label: l10n.inboxFilterPromos),
      ],
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({
    required this.item,
    required this.now,
    required this.onTap,
  });

  final InboxNotification item;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final copy = inboxCopy(l10n, item);
    final tone = _toneFor(item.category);
    return DealGoPressable(
      onTap: onTap,
      child: DealGoCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AccountToneIcon(
              icon: tone.icon,
              background: tone.background,
              foreground: tone.foreground,
            ),
            const SizedBox(width: DealGoSpacing.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    copy.title,
                    style: textTheme.titleMedium?.copyWith(
                      fontSize: 16,
                      fontWeight: item.read ? FontWeight.w600 : FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(copy.body, style: textTheme.bodySmall),
                ],
              ),
            ),
            const SizedBox(width: DealGoSpacing.s8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  inboxWhen(l10n, item.createdAt, now),
                  style: textTheme.bodySmall,
                ),
                const SizedBox(height: DealGoSpacing.s8),
                if (!item.read)
                  Semantics(
                    label: l10n.inboxUnread,
                    child: Container(
                      key: const Key('inbox-unread-dot'),
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: DealGoColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

typedef _Tone = ({IconData icon, Color background, Color foreground});

_Tone _toneFor(InboxCategory category) => switch (category) {
  InboxCategory.ride => (
    icon: DealGoIcons.car,
    background: DealGoColors.greenSurface,
    foreground: DealGoColors.brandGreen,
  ),
  InboxCategory.food => (
    icon: DealGoIcons.package,
    background: DealGoColors.amberSurface,
    foreground: DealGoColors.amber,
  ),
  InboxCategory.promotion => (
    icon: DealGoIcons.gift,
    background: DealGoColors.dangerSurface,
    foreground: DealGoColors.danger,
  ),
  InboxCategory.system => (
    icon: DealGoIcons.notifications,
    background: DealGoColors.subtlePurple,
    foreground: DealGoColors.primary,
  ),
};
