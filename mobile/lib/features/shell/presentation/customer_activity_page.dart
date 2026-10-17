import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design_system/components/dealgo_banner.dart';
import '../../../core/design_system/components/dealgo_card.dart';
import '../../../core/design_system/components/dealgo_segmented_control.dart';
import '../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../core/network/connectivity_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../activity/domain/entities/history_models.dart';
import '../../activity/domain/usecases/list_food_history.dart';
import '../../activity/domain/usecases/list_ride_history.dart';
import '../../activity/presentation/cubit/activity_history_cubit.dart';
import '../../identity/domain/entities/auth_state.dart';
import '../../identity/presentation/cubit/auth_cubit.dart';
import '../../identity/presentation/widgets/auth_widgets.dart';
import '../../ride/domain/entities/ride_money.dart';
import 'account_widgets.dart';

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
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Material(
              color: DealGoColors.card,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  DealGoSpacing.s8,
                  DealGoSpacing.s8,
                  DealGoDimensions.pageGutter,
                  DealGoSpacing.s8,
                ),
                child: Row(
                  children: [
                    AuthBackButton(
                      onPressed: () {
                        if (context.canPop()) {
                          context.pop();
                        } else {
                          context.go('/customer');
                        }
                      },
                    ),
                    const SizedBox(width: DealGoSpacing.s8),
                    Expanded(
                      child: Text(
                        'Hoạt động của tôi',
                        style: textTheme.titleMedium,
                      ),
                    ),
                    const DealGoWordmark(),
                  ],
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
                return const Padding(
                  padding: EdgeInsets.fromLTRB(
                    DealGoDimensions.pageGutter,
                    DealGoSpacing.s8,
                    DealGoDimensions.pageGutter,
                    0,
                  ),
                  child: DealGoBanner(
                    tone: DealGoBannerTone.offline,
                    title: 'Bạn đang offline',
                    message: 'Lịch sử hoạt động có thể chưa cập nhật.',
                  ),
                );
              },
            ),
            Expanded(
              child: BlocBuilder<ActivityHistoryCubit, ActivityHistoryState>(
                builder: (context, state) {
                  final history = _visibleHistory(state);
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(
                      DealGoDimensions.pageGutter,
                      DealGoSpacing.s16,
                      DealGoDimensions.pageGutter,
                      DealGoSpacing.s24,
                    ),
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Hoạt động của bạn',
                                  style: textTheme.titleMedium,
                                ),
                                Text(
                                  'Theo dõi đơn hàng và chuyến đi',
                                  style: textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            key: const Key('activity-refresh'),
                            tooltip: 'Tải lại',
                            onPressed: state.busy
                                ? null
                                : () {
                                    final auth = context
                                        .read<AuthCubit>()
                                        .state;
                                    final token = auth is AuthSignedIn
                                        ? auth.tokens.accessToken
                                        : null;
                                    context.read<ActivityHistoryCubit>().load(
                                      accessToken: token,
                                    );
                                  },
                            icon: state.busy
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.refresh),
                          ),
                        ],
                      ),
                      const SizedBox(height: DealGoSpacing.s12),
                      Builder(
                        builder: (context) {
                          final l10n = AppLocalizations.of(context);
                          return DealGoSegmentedControl(
                            value: _filter.name,
                            onChanged: (id) => setState(
                              () => _filter = _ActivityFilter.values
                                  .firstWhere((e) => e.name == id),
                            ),
                            items: [
                              DealGoSegmentItem(
                                id: 'all',
                                label: l10n.filterAll,
                              ),
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
                          );
                        },
                      ),
                      if (state is ActivityHistoryFailure) ...[
                        const SizedBox(height: DealGoSpacing.s12),
                        DealGoCard(child: Text(state.message)),
                      ],
                      const SizedBox(height: DealGoSpacing.s20),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Lịch sử gần đây',
                              style: textTheme.titleMedium,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: DealGoSpacing.s12),
                      if (history.isEmpty)
                        const DealGoCard(
                          child: Text('Chưa có hoạt động trong nhóm này.'),
                        )
                      else
                        for (final item in history) ...[
                          _HistoryCard(item: item),
                          const SizedBox(height: DealGoSpacing.s12),
                        ],
                    ],
                  );
                },
              ),
            ),
          ],
        ),
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
            icon: isRide ? Icons.two_wheeler : Icons.ramen_dining,
            background: isRide
                ? DealGoColors.dangerSurface
                : const Color(0xFFFFF4EA),
            foreground: isRide ? DealGoColors.danger : const Color(0xFFEA580C),
          ),
          const SizedBox(width: DealGoSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: textTheme.titleMedium?.copyWith(fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(item.meta, style: textTheme.bodySmall),
                const SizedBox(height: DealGoSpacing.s4),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: DealGoColors.greenSurface,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DealGoSpacing.s8,
                      vertical: 2,
                    ),
                    child: Text(
                      item.status.isEmpty ? '—' : item.status,
                      style: textTheme.labelSmall?.copyWith(
                        color: DealGoColors.brandGreen,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Text(
            amount == null ? '—' : formatRideVnd(amount),
            style: textTheme.titleMedium?.copyWith(
              color: DealGoColors.primary,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}
