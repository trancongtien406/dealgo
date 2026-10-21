import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design_system/components/dealgo_card.dart';
import '../../../../core/design_system/components/dealgo_skeleton.dart';
import '../../../../core/design_system/components/dealgo_state_view.dart';
import '../../../../core/design_system/components/dealgo_segmented_control.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../food/domain/entities/food_money.dart';
import '../../../rating/domain/service_rating.dart';
import '../../domain/merchant_stats.dart';
import '../../domain/usecases/get_merchant_catalog.dart';
import '../cubit/merchant_stats_cubit.dart';
import '../widgets/merchant_widgets.dart';

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
          onBack: () => merchantBack(context),
          body: switch (state) {
            MerchantStatsLoading() => const DealGoSkeletonList(itemCount: 3),
            MerchantStatsIneligible() => ListView(
              padding: merchantPagePadding,
              children: [
                MerchantNote(
                  tone: MerchantNoteTone.warning,
                  message: l10n.merchantStatsIneligible,
                ),
              ],
            ),
            MerchantStatsFailed(:final cause) => DealGoStateView.failure(
              context,
              onRetry: () => unawaited(_load()),
              cause: cause,
              message: l10n.merchantStatsFailed,
            ),
            MerchantStatsReady() => RefreshIndicator(
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

class _StatsBody extends StatelessWidget {
  const _StatsBody({
    required this.state,
    required this.days,
    required this.onDays,
  });

  final MerchantStatsReady state;
  final int days;
  final ValueChanged<int> onDays;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final stats = state.stats;
    final rating = state.rating;
    final ratingValue = rating?.average != null
        ? rating!.average!.toStringAsFixed(1)
        : l10n.merchantStatsRatingNew;
    final maxDelivered = stats.series.fold<int>(
      0,
      (max, day) => day.deliveredCount > max ? day.deliveredCount : max,
    );
    return ListView(
      padding: merchantPagePadding,
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        if (state.store != null) ...[
          Text(state.store!.name, style: textTheme.titleMedium),
          const SizedBox(height: DealGoSpacing.s8),
        ],
        Text(l10n.merchantStatsToday, style: textTheme.titleMedium),
        const SizedBox(height: DealGoSpacing.s12),
        Row(
          children: [
            Expanded(
              child: _KpiCard(
                key: const Key('stats-sales-today'),
                label: l10n.merchantStatsSales,
                value: formatVnd(stats.today.salesVnd),
                tone: DealGoColors.primary,
              ),
            ),
            const SizedBox(width: DealGoSpacing.s12),
            Expanded(
              child: _KpiCard(
                key: const Key('stats-delivered-today'),
                label: l10n.merchantStatsDelivered,
                value: '${stats.today.deliveredCount}',
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
                style: textTheme.titleMedium,
              ),
            ),
            SizedBox(
              width: 180,
              child: DealGoSegmentedControl(
                value: '$days',
                onChanged: (value) => onDays(int.parse(value)),
                items: [
                  DealGoSegmentItem(id: '7', label: l10n.merchantStatsRange7),
                  DealGoSegmentItem(id: '30', label: l10n.merchantStatsRange30),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: DealGoSpacing.s12),
        DealGoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.merchantStatsOrdersByDay, style: textTheme.titleMedium),
              const SizedBox(height: DealGoSpacing.s16),
              _MiniBars(
                values: [
                  for (final day in stats.series)
                    maxDelivered == 0
                        ? 0.02
                        : day.deliveredCount / maxDelivered,
                ],
                labels: [
                  for (final day in stats.series)
                    _dayLabel(day.date, stats.days),
                ],
              ),
              const SizedBox(height: DealGoSpacing.s12),
              Text(
                l10n.merchantStatsTotals(
                  stats.totals.deliveredCount,
                  formatVnd(stats.totals.salesVnd),
                  stats.totals.cancelledCount,
                ),
                style: textTheme.bodySmall,
              ),
            ],
          ),
        ),
        const SizedBox(height: DealGoSpacing.s16),
        DealGoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.merchantStatsTopItems, style: textTheme.titleMedium),
              const SizedBox(height: DealGoSpacing.s12),
              if (stats.topItems.isEmpty)
                Text(l10n.merchantStatsTopEmpty, style: textTheme.bodySmall)
              else
                for (final (index, item) in stats.topItems.indexed) ...[
                  if (index > 0) const SizedBox(height: DealGoSpacing.s8),
                  _RankRow(
                    rank: '${index + 1}',
                    name: item.name,
                    count: l10n.merchantStatsPortions(item.quantity),
                  ),
                ],
            ],
          ),
        ),
        const SizedBox(height: DealGoSpacing.s12),
        MerchantNote(
          tone: MerchantNoteTone.green,
          message: l10n.merchantStatsNote,
        ),
      ],
    );
  }

  /// `dd/MM` for 7 days; for 30 days only every 5th label to keep it legible.
  static String _dayLabel(String date, int days) {
    final parts = date.split('-');
    if (parts.length != 3) {
      return '';
    }
    final label = '${parts[2]}/${parts[1]}';
    if (days <= 7) {
      return label;
    }
    final day = int.tryParse(parts[2]) ?? 0;
    return day % 5 == 0 ? parts[2] : '';
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    required this.tone,
    super.key,
  });

  final String label;
  final String value;
  final Color tone;

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
        ],
      ),
    );
  }
}

class _MiniBars extends StatelessWidget {
  const _MiniBars({required this.values, required this.labels});

  final List<double> values;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var index = 0; index < values.length; index++) ...[
            if (index > 0)
              SizedBox(width: values.length > 10 ? 2 : DealGoSpacing.s8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Flexible(
                    child: FractionallySizedBox(
                      heightFactor: values[index],
                      widthFactor: 1,
                      alignment: Alignment.bottomCenter,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: index == values.length - 1
                              ? DealGoColors.brandGreen
                              : DealGoColors.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: DealGoSpacing.s8),
                  Text(
                    labels[index],
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow({required this.rank, required this.name, required this.count});

  final String rank;
  final String name;
  final String count;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: DealGoColors.subtlePurple,
            borderRadius: BorderRadius.circular(999),
          ),
          child: SizedBox(
            width: 28,
            height: 28,
            child: Center(
              child: Text(
                rank,
                style: textTheme.labelSmall?.copyWith(
                  color: DealGoColors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: DealGoSpacing.s12),
        Expanded(child: Text(name, style: textTheme.bodyMedium)),
        Text(
          count,
          style: textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}
