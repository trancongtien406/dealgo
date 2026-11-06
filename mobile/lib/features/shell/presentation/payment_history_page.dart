import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/design_system/components/dealgo_refresh.dart';
import '../../../core/design_system/components/dealgo_segmented_control.dart';
import '../../../core/design_system/components/dealgo_skeleton.dart';
import '../../../core/design_system/components/dealgo_state_view.dart';
import '../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../core/format/date_time_format.dart';
import '../../../l10n/app_localizations.dart';
import '../../activity/domain/entities/history_models.dart';
import '../../activity/domain/usecases/list_food_history.dart';
import '../../activity/domain/usecases/list_ride_history.dart';
import '../../activity/presentation/cubit/activity_history_cubit.dart';
import '../../identity/domain/entities/auth_state.dart';
import '../../identity/presentation/cubit/auth_cubit.dart';
import '../../ride/domain/entities/ride_money.dart';
import '../../../core/design_system/icons/dealgo_icons.dart';
import 'customer_activity_page.dart';
import '../../../core/design_system/components/dealgo_app_header.dart';

/// Statuses where the customer actually paid (cash on completion).
const _paidStatuses = {'COMPLETED', 'DELIVERED'};

enum _PaymentFilter { all, rides, food }

/// C046 — payment history built from the customer's real finished rides and
/// delivered food orders (both cash on delivery today). No sample rows.
class PaymentHistoryPage extends StatelessWidget {
  const PaymentHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthCubit>().state;
    final token = auth is AuthSignedIn ? auth.tokens.accessToken : null;
    return BlocProvider(
      create: (context) => ActivityHistoryCubit(
        listRideHistory: context.read<ListRideHistory>(),
        listFoodHistory: context.read<ListFoodHistory>(),
      )..load(accessToken: token),
      child: const _PaymentHistoryView(),
    );
  }
}

class _PaymentHistoryView extends StatefulWidget {
  const _PaymentHistoryView();

  @override
  State<_PaymentHistoryView> createState() => _PaymentHistoryViewState();
}

class _PaymentHistoryViewState extends State<_PaymentHistoryView> {
  var _filter = _PaymentFilter.all;

  Future<void> _reload(BuildContext context) {
    final auth = context.read<AuthCubit>().state;
    final token = auth is AuthSignedIn ? auth.tokens.accessToken : null;
    return context.read<ActivityHistoryCubit>().load(accessToken: token);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final state = context.watch<ActivityHistoryCubit>().state;
    final paid =
        [...state.rides, ...state.food]
            .where(
              (item) =>
                  _paidStatuses.contains(item.status) && item.amountVnd != null,
            )
            .toList()
          ..sort((a, b) => b.meta.compareTo(a.meta));
    final total = paid.fold<int>(0, (sum, item) => sum + item.amountVnd!);
    final visible = paid.where((item) {
      return switch (_filter) {
        _PaymentFilter.all => true,
        _PaymentFilter.rides => item.kind == HistoryKind.ride,
        _PaymentFilter.food => item.kind == HistoryKind.food,
      };
    }).toList();
    return Scaffold(
      backgroundColor: DealGoColors.canvas,
      body: SafeArea(
        child: Column(
          children: [
            DealGoAppHeader(title: l10n.paymentHistoryTitle),
            Expanded(
              child: DealGoRefresh(
                onRefresh: () => _reload(context),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    DealGoDimensions.pageGutter,
                    DealGoSpacing.s8,
                    DealGoDimensions.pageGutter,
                    DealGoSpacing.s24,
                  ),
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: DealGoColors.primary,
                        borderRadius: BorderRadius.circular(DealGoRadius.card),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(DealGoSpacing.s20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.paymentHistoryTotal,
                              style: textTheme.bodySmall?.copyWith(
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                            ),
                            const SizedBox(height: DealGoSpacing.s8),
                            Text(
                              formatRideVnd(total),
                              key: const Key('payment-history-total'),
                              style: textTheme.headlineMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: DealGoSpacing.s4),
                            Text(
                              l10n.paymentHistoryCount(paid.length),
                              style: textTheme.bodySmall?.copyWith(
                                color: Colors.white.withValues(alpha: 0.85),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: DealGoSpacing.s16),
                    DealGoSegmentedControl(
                      value: _filter.name,
                      scrollable: false,
                      onChanged: (id) => setState(
                        () => _filter = _PaymentFilter.values.firstWhere(
                          (e) => e.name == id,
                        ),
                      ),
                      items: [
                        DealGoSegmentItem(
                          id: 'all',
                          label: l10n.paymentHistoryFilterAll,
                        ),
                        DealGoSegmentItem(
                          id: 'rides',
                          label: l10n.paymentHistoryFilterRides,
                        ),
                        DealGoSegmentItem(
                          id: 'food',
                          label: l10n.paymentHistoryFilterFood,
                        ),
                      ],
                    ),
                    const SizedBox(height: DealGoSpacing.s20),
                    Text(
                      l10n.paymentHistoryRecent,
                      style: textTheme.titleMedium,
                    ),
                    const SizedBox(height: DealGoSpacing.s8),
                    if (state is ActivityHistoryLoading && paid.isEmpty)
                      const DealGoSkeletonList(itemCount: 3)
                    else if (state is ActivityHistoryFailure && paid.isEmpty)
                      DealGoStateView.failure(
                        context,
                        onRetry: () => _reload(context),
                        cause: state.message.error,
                        message: state.message.resolve(l10n),
                        compact: true,
                      )
                    else if (visible.isEmpty)
                      DealGoStateView(
                        key: const Key('payment-history-empty'),
                        art: DealGoStateArt.noOrders,
                        title: l10n.paymentHistoryEmpty,
                        compact: true,
                      )
                    else
                      for (final item in visible)
                        _TxRow(
                          icon: item.kind == HistoryKind.ride
                              ? DealGoIcons.car
                              : DealGoIcons.food,
                          color: item.kind == HistoryKind.ride
                              ? const Color(0xFFFEF3C7)
                              : const Color(0xFFFFEDD5),
                          iconColor: item.kind == HistoryKind.ride
                              ? const Color(0xFFD97706)
                              : const Color(0xFFEA580C),
                          title: historyTitle(
                            AppLocalizations.of(context),
                            item,
                          ),
                          subtitle: [
                            formatLocalDateTime(item.meta),
                            l10n.paymentHistoryCash,
                          ].whereType<String>().join(' · '),
                          amount: '-${formatRideVnd(item.amountVnd!)}',
                          amountColor: DealGoColors.text,
                        ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TxRow extends StatelessWidget {
  const _TxRow({
    required this.icon,
    required this.color,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.amountColor,
  });

  final IconData icon;
  final Color color;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String amount;
  final Color amountColor;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DealGoSpacing.s8),
      child: Row(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(DealGoRadius.input),
            ),
            child: SizedBox(
              width: 40,
              height: 40,
              child: Icon(icon, color: iconColor, size: 20),
            ),
          ),
          const SizedBox(width: DealGoSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: textTheme.titleSmall),
                Text(subtitle, style: textTheme.bodySmall),
              ],
            ),
          ),
          Text(
            amount,
            style: textTheme.titleSmall?.copyWith(
              color: amountColor,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
