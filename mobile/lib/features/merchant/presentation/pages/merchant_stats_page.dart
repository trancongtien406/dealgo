import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/design_system/components/dealgo_card.dart';
import '../../../../core/design_system/components/dealgo_nav_insets.dart';
import '../../../../core/design_system/components/dealgo_refresh.dart';
import '../../../../core/design_system/components/dealgo_secondary_button.dart';
import '../../../../core/design_system/components/dealgo_segmented_control.dart';
import '../../../../core/design_system/components/dealgo_skeleton.dart';
import '../../../../core/design_system/components/dealgo_state_view.dart';
import '../../../../core/design_system/icons/dealgo_icons.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../core/motion/dealgo_sheet.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../driver_card/presentation/driver_card_tile.dart'
    show formatRatingAverage;
import '../../../food/domain/entities/food_money.dart';
import '../../../rating/domain/service_rating.dart';
import '../../../rating/presentation/rate_service_card.dart';
import '../../domain/merchant_stats.dart';
import '../../domain/usecases/get_merchant_catalog.dart';
import '../cubit/merchant_stats_cubit.dart';
import '../utils/merchant_routes.dart';
import '../widgets/merchant_widgets.dart';

enum _StatsChartMetric { orders, revenue }

class MerchantStatsPage extends StatefulWidget {
  const MerchantStatsPage({super.key});

  @override
  State<MerchantStatsPage> createState() => _MerchantStatsPageState();
}

class _MerchantStatsPageState extends State<MerchantStatsPage> {
  late final MerchantStatsCubit _cubit = MerchantStatsCubit(
    stats: context.read<MerchantStatsRepository>(),
    catalog: context.read<GetMerchantCatalog>(),
    ratings: context.read<RatingRepository>(),
  );
  var _days = 7;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) {
      return;
    }
    await _cubit.load(merchantAccessToken(context), days: _days);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocBuilder<MerchantStatsCubit, MerchantStatsState>(
      bloc: _cubit,
      builder: (context, state) {
        return MerchantPageFrame(
          title: l10n.merchantStatsTitle,
          showBack: false,
          body: switch (state) {
            MerchantStatsLoading() => const DealGoSkeletonList(itemCount: 3),
            MerchantStatsIneligible() => DealGoRefresh(
              onRefresh: _load,
              child: ListView(
                padding: dealGoScrollPadding(context, merchantPagePadding),
                children: [
                  MerchantNote(
                    tone: MerchantNoteTone.warning,
                    message: l10n.merchantStatsIneligible,
                  ),
                ],
              ),
            ),
            MerchantStatsFailed(:final cause) => DealGoRefresh(
              onRefresh: _load,
              child: DealGoStateView.failure(
                context,
                onRetry: () => unawaited(_load()),
                cause: cause,
                message: l10n.merchantStatsFailed,
              ),
            ),
            MerchantStatsReady() => DealGoRefresh(
              onRefresh: _load,
              child: _StatsBody(
                state: state,
                days: _days,
                onDays: (days) {
                  setState(() => _days = days);
                  unawaited(_load());
                },
              ),
            ),
          },
        );
      },
    );
  }
}

class _StatsBody extends StatefulWidget {
  const _StatsBody({
    required this.state,
    required this.days,
    required this.onDays,
  });

  final MerchantStatsReady state;
  final int days;
  final ValueChanged<int> onDays;

  @override
  State<_StatsBody> createState() => _StatsBodyState();
}

class _StatsBodyState extends State<_StatsBody> {
  _StatsChartMetric _chartMetric = _StatsChartMetric.orders;
  String? _selectedDayDate;

  @override
  void didUpdateWidget(covariant _StatsBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.days != widget.days) {
      _selectedDayDate = null;
    }
  }

  void _tryPush(BuildContext context, String route) {
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      router.push(route);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final state = widget.state;
    final stats = state.stats;
    final rating = state.rating;
    final ratingValue = rating?.average != null
        ? rating!.average!.toStringAsFixed(1)
        : l10n.merchantStatsRatingNew;

    final totalOrdersAttempted =
        stats.totals.deliveredCount + stats.totals.cancelledCount;
    final completionRateText = totalOrdersAttempted > 0
        ? '${((stats.totals.deliveredCount * 100) / totalOrdersAttempted).round()}%'
        : '—';
    final avgOrderValueText = stats.totals.deliveredCount > 0
        ? formatVnd(stats.totals.salesVnd ~/ stats.totals.deliveredCount)
        : '—';
    final dailyAvgSalesText = stats.days > 0
        ? formatVnd(stats.totals.salesVnd ~/ stats.days)
        : '—';

    MerchantDayStats? peakDay;
    for (final day in stats.series) {
      if (peakDay == null ||
          day.salesVnd > peakDay.salesVnd ||
          (day.salesVnd == peakDay.salesVnd &&
              day.deliveredCount > peakDay.deliveredCount)) {
        peakDay = day;
      }
    }

    final availableMenuCount =
        state.store?.items.where((item) => item.available).length ?? 0;
    final totalMenuCount = state.store?.items.length ?? 0;

    return ListView(
      padding: dealGoScrollPadding(context, merchantPagePadding),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        if (state.store != null) ...[
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state.store!.name,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (totalMenuCount > 0) ...[
                      const SizedBox(height: DealGoSpacing.s2),
                      Text(
                        '${l10n.merchantStatsMenuStatus}: ${l10n.merchantStatsMenuItemsCount(availableMenuCount, totalMenuCount)}',
                        style: textTheme.bodySmall?.copyWith(
                          color: DealGoColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: DealGoSpacing.s12),
        ],
        _QuickNavigationBar(
          l10n: l10n,
          onPush: (route) => _tryPush(context, route),
        ),
        const SizedBox(height: DealGoSpacing.s16),
        Text(
          l10n.merchantStatsToday,
          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: DealGoSpacing.s12),
        Row(
          children: [
            Expanded(
              child: _KpiCard(
                key: const Key('stats-sales-today'),
                label: l10n.merchantStatsSales,
                value: formatVnd(stats.today.salesVnd),
                subtitle: stats.today.deliveredCount > 0
                    ? '${l10n.merchantStatsAvgOrderValue}: ${formatVnd(stats.today.salesVnd ~/ stats.today.deliveredCount)}'
                    : null,
                tone: DealGoColors.primary,
              ),
            ),
            const SizedBox(width: DealGoSpacing.s12),
            Expanded(
              child: _KpiCard(
                key: const Key('stats-delivered-today'),
                label: l10n.merchantStatsDelivered,
                value: '${stats.today.deliveredCount}',
                subtitle: stats.today.cancelledCount > 0
                    ? '${l10n.merchantStatsCancelledOrders}: ${stats.today.cancelledCount}'
                    : null,
                tone: DealGoColors.brandGreen,
              ),
            ),
          ],
        ),
        const SizedBox(height: DealGoSpacing.s12),
        Row(
          children: [
            Expanded(
              child: _KpiCard(
                label: l10n.merchantStatsOpen,
                value: '${stats.openCount}',
                tone: DealGoColors.amber,
              ),
            ),
            const SizedBox(width: DealGoSpacing.s12),
            Expanded(
              child: _KpiCard(
                label: rating == null
                    ? l10n.merchantStatsRating
                    : '${l10n.merchantStatsRating} · ${l10n.merchantStatsRatingCount(rating.count)}',
                value: ratingValue,
                tone: const Color(0xFFEA580C),
              ),
            ),
          ],
        ),
        const SizedBox(height: DealGoSpacing.s20),
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.merchantStatsLastDays(stats.days),
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            SizedBox(
              width: 224,
              child: DealGoSegmentedControl(
                value: '${widget.days}',
                onChanged: (value) => widget.onDays(int.parse(value)),
                items: [
                  DealGoSegmentItem(id: '7', label: l10n.merchantStatsRange7),
                  DealGoSegmentItem(id: '14', label: l10n.merchantStatsRange14),
                  DealGoSegmentItem(id: '30', label: l10n.merchantStatsRange30),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: DealGoSpacing.s12),
        _PeriodKpiGrid(
          l10n: l10n,
          avgOrderValueText: avgOrderValueText,
          dailyAvgSalesText: dailyAvgSalesText,
          completionRateText: completionRateText,
          cancelledCount: stats.totals.cancelledCount,
          peakDay: peakDay,
        ),
        const SizedBox(height: DealGoSpacing.s12),
        _InteractiveSeriesCard(
          stats: stats,
          metric: _chartMetric,
          selectedDate: _selectedDayDate,
          onMetricChanged: (metric) {
            HapticFeedback.selectionClick();
            setState(() => _chartMetric = metric);
          },
          onSelectDay: (day) {
            HapticFeedback.selectionClick();
            setState(() => _selectedDayDate = day.date);
          },
          onInspectDaySheet: (day) => _showDayDetailSheet(
            context: context,
            day: day,
          ),
        ),
        if (state.statement != null) ...[
          const SizedBox(height: DealGoSpacing.s16),
          _StatementCard(statement: state.statement!),
        ],
        const SizedBox(height: DealGoSpacing.s16),
        DealGoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.merchantStatsTopItems,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: DealGoSpacing.s12),
              if (stats.topItems.isEmpty)
                Text(l10n.merchantStatsTopEmpty, style: textTheme.bodySmall)
              else
                _TopItemsList(
                  items: stats.topItems,
                  l10n: l10n,
                ),
            ],
          ),
        ),
        const SizedBox(height: DealGoSpacing.s12),
        _StoreReviews(
          state: state,
          onOpenReviews: () => _tryPush(context, MerchantRoutes.reviews),
        ),
      ],
    );
  }

  Future<void> _showDayDetailSheet({
    required BuildContext context,
    required MerchantDayStats day,
  }) async {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final totalDayOrders = day.deliveredCount + day.cancelledCount;
    final completionRate = totalDayOrders > 0
        ? '${((day.deliveredCount * 100) / totalDayOrders).round()}%'
        : '—';
    final dayAov = day.deliveredCount > 0
        ? formatVnd(day.salesVnd ~/ day.deliveredCount)
        : '—';

    await showDealGoSheet<void>(
      context: context,
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            DealGoSpacing.s16,
            DealGoSpacing.s8,
            DealGoSpacing.s16,
            DealGoSpacing.s20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.merchantStatsDayDetailTitle(_shortDate(day.date)),
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: DealGoSpacing.s12),
              DealGoCard(
                child: Column(
                  children: [
                    _DetailSheetRow(
                      label: l10n.merchantStatsMetricRevenue,
                      value: formatVnd(day.salesVnd),
                      emphasize: true,
                    ),
                    const Divider(height: DealGoSpacing.s16),
                    _DetailSheetRow(
                      label: l10n.merchantStatsDelivered,
                      value: l10n.merchantStatsDayRow(
                        day.deliveredCount,
                        day.cancelledCount,
                      ),
                    ),
                    const SizedBox(height: DealGoSpacing.s8),
                    _DetailSheetRow(
                      label: l10n.merchantStatsAvgOrderValue,
                      value: dayAov,
                    ),
                    const SizedBox(height: DealGoSpacing.s8),
                    _DetailSheetRow(
                      label: l10n.merchantStatsCompletionRate,
                      value: completionRate,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: DealGoSpacing.s12),
              DealGoSecondaryButton(
                label: l10n.merchantStatsQuickHistory,
                leadingIcon: DealGoIcons.history,
                onPressed: () {
                  Navigator.of(sheetCtx).pop();
                  _tryPush(context, MerchantRoutes.history);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickNavigationBar extends StatelessWidget {
  const _QuickNavigationBar({
    required this.l10n,
    required this.onPush,
  });

  final AppLocalizations l10n;
  final ValueChanged<String> onPush;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: DealGoSpacing.s8,
      runSpacing: DealGoSpacing.s8,
      children: [
        _QuickNavChip(
          key: const Key('stats-quick-history'),
          icon: DealGoIcons.history,
          label: l10n.merchantStatsQuickHistory,
          onTap: () => onPush(MerchantRoutes.history),
        ),
        _QuickNavChip(
          key: const Key('stats-quick-offers'),
          icon: DealGoIcons.voucher,
          label: l10n.merchantStatsQuickOffers,
          onTap: () => onPush(MerchantRoutes.offers),
        ),
        _QuickNavChip(
          key: const Key('stats-quick-reviews'),
          icon: DealGoIcons.star,
          label: l10n.merchantStatsQuickReviews,
          onTap: () => onPush(MerchantRoutes.reviews),
        ),
      ],
    );
  }
}

class _QuickNavChip extends StatelessWidget {
  const _QuickNavChip({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: DealGoColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DealGoRadius.pill),
        side: BorderSide(color: DealGoColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(DealGoRadius.pill),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: DealGoSpacing.s12,
            vertical: DealGoSpacing.s8,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: DealGoColors.primary),
              const SizedBox(width: DealGoSpacing.s6),
              Text(
                label,
                style: textTheme.labelMedium?.copyWith(
                  color: DealGoColors.text,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: DealGoSpacing.s4),
              Icon(
                DealGoIcons.chevronRight,
                size: 14,
                color: DealGoColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PeriodKpiGrid extends StatelessWidget {
  const _PeriodKpiGrid({
    required this.l10n,
    required this.avgOrderValueText,
    required this.dailyAvgSalesText,
    required this.completionRateText,
    required this.cancelledCount,
    required this.peakDay,
  });

  final AppLocalizations l10n;
  final String avgOrderValueText;
  final String dailyAvgSalesText;
  final String completionRateText;
  final int cancelledCount;
  final MerchantDayStats? peakDay;

  @override
  Widget build(BuildContext context) {
    final hasPeak = peakDay != null &&
        (peakDay!.salesVnd > 0 || peakDay!.deliveredCount > 0);
    final peakValue = hasPeak ? _shortDate(peakDay!.date) : '—';
    final peakSub = hasPeak ? formatVnd(peakDay!.salesVnd) : null;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _MiniMetricTile(
                key: const Key('stats-kpi-aov'),
                label: l10n.merchantStatsAvgOrderValue,
                value: avgOrderValueText,
              ),
            ),
            const SizedBox(width: DealGoSpacing.s12),
            Expanded(
              child: _MiniMetricTile(
                key: const Key('stats-kpi-daily-avg'),
                label: l10n.merchantStatsDailyAvgSales,
                value: dailyAvgSalesText,
              ),
            ),
          ],
        ),
        const SizedBox(height: DealGoSpacing.s12),
        Row(
          children: [
            Expanded(
              child: _MiniMetricTile(
                key: const Key('stats-kpi-completion'),
                label: l10n.merchantStatsCompletionRate,
                value: completionRateText,
                subtitle:
                    '${l10n.merchantStatsCancelledOrders}: $cancelledCount',
              ),
            ),
            const SizedBox(width: DealGoSpacing.s12),
            Expanded(
              child: _MiniMetricTile(
                key: const Key('stats-kpi-peak-day'),
                label: l10n.merchantStatsPeakDay,
                value: peakValue,
                subtitle: peakSub,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MiniMetricTile extends StatelessWidget {
  const _MiniMetricTile({
    super.key,
    required this.label,
    required this.value,
    this.subtitle,
  });

  final String label;
  final String value;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return DealGoCard(
      padding: const EdgeInsets.symmetric(
        horizontal: DealGoSpacing.s12,
        vertical: DealGoSpacing.s12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: textTheme.labelSmall?.copyWith(
              color: DealGoColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: DealGoSpacing.s4),
          Text(
            value,
            style: textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: DealGoColors.text,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: DealGoSpacing.s2),
            Text(
              subtitle!,
              style: textTheme.bodySmall?.copyWith(
                color: DealGoColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InteractiveSeriesCard extends StatelessWidget {
  const _InteractiveSeriesCard({
    required this.stats,
    required this.metric,
    required this.selectedDate,
    required this.onMetricChanged,
    required this.onSelectDay,
    required this.onInspectDaySheet,
  });

  final MerchantStats stats;
  final _StatsChartMetric metric;
  final String? selectedDate;
  final ValueChanged<_StatsChartMetric> onMetricChanged;
  final ValueChanged<MerchantDayStats> onSelectDay;
  final ValueChanged<MerchantDayStats> onInspectDaySheet;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final series = stats.series;

    MerchantDayStats? activeDay;
    if (series.isNotEmpty) {
      if (selectedDate != null) {
        for (final d in series) {
          if (d.date == selectedDate) {
            activeDay = d;
            break;
          }
        }
      }
      activeDay ??= series.last;
    }

    return DealGoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.merchantStatsOrdersByDay,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              SizedBox(
                width: 180,
                child: DealGoSegmentedControl(
                  value: metric.name,
                  onChanged: (val) => onMetricChanged(
                    val == _StatsChartMetric.revenue.name
                        ? _StatsChartMetric.revenue
                        : _StatsChartMetric.orders,
                  ),
                  items: [
                    DealGoSegmentItem(
                      id: _StatsChartMetric.orders.name,
                      label: l10n.merchantStatsMetricOrders,
                    ),
                    DealGoSegmentItem(
                      id: _StatsChartMetric.revenue.name,
                      label: l10n.merchantStatsMetricRevenue,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: DealGoSpacing.s16),
          _InteractiveMiniBars(
            series: series,
            days: stats.days,
            metric: metric,
            selectedDate: activeDay?.date,
            onSelectDay: onSelectDay,
          ),
          const SizedBox(height: DealGoSpacing.s12),
          Text(
            l10n.merchantStatsTotals(
              stats.totals.deliveredCount,
              formatVnd(stats.totals.salesVnd),
              stats.totals.cancelledCount,
            ),
            style: textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          if (activeDay != null) ...[
            const SizedBox(height: DealGoSpacing.s12),
            Text(
              l10n.merchantStatsTapBarHint,
              style: textTheme.labelSmall?.copyWith(
                color: DealGoColors.textSecondary,
              ),
            ),
            const SizedBox(height: DealGoSpacing.s6),
            InkWell(
              key: const Key('stats-selected-day-panel'),
              borderRadius: BorderRadius.circular(DealGoRadius.input),
              onTap: () => onInspectDaySheet(activeDay!),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: DealGoSpacing.s12,
                  vertical: DealGoSpacing.s8,
                ),
                decoration: BoxDecoration(
                  color: DealGoColors.subtlePurple,
                  borderRadius: BorderRadius.circular(DealGoRadius.input),
                  border: Border.all(color: DealGoColors.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.merchantStatsSelectedDay(
                              _shortDate(activeDay.date),
                            ),
                            style: textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: DealGoColors.text,
                            ),
                          ),
                          const SizedBox(height: DealGoSpacing.s2),
                          Text(
                            l10n.merchantStatsDayRow(
                              activeDay.deliveredCount,
                              activeDay.cancelledCount,
                            ),
                            style: textTheme.bodySmall?.copyWith(
                              color: DealGoColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      formatVnd(activeDay.salesVnd),
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: DealGoColors.primary,
                      ),
                    ),
                    const SizedBox(width: DealGoSpacing.s4),
                    Icon(
                      DealGoIcons.chevronRight,
                      size: 16,
                      color: DealGoColors.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InteractiveMiniBars extends StatelessWidget {
  const _InteractiveMiniBars({
    required this.series,
    required this.days,
    required this.metric,
    required this.selectedDate,
    required this.onSelectDay,
  });

  final List<MerchantDayStats> series;
  final int days;
  final _StatsChartMetric metric;
  final String? selectedDate;
  final ValueChanged<MerchantDayStats> onSelectDay;

  int _metricValue(MerchantDayStats day) => switch (metric) {
    _StatsChartMetric.orders => day.deliveredCount,
    _StatsChartMetric.revenue => day.salesVnd,
  };

  /// `dd/MM` for 7 days; for 14/30 days only periodic labels to keep it legible.
  static String _dayLabel(String date, int days, {required bool isSelected}) {
    final parts = date.split('-');
    if (parts.length != 3) {
      return '';
    }
    final label = '${parts[2]}/${parts[1]}';
    if (days <= 7 || isSelected) {
      return label;
    }
    final day = int.tryParse(parts[2]) ?? 0;
    final step = days <= 14 ? 3 : 5;
    return day % step == 0 ? parts[2] : '';
  }

  @override
  Widget build(BuildContext context) {
    final maxVal = series.fold<int>(
      0,
      (max, day) => _metricValue(day) > max ? _metricValue(day) : max,
    );
    final activeColor = metric == _StatsChartMetric.orders
        ? DealGoColors.primary
        : DealGoColors.brandGreen;

    return SizedBox(
      height: 124,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var index = 0; index < series.length; index++) ...[
            if (index > 0)
              SizedBox(width: series.length > 10 ? 2 : DealGoSpacing.s8),
            Expanded(
              child: Builder(
                builder: (context) {
                  final day = series[index];
                  final val = _metricValue(day);
                  final isSelected = day.date == selectedDate;
                  final factor = maxVal == 0
                      ? 0.04
                      : (val / maxVal).clamp(val > 0 ? 0.12 : 0.04, 1.0);
                  return GestureDetector(
                    key: Key('stats-bar-${day.date}'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onSelectDay(day),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Flexible(
                          child: FractionallySizedBox(
                            heightFactor: factor,
                            widthFactor: 1,
                            alignment: Alignment.bottomCenter,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              decoration: BoxDecoration(
                                color: val == 0
                                    ? DealGoColors.border
                                    : (isSelected
                                          ? activeColor
                                          : activeColor.withValues(alpha: 0.4)),
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: DealGoSpacing.s8),
                        Text(
                          _dayLabel(day.date, days, isSelected: isSelected),
                          maxLines: 1,
                          overflow: TextOverflow.clip,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                fontWeight: isSelected
                                    ? FontWeight.w800
                                    : FontWeight.w500,
                                color: isSelected
                                    ? DealGoColors.text
                                    : DealGoColors.textSecondary,
                              ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TopItemsList extends StatelessWidget {
  const _TopItemsList({
    required this.items,
    required this.l10n,
  });

  final List<MerchantTopItem> items;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    var totalPortions = 0;
    var maxQuantity = 1;
    for (final item in items) {
      totalPortions += item.quantity;
      if (item.quantity > maxQuantity) {
        maxQuantity = item.quantity;
      }
    }

    return Column(
      children: [
        for (final (index, item) in items.indexed) ...[
          if (index > 0) const SizedBox(height: DealGoSpacing.s12),
          _RankRow(
            rank: '#${index + 1}',
            isFirst: index == 0,
            name: item.name,
            count: l10n.merchantStatsPortions(item.quantity),
            shareLabel: l10n.merchantStatsItemShare(
              totalPortions > 0
                  ? ((item.quantity * 100) / totalPortions).round()
                  : 0,
            ),
            ratio: (item.quantity / maxQuantity).clamp(0.08, 1.0),
          ),
        ],
      ],
    );
  }
}

/// Cash received at pickup vs. DealGo commission owed.
class _StatementCard extends StatelessWidget {
  const _StatementCard({required this.statement});

  final MerchantStatement statement;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final percent = statement.commissionPercentNow;
    final percentLabel = percent == percent.roundToDouble()
        ? '${percent.toInt()}'
        : percent.toStringAsFixed(1);
    final last = statement.settlements.isEmpty
        ? null
        : statement.settlements.first;

    final totalCash = statement.cashReceivedVnd;
    final commRatio = totalCash > 0
        ? (statement.commissionVnd / totalCash).clamp(0.0, 1.0)
        : (percent / 100.0).clamp(0.0, 1.0);
    final commPercentInt = (commRatio * 100).round();
    final netPercentInt = (100 - commPercentInt).clamp(0, 100);

    Widget row(String label, String value, {Color? tone, Key? key}) => Padding(
      padding: const EdgeInsets.only(bottom: DealGoSpacing.s8),
      child: Row(
        children: [
          Expanded(child: Text(label, style: textTheme.bodyMedium)),
          Text(
            value,
            key: key,
            style: textTheme.titleSmall?.copyWith(color: tone),
          ),
        ],
      ),
    );
    return DealGoCard(
      key: const Key('merchant-statement'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.merchantStatementTitle,
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          if (totalCash > 0) ...[
            const SizedBox(height: DealGoSpacing.s12),
            ClipRRect(
              borderRadius: BorderRadius.circular(DealGoRadius.pill),
              child: SizedBox(
                height: 8,
                child: Row(
                  children: [
                    if (netPercentInt > 0)
                      Expanded(
                        flex: netPercentInt,
                        child: Container(color: DealGoColors.brandGreen),
                      ),
                    if (commPercentInt > 0)
                      Expanded(
                        flex: commPercentInt,
                        child: Container(color: DealGoColors.primary),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: DealGoSpacing.s6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.merchantStatsNetShare(netPercentInt),
                  style: textTheme.labelSmall?.copyWith(
                    color: DealGoColors.brandGreen,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  l10n.merchantStatsCommissionShare(commPercentInt),
                  style: textTheme.labelSmall?.copyWith(
                    color: DealGoColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: DealGoSpacing.s12),
          row(
            l10n.merchantStatementCash(statement.orderCount),
            formatVnd(statement.cashReceivedVnd),
          ),
          row(
            l10n.merchantStatementCommission(percentLabel),
            formatVnd(statement.commissionVnd),
          ),
          row(l10n.merchantStatementNet, formatVnd(statement.netVnd)),
          if (statement.settlementCycleDays > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: DealGoSpacing.s8),
              child: Text(
                l10n.merchantStatementCycle(statement.settlementCycleDays),
                key: const Key('merchant-statement-cycle'),
                style: textTheme.bodySmall,
              ),
            ),
          if (statement.unsettledCommissionVnd > 0)
            row(
              l10n.merchantStatementUnsettled,
              formatVnd(statement.unsettledCommissionVnd),
              tone: DealGoColors.danger,
              key: const Key('merchant-statement-unsettled'),
            )
          else if (statement.commissionVnd > 0)
            Text(l10n.merchantStatementAllPaid, style: textTheme.bodySmall),
          if (last != null) ...[
            const SizedBox(height: DealGoSpacing.s4),
            Text(
              l10n.merchantStatementLastPaid(
                '${_shortDate(last.periodStart)}–${_shortDate(last.periodEnd)}',
                formatVnd(last.commissionVnd),
              ),
              style: textTheme.bodySmall,
            ),
          ],
          if (statement.settlements.isNotEmpty) ...[
            const SizedBox(height: DealGoSpacing.s8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const Key('merchant-statement-history-btn'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DealGoSpacing.s8,
                    vertical: DealGoSpacing.s4,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () => _showSettlementsSheet(context, statement),
                icon: const Icon(DealGoIcons.history, size: 15),
                label: Text(
                  l10n.merchantStatsStatementHistoryBtn(
                    statement.settlements.length,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: DealGoSpacing.s8),
          Text(l10n.merchantStatementNote, style: textTheme.bodySmall),
        ],
      ),
    );
  }

  Future<void> _showSettlementsSheet(
    BuildContext context,
    MerchantStatement statement,
  ) async {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    await showDealGoSheet<void>(
      context: context,
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            DealGoSpacing.s16,
            DealGoSpacing.s8,
            DealGoSpacing.s16,
            DealGoSpacing.s20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.merchantStatsStatementHistoryTitle,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: DealGoSpacing.s12),
              for (var i = 0; i < statement.settlements.length; i++) ...[
                if (i > 0) const Divider(height: DealGoSpacing.s16),
                Builder(
                  builder: (context) {
                    final s = statement.settlements[i];
                    return Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_shortDate(s.periodStart)} – ${_shortDate(s.periodEnd)}',
                                style: textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (s.createdAt != null)
                                Text(
                                  DateFormat('dd/MM/yyyy HH:mm')
                                      .format(s.createdAt!.toLocal()),
                                  style: textTheme.bodySmall?.copyWith(
                                    color: DealGoColors.textSecondary,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Text(
                          formatVnd(s.commissionVnd),
                          style: textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: DealGoColors.brandGreen,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailSheetRow extends StatelessWidget {
  const _DetailSheetRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final style = (emphasize ? textTheme.bodyMedium : textTheme.bodySmall)
        ?.copyWith(
          fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
          color: emphasize ? DealGoColors.text : DealGoColors.textSecondary,
        );
    return Row(
      children: [
        Expanded(child: Text(label, style: style)),
        Text(
          value,
          style: style?.copyWith(
            fontWeight: FontWeight.w800,
            color: DealGoColors.text,
          ),
        ),
      ],
    );
  }
}

class _StoreReviews extends StatelessWidget {
  const _StoreReviews({
    required this.state,
    required this.onOpenReviews,
  });

  final MerchantStatsReady state;
  final VoidCallback onOpenReviews;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final failure = state.reviewsFailure;
    final reviews = state.reviews;
    final storeMissing = state.store == null;
    return DealGoCard(
      key: const Key('merchant-store-reviews'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.foodStoreTabReviews,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (!storeMissing)
                TextButton(
                  onPressed: onOpenReviews,
                  child: Text(l10n.merchantStatsQuickReviews),
                ),
            ],
          ),
          const SizedBox(height: DealGoSpacing.s12),
          if (storeMissing)
            Text(l10n.foodStoreReviewsNone, style: textTheme.bodySmall)
          else if (failure != null)
            Text(
              l10n.foodStoreReviewsUnavailable,
              key: const Key('merchant-store-reviews-error'),
              style: textTheme.bodySmall,
            )
          else if (reviews == null)
            Text(l10n.foodStoreReviewsNone, style: textTheme.bodySmall)
          else ...[
            _ReviewSummary(
              summary: reviews.summary,
              items: reviews.items,
            ),
            for (final review in reviews.items) ...[
              const SizedBox(height: DealGoSpacing.s12),
              const Divider(height: 1),
              const SizedBox(height: DealGoSpacing.s12),
              _ReviewRow(review: review),
            ],
          ],
        ],
      ),
    );
  }
}

class _ReviewSummary extends StatelessWidget {
  const _ReviewSummary({
    required this.summary,
    required this.items,
  });

  final StoreRating summary;
  final List<StoreReview> items;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final average = summary.average;
    final text = average == null
        ? (summary.count == 0
              ? l10n.foodStoreReviewsNone
              : l10n.foodStoreReviewsHidden(summary.count))
        : l10n.foodStoreReviewsSummary(
            formatRatingAverage(context, average),
            summary.count,
          );

    final starCounts = <int, int>{5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
    for (final item in items) {
      final stars = item.stars.clamp(1, 5);
      starCounts[stars] = (starCounts[stars] ?? 0) + 1;
    }
    final totalSample = items.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              DealGoIcons.starFilled,
              color: DealGoColors.amber,
              size: 18,
            ),
            const SizedBox(width: DealGoSpacing.s8),
            Expanded(
              child: Text(
                text,
                key: const Key('merchant-store-review-summary'),
                style: textTheme.titleSmall,
              ),
            ),
          ],
        ),
        if (totalSample > 0) ...[
          const SizedBox(height: DealGoSpacing.s8),
          for (final star in [5, 4, 3, 2, 1])
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  SizedBox(
                    width: 28,
                    child: Text(
                      '$star★',
                      style: textTheme.labelSmall?.copyWith(
                        color: DealGoColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(DealGoRadius.pill),
                      child: LinearProgressIndicator(
                        value: (starCounts[star] ?? 0) / totalSample,
                        minHeight: 5,
                        backgroundColor:
                            DealGoColors.border.withValues(alpha: 0.45),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          DealGoColors.amber,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({required this.review});

  final StoreReview review;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (var i = 0; i < 5; i++)
              Icon(
                DealGoIcons.starFilled,
                size: 14,
                color: i < review.stars
                    ? DealGoColors.amber
                    : DealGoColors.border,
              ),
            const Spacer(),
            Text(
              DateFormat('dd/MM/yyyy').format(review.createdAt.toLocal()),
              style: textTheme.labelSmall?.copyWith(
                color: DealGoColors.textSecondary,
              ),
            ),
          ],
        ),
        if (review.tags.isNotEmpty) ...[
          const SizedBox(height: DealGoSpacing.s8),
          Text(
            [for (final tag in review.tags) ratingTagLabel(l10n, tag)]
                .join(' · '),
            style: textTheme.bodySmall?.copyWith(color: DealGoColors.primary),
          ),
        ],
        if (review.comment != null) ...[
          const SizedBox(height: DealGoSpacing.s8),
          Text(review.comment!, style: textTheme.bodyMedium),
        ],
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    required this.tone,
    this.subtitle,
    super.key,
  });

  final String label;
  final String value;
  final Color tone;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return DealGoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: textTheme.bodySmall),
          const SizedBox(height: DealGoSpacing.s8),
          Text(
            value,
            style: textTheme.titleLarge?.copyWith(
              color: tone,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: DealGoSpacing.s4),
            Text(
              subtitle!,
              style: textTheme.labelSmall?.copyWith(
                color: DealGoColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow({
    required this.rank,
    required this.isFirst,
    required this.name,
    required this.count,
    required this.shareLabel,
    required this.ratio,
  });

  final String rank;
  final bool isFirst;
  final String name;
  final String count;
  final String shareLabel;
  final double ratio;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: DealGoColors.subtlePurple,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: DealGoSpacing.s8,
                  vertical: DealGoSpacing.s4,
                ),
                child: Text(
                  rank,
                  style: textTheme.labelSmall?.copyWith(
                    color: DealGoColors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(width: DealGoSpacing.s12),
            Expanded(
              child: Text(
                name,
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  count,
                  style: textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: DealGoColors.primary,
                  ),
                ),
                Text(
                  shareLabel,
                  style: textTheme.labelSmall?.copyWith(
                    color: DealGoColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: DealGoSpacing.s6),
        ClipRRect(
          borderRadius: BorderRadius.circular(DealGoRadius.pill),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 6,
            backgroundColor: DealGoColors.border.withValues(alpha: 0.45),
            valueColor: AlwaysStoppedAnimation<Color>(
              isFirst
                  ? DealGoColors.primary
                  : DealGoColors.primary.withValues(alpha: 0.6),
            ),
          ),
        ),
      ],
    );
  }
}

String _shortDate(String date) {
  final parts = date.split('-');
  return parts.length == 3 ? '${parts[2]}/${parts[1]}' : date;
}
