import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/design_system/components/dealgo_banner.dart';
import '../../../core/design_system/components/dealgo_card.dart';
import '../../../core/design_system/components/dealgo_chip.dart';
import '../../../core/design_system/components/dealgo_state_view.dart';
import '../../../core/design_system/components/dealgo_skeleton.dart';
import '../../../core/design_system/components/dealgo_refresh.dart';
import '../../../core/design_system/components/dealgo_segmented_control.dart';
import '../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../core/network/connectivity_service.dart';
import '../../../core/network/request_failure.dart';
import '../../../l10n/app_localizations.dart';
import '../../activity/domain/entities/history_models.dart';
import '../../activity/domain/usecases/list_food_history.dart';
import '../../activity/domain/usecases/list_ride_history.dart';
import '../../activity/presentation/cubit/activity_history_cubit.dart';
import '../../identity/domain/entities/auth_state.dart';
import '../../identity/presentation/cubit/auth_cubit.dart';
import '../../ride/domain/entities/ride_money.dart';
import 'account_widgets.dart';
import 'customer_tab_bar.dart';
import '../../../core/design_system/icons/dealgo_icons.dart';
import '../../../core/format/date_time_format.dart';
import '../../../core/format/short_ref.dart';
import '../../../core/design_system/components/dealgo_app_header.dart';

enum _ActivityFilter { all, rides, food, shopping }

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

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return ColoredBox(
      color: DealGoColors.canvas,
      child: SafeArea(
        bottom: dealGoSafeAreaBottom(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DealGoAppHeader(
              title: AppLocalizations.of(context).accountActivity,
              showBack: false,
              actions: BlocBuilder<ActivityHistoryCubit, ActivityHistoryState>(
                builder: (context, state) => IconButton(
                  key: const Key('activity-refresh'),
                  tooltip: AppLocalizations.of(context).actionRefresh,
                  onPressed: state.busy ? null : () => _reload(context),
                  icon: const Icon(
                    DealGoIcons.refresh,
                    color: DealGoColors.text,
                  ),
                ),
              ),
            ),
            StreamBuilder<bool>(
              stream: context.read<ConnectivityService>().onStatusChanged,
              initialData: context.read<ConnectivityService>().isOnline,
              builder: (context, snapshot) {
                if (snapshot.data ?? true) {
                  return const SizedBox.shrink();
                }
                final l10n = AppLocalizations.of(context);
                return Padding(
                  padding: const EdgeInsets.fromLTRB(
                    DealGoDimensions.pageGutter,
                    DealGoSpacing.s8,
                    DealGoDimensions.pageGutter,
                    0,
                  ),
                  child: DealGoBanner(
                    tone: DealGoBannerTone.offline,
                    title: l10n.bannerOfflineTitle,
                    message: l10n.activityOfflineBody,
                  ),
                );
              },
            ),
            Expanded(
              child: BlocBuilder<ActivityHistoryCubit, ActivityHistoryState>(
                builder: (context, state) {
                  final l10n = AppLocalizations.of(context);
                  final history = _visibleHistory(state);
                  final initialLoad =
                      state.busy && state.rides.isEmpty && state.food.isEmpty;
                  return DealGoRefresh(
                    onRefresh: () => _reload(context),
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                        DealGoDimensions.pageGutter,
                        DealGoSpacing.s12,
                        DealGoDimensions.pageGutter,
                        customerShellBottomClearance(context),
                      ),
                      children: [
                        DealGoSegmentedControl(
                          value: _filter.name,
                          scrollable: false,
                          onChanged: (id) => setState(
                            () => _filter = _ActivityFilter.values.firstWhere(
                              (e) => e.name == id,
                            ),
                          ),
                          items: [
                            DealGoSegmentItem(id: 'all', label: l10n.filterAll),
                            DealGoSegmentItem(
                              id: 'rides',
                              label: l10n.filterRides,
                            ),
                            DealGoSegmentItem(
                              id: 'food',
                              label: l10n.filterFood,
                            ),
                            DealGoSegmentItem(
                              id: 'shopping',
                              label: l10n.filterShopping,
                            ),
                          ],
                        ),
                        const SizedBox(height: DealGoSpacing.s16),
                        if (initialLoad)
                          const DealGoSkeletonList(
                            itemCount: 4,
                            padding: EdgeInsets.zero,
                          )
                        else if (state is ActivityHistoryFailure &&
                            history.isEmpty)
                          DealGoStateView.failure(
                            context,
                            onRetry: () => _reload(context),
                            cause: state.message.error,
                            message: state.message.resolve(l10n),
                            compact: true,
                          )
                        else if (history.isEmpty)
                          DealGoStateView(
                            art: DealGoStateArt.noOrders,
                            title: l10n.activityEmptyTitle,
                            message: l10n.activityEmptyBody,
                            compact: true,
                          )
                        else ...[
                          if (state is ActivityHistoryFailure) ...[
                            DealGoBanner(
                              tone: requestFailureKind(state.message.error) ==
                                      RequestFailureKind.offline
                                  ? DealGoBannerTone.offline
                                  : DealGoBannerTone.warning,
                              message: state.message.resolve(l10n),
                            ),
                            const SizedBox(height: DealGoSpacing.s12),
                          ],
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
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _reload(BuildContext context) {
    final auth = context.read<AuthCubit>().state;
    final token = auth is AuthSignedIn ? auth.tokens.accessToken : null;
    return context.read<ActivityHistoryCubit>().load(accessToken: token);
  }

  List<HistoryItem> _visibleHistory(ActivityHistoryState state) {
    final combined = <HistoryItem>[
      if (_filter == _ActivityFilter.all || _filter == _ActivityFilter.rides)
        ...state.rides,
      if (_filter == _ActivityFilter.all || _filter == _ActivityFilter.food)
        ...state.food,
    ];
    if (_filter == _ActivityFilter.shopping) {
      return const [];
    }
    return combined;
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

bool historyStatusIsBad(String status) =>
    const {'CANCELLED', 'EXPIRED', 'FAILED', 'REJECTED'}.contains(status);

/// Maps backend ride/food status codes to customer-facing copy.
/// The server title (destination or store name), or the short reference when it has none.
String historyTitle(AppLocalizations l10n, HistoryItem item) {
  if (item.title.isNotEmpty) {
    return item.title;
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
