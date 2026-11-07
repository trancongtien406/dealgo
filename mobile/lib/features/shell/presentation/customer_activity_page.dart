import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design_system/components/dealgo_app_header.dart';
import '../../../core/design_system/components/dealgo_card.dart';
import '../../../core/design_system/components/dealgo_chip.dart';
import '../../../core/design_system/components/dealgo_nav_insets.dart';
import '../../../core/design_system/components/dealgo_refresh.dart';
import '../../../core/design_system/components/dealgo_segmented_control.dart';
import '../../../core/design_system/components/dealgo_skeleton.dart';
import '../../../core/design_system/components/dealgo_state_view.dart';
import '../../../core/design_system/icons/dealgo_icons.dart';
import '../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../core/format/date_time_format.dart';
import '../../../core/format/short_ref.dart';
import '../../../core/realtime/realtime_refresh_watcher.dart';
import '../../../core/realtime/snapshot_realtime.dart';
import '../../../l10n/app_localizations.dart';
import '../../activity/domain/entities/history_models.dart';
import '../../activity/domain/usecases/list_food_history.dart';
import '../../activity/domain/usecases/list_ride_history.dart';
import '../../activity/presentation/cubit/activity_history_cubit.dart';
import '../../identity/domain/entities/auth_state.dart';
import '../../identity/presentation/cubit/auth_cubit.dart';
import '../../places/domain/place.dart';
import '../../ride/domain/entities/ride_money.dart';
import 'account_widgets.dart';

enum _ActivityFilter { all, rides, food }

class CustomerActivityPage extends StatelessWidget {
  const CustomerActivityPage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthCubit>().state;
    final token = auth is AuthSignedIn ? auth.tokens.accessToken : null;
    return BlocProvider(
      create: (context) => ActivityHistoryCubit(
        listRideHistory: context.read<ListRideHistory>(),
        listFoodHistory: context.read<ListFoodHistory>(),
      )..load(accessToken: token),
      child: const _CustomerActivityView(),
    );
  }
}

class _CustomerActivityView extends StatefulWidget {
  const _CustomerActivityView();

  @override
  State<_CustomerActivityView> createState() => _CustomerActivityViewState();
}

class _CustomerActivityViewState extends State<_CustomerActivityView> {
  var _filter = _ActivityFilter.all;
  StreamSubscription<ActivityHistoryState>? _stateSub;
  RealtimeRefreshWatcher? _watcher;
  var _watchedKeys = <String>{};

  @override
  void initState() {
    super.initState();
    final cubit = context.read<ActivityHistoryCubit>();
    _stateSub = cubit.stream.listen(_syncWatcher);
    _syncWatcher(cubit.state);
  }

  @override
  void dispose() {
    unawaited(_stateSub?.cancel());
    final watcher = _watcher;
    if (watcher != null) {
      unawaited(watcher.stop());
    }
    super.dispose();
  }

  /// Joins the snapshot room of every unfinished ride/order in the list so a
  /// status change (e.g. trip completed) refreshes the row without pull-to-refresh.
  void _syncWatcher(ActivityHistoryState state) {
    if (state is! ActivityHistoryReady) {
      return;
    }
    final rooms = activeHistoryRooms([...state.rides, ...state.food]);
    final keys = {for (final room in rooms) room.name};
    if (keys.length == _watchedKeys.length && keys.containsAll(_watchedKeys)) {
      return;
    }
    _watchedKeys = keys;
    final previous = _watcher;
    _watcher = null;
    if (previous != null) {
      unawaited(previous.stop());
    }
    if (rooms.isEmpty) {
      return;
    }
    SnapshotRealtime? realtime;
    try {
      realtime = context.read<SnapshotRealtime>();
    } catch (_) {
      return;
    }
    final auth = context.read<AuthCubit>().state;
    final token = auth is AuthSignedIn ? auth.tokens.accessToken : null;
    if (token == null || token.isEmpty) {
      return;
    }
    final ids = {for (final room in rooms) activeRoomId(room)};
    final watcher = RealtimeRefreshWatcher(
      realtime: realtime,
      rooms: rooms,
      refresh: () => _reload(context),
      matchesSnapshot: (hint) => ids.contains(hint.aggregateId),
    );
    _watcher = watcher;
    unawaited(watcher.start(accessToken: token, initialRefresh: false));
  }

  Future<void> _reload(BuildContext context) {
    final auth = context.read<AuthCubit>().state;
    final token = auth is AuthSignedIn ? auth.tokens.accessToken : null;
    return context.read<ActivityHistoryCubit>().load(accessToken: token);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return ColoredBox(
      color: DealGoColors.canvas,
      child: SafeArea(
        bottom: false,
        child: BlocConsumer<ActivityHistoryCubit, ActivityHistoryState>(
          listener: (context, state) {
            if (state is ActivityHistoryFailure &&
                (state.rides.isNotEmpty || state.food.isNotEmpty)) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(state.message.resolve(l10n))),
              );
            }
          },
          builder: (context, state) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DealGoAppHeader(
                  title: l10n.accountActivity,
                  showBack: false,
                  actions: IconButton(
                    key: const Key('activity-refresh'),
                    tooltip: l10n.actionRefresh,
                    onPressed: state.busy ? null : () => _reload(context),
                    icon: Icon(
                      DealGoIcons.refresh,
                      color: DealGoColors.text,
                    ),
                  ),
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
            );
          },
        ),
      ),
    );
  }

  Widget _body(BuildContext context, ActivityHistoryState state) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final history = _visibleHistory(state);
    final initialLoad =
        state.busy && state.rides.isEmpty && state.food.isEmpty;
    final padding = dealGoScrollPadding(
      context,
      const EdgeInsets.fromLTRB(
        DealGoDimensions.pageGutter,
        DealGoSpacing.s16,
        DealGoDimensions.pageGutter,
        DealGoSpacing.s24,
      ),
    );

    if (initialLoad) {
      return DealGoSkeletonList(
        itemCount: 4,
        padding: padding,
        thumbSize: 44,
        semanticLabel: l10n.inboxLoading,
      );
    }

    if (state is ActivityHistoryFailure && history.isEmpty) {
      return DealGoRefresh(
        onRefresh: () => _reload(context),
        child: DealGoStateView.failure(
          context,
          onRetry: () => _reload(context),
          cause: state.message.error,
          message: state.message.resolve(l10n),
        ),
      );
    }

    if (history.isEmpty) {
      return DealGoRefresh(
        onRefresh: () => _reload(context),
        child: DealGoStateView(
          art: DealGoStateArt.noOrders,
          title: l10n.activityEmptyTitle,
          message: l10n.activityEmptyBody,
        ),
      );
    }

    return DealGoRefresh(
      onRefresh: () => _reload(context),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: padding,
        children: [
          Text(
            l10n.activityRecent,
            style: textTheme.titleMedium,
          ),
          const SizedBox(height: DealGoSpacing.s12),
          for (final item in history) ...[
            _HistoryCard(item: item),
            const SizedBox(height: DealGoSpacing.s12),
          ],
        ],
      ),
    );
  }

  List<HistoryItem> _visibleHistory(ActivityHistoryState state) {
    final combined = <HistoryItem>[
      if (_filter == _ActivityFilter.all || _filter == _ActivityFilter.rides)
        ...state.rides,
      if (_filter == _ActivityFilter.all || _filter == _ActivityFilter.food)
        ...state.food,
    ];
    if (_filter == _ActivityFilter.all) {
      combined.sort((a, b) => b.meta.compareTo(a.meta));
    }
    return combined;
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({required this.selected, required this.onSelected});

  final _ActivityFilter selected;
  final ValueChanged<_ActivityFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DealGoSegmentedControl(
      value: selected.name,
      scrollable: false,
      onChanged: (id) =>
          onSelected(_ActivityFilter.values.firstWhere((e) => e.name == id)),
      items: [
        DealGoSegmentItem(
          id: 'all',
          label: l10n.filterAll,
          key: const Key('activity-filter-all'),
        ),
        DealGoSegmentItem(
          id: 'rides',
          label: l10n.filterRides,
          key: const Key('activity-filter-rides'),
        ),
        DealGoSegmentItem(
          id: 'food',
          label: l10n.filterFood,
          key: const Key('activity-filter-food'),
        ),
      ],
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.item});

  final HistoryItem item;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isRide = item.kind == HistoryKind.ride;
    final amount = item.amountVnd;
    return DealGoCard(
      onTap: () async {
        await context.push(historyDetailPath(item));
        if (context.mounted) {
          final auth = context.read<AuthCubit>().state;
          final token = auth is AuthSignedIn ? auth.tokens.accessToken : null;
          await context.read<ActivityHistoryCubit>().load(accessToken: token);
        }
      },
      child: Row(
        children: [
          AccountToneIcon(
            icon: isRide ? DealGoIcons.motorbike : DealGoIcons.food,
            background: isRide
                ? DealGoColors.dangerSurface
                : DealGoColors.amberSurface,
            foreground: isRide ? DealGoColors.danger : DealGoColors.amber,
          ),
          const SizedBox(width: DealGoSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  historyTitle(AppLocalizations.of(context), item),
                  style: textTheme.titleMedium?.copyWith(fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(
                  formatLocalDateTime(item.meta) ?? item.meta,
                  style: textTheme.bodySmall,
                ),
                const SizedBox(height: DealGoSpacing.s4),
                DealGoChip(
                  label: historyStatusLabel(
                    AppLocalizations.of(context),
                    item.status,
                  ),
                  tone: historyStatusIsBad(item.status)
                      ? DealGoChipTone.danger
                      : DealGoChipTone.success,
                ),
              ],
            ),
          ),
          Text(
            amount == null ? '—' : formatRideVnd(amount),
            style: textTheme.titleMedium?.copyWith(
              color: DealGoColors.primary,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// Detail route for a history row: food opens order tracking, rides open ride tracking.
String historyDetailPath(HistoryItem item) => item.kind == HistoryKind.ride
    ? '/customer/ride/tracking/${item.id}'
    : '/customer/food/orders/${item.id}';

bool historyStatusIsBad(String status) =>
    const {'CANCELLED', 'EXPIRED', 'FAILED', 'REJECTED'}.contains(status);

/// Maps backend ride/food status codes to customer-facing copy.
/// The server title (destination or store name), or the short reference when it has none.
String historyTitle(AppLocalizations l10n, HistoryItem item) {
  final title = cleanPlaceText(item.title);
  if (title.isNotEmpty) {
    return title;
  }
  return item.kind == HistoryKind.ride
      ? l10n.rideRef(shortRef(item.id))
      : l10n.orderRef(shortRef(item.id));
}

String historyStatusLabel(AppLocalizations l10n, String status) {
  return switch (status) {
    'COMPLETED' || 'DELIVERED' => l10n.statusCompleted,
    'CANCELLED' => l10n.statusCancelled,
    'EXPIRED' => l10n.statusExpired,
    'FAILED' => l10n.statusFailed,
    'REJECTED' => l10n.statusRejected,
    'NEGOTIATING' || 'PLACED' => l10n.statusPending,
    'ASSIGNED' ||
    'DRIVER_EN_ROUTE' ||
    'DRIVER_ARRIVED' ||
    'IN_TRIP' ||
    'ACCEPTED' ||
    'PREPARING' ||
    'READY' ||
    'PICKED_UP' => l10n.statusInProgress,
    '' => '—',
    _ => l10n.statusInProgress,
  };
}

/// Unfinished rows whose status can still change; each gets its snapshot room.
List<SnapshotRoom> activeHistoryRooms(List<HistoryItem> items) => [
  for (final item in items)
    if (!historyStatusIsFinal(item.status))
      item.kind == HistoryKind.ride
          ? RideSnapshotRoom(item.id)
          : FoodSnapshotRoom(item.id),
];

String activeRoomId(SnapshotRoom room) => switch (room) {
  RideSnapshotRoom(:final rideId) => rideId,
  FoodSnapshotRoom(:final orderId) => orderId,
  _ => room.name,
};

bool historyStatusIsFinal(String status) => const {
  'COMPLETED',
  'DELIVERED',
  'CANCELLED',
  'EXPIRED',
  'FAILED',
  'REJECTED',
  '',
}.contains(status);
