import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/design_system/components/dealgo_card.dart';
import '../../../../core/design_system/components/dealgo_chip.dart';
import '../../../../core/design_system/components/dealgo_refresh.dart';
import '../../../../core/design_system/components/dealgo_segmented_control.dart';
import '../../../../core/design_system/components/dealgo_skeleton.dart';
import '../../../../core/design_system/components/dealgo_state_view.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../driver_history/domain/driver_history.dart';
import '../../../driver_history/presentation/driver_history_cubit.dart';
import '../../../food/domain/entities/food_money.dart';
import '../../../identity/domain/entities/auth_state.dart';
import '../../../identity/presentation/cubit/auth_cubit.dart';
import '../../../onboarding/presentation/cubit/driver_kyc_cubit.dart';
import '../utils/driver_routes.dart';
import '../utils/driver_service_icons.dart';
import '../widgets/driver_widgets.dart';
import '../../../../core/design_system/components/dealgo_nav_insets.dart';

enum _EarnRange { today, week }

/// Driver earnings (today / 7 days, UTC+7 days from the server) and job history.
class DriverEarningsPage extends StatelessWidget {
  const DriverEarningsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final auth = context.read<AuthCubit>();
        return DriverHistoryCubit(
          repository: context.read<DriverHistoryRepository>(),
          accessToken: () {
            final state = auth.state;
            return state is AuthSignedIn ? state.tokens.accessToken : null;
          },
        )..load();
      },
      child: const _DriverEarningsView(),
    );
  }
}

class _DriverEarningsView extends StatefulWidget {
  const _DriverEarningsView();

  @override
  State<_DriverEarningsView> createState() => _DriverEarningsViewState();
}

class _DriverEarningsViewState extends State<_DriverEarningsView> {
  var _range = _EarnRange.today;

  static const _padding = EdgeInsets.fromLTRB(
    DealGoDimensions.pageGutter,
    DealGoSpacing.s12,
    DealGoDimensions.pageGutter,
    DealGoSpacing.s16,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.watch<DriverHistoryCubit>().state;
    return DriverPageFrame(
      title: l10n.drvHistTitle,
      showBack: false,
      body: _body(context, state),
    );
  }

  Widget _body(BuildContext context, DriverHistoryState state) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<DriverHistoryCubit>();
    final summary = state.summary;
    if (state.status == DriverHistoryStatus.failed && summary == null) {
      return ListView(
        padding: dealGoScrollPadding(context, _padding),
        children: [
          DealGoStateView.failure(
            context,
            onRetry: cubit.load,
            cause: state.cause,
            compact: true,
          ),
        ],
      );
    }
    if (summary == null) {
      return DealGoSkeletonList(
        padding: _padding,
        thumbSize: 44,
        semanticLabel: l10n.drvHistLoading,
      );
    }
    return DealGoRefresh(
      onRefresh: cubit.load,
      child: ListView(
        key: const Key('driver-history-list'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: dealGoScrollPadding(context, _padding),
        children: [
          DealGoSegmentedControl(
            value: _range.name,
            onChanged: (id) => setState(
              () => _range = _EarnRange.values.firstWhere((e) => e.name == id),
            ),
            items: [
              DealGoSegmentItem(id: 'today', label: l10n.drvHistToday),
              DealGoSegmentItem(id: 'week', label: l10n.drvHistWeek),
            ],
          ),
          const SizedBox(height: DealGoSpacing.s16),
          _Hero(summary: summary, week: _range == _EarnRange.week),
          const SizedBox(height: DealGoSpacing.s12),
          Row(
            children: [
              Expanded(
                child: _range == _EarnRange.week
                    ? _SplitCard(
                        title: l10n.drvHistRides,
                        amount: formatVnd(summary.weekRideEarningsVnd),
                        meta: l10n.drvHistWeek,
                      )
                    : _SplitCard(
                        title: l10n.drvHistRating,
                        amount: summary.ratingAverage == null
                            ? '—'
                            : '${summary.ratingAverage!.toStringAsFixed(1)}/5',
                        meta: summary.ratingAverage == null
                            ? l10n.drvHistNoRating
                            : l10n.drvHistRatingCount(summary.ratingCount),
                      ),
              ),
              const SizedBox(width: DealGoSpacing.s12),
              Expanded(
                child: _range == _EarnRange.week
                    ? _SplitCard(
                        title: l10n.drvHistFood,
                        amount: formatVnd(summary.weekFoodEarningsVnd),
                        meta: l10n.drvHistCancelled(summary.weekCancelledJobs),
                      )
                    : _SplitCard(
                        title: l10n.drvHistEarnedWeek,
                        amount: formatVnd(summary.weekEarningsVnd),
                        meta: l10n.drvHistJobs(summary.weekCompletedJobs),
                      ),
              ),
            ],
          ),
          const SizedBox(height: DealGoSpacing.s20),
          DealGoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.drvHistEarnedWeek,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: DealGoSpacing.s16),
                _WeekBars(days: summary.days),
              ],
            ),
          ),
          const SizedBox(height: DealGoSpacing.s20),
          Text(
            l10n.drvHistRecent,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: DealGoSpacing.s8),
          Wrap(
            spacing: DealGoSpacing.s8,
            children: [
              DealGoChip(
                key: const Key('driver-history-filter-all'),
                label: l10n.drvHistFilterAll,
                selected: state.filter == null,
                onTap: () => cubit.setFilter(null),
              ),
              DealGoChip(
                key: const Key('driver-history-filter-ride'),
                label: l10n.drvHistRides,
                selected: state.filter == DriverJobKind.ride,
                onTap: () => cubit.setFilter(DriverJobKind.ride),
              ),
              DealGoChip(
                key: const Key('driver-history-filter-food'),
                label: l10n.drvHistFood,
                selected: state.filter == DriverJobKind.food,
                onTap: () => cubit.setFilter(DriverJobKind.food),
              ),
            ],
          ),
          const SizedBox(height: DealGoSpacing.s12),
          ..._history(context, state),
        ],
      ),
    );
  }

  List<Widget> _history(BuildContext context, DriverHistoryState state) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<DriverHistoryCubit>();
    if (state.status == DriverHistoryStatus.loading) {
      return const [
        Padding(
          padding: EdgeInsets.all(DealGoSpacing.s16),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    if (state.status == DriverHistoryStatus.failed) {
      return [
        DealGoStateView.failure(
          context,
          onRetry: cubit.load,
          cause: state.cause,
          compact: true,
        ),
      ];
    }
    if (state.items.isEmpty) {
      return [
        DealGoStateView(
          art: DealGoStateArt.noOrders,
          title: l10n.drvHistEmptyTitle,
          message: l10n.drvHistEmptyBody,
          compact: true,
        ),
      ];
    }
    return [
      for (final item in state.items) ...[
        _HistoryRow(item: item),
        const SizedBox(height: DealGoSpacing.s12),
      ],
      if (state.hasMore)
        Center(
          child: state.loadingMore
              ? const Padding(
                  padding: EdgeInsets.all(DealGoSpacing.s8),
                  child: CircularProgressIndicator(),
                )
              : TextButton(
                  key: const Key('driver-history-more'),
                  onPressed: cubit.loadMore,
                  child: Text(
                    state.moreFailed
                        ? l10n.drvHistLoadMoreFailed
                        : l10n.drvHistLoadMore,
                  ),
                ),
        ),
    ];
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.summary, required this.week});

  final DriverHistorySummary summary;
  final bool week;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final amount = week ? summary.weekEarningsVnd : summary.today.earningsVnd;
    final jobs = week ? summary.weekCompletedJobs : summary.today.completedJobs;
    final gross = week ? summary.weekGrossVnd : summary.today.grossVnd;
    final fee = week ? summary.weekFeeVnd : summary.today.feeVnd;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: DealGoColors.primary,
        borderRadius: BorderRadius.circular(DealGoRadius.card),
      ),
      child: Padding(
        padding: const EdgeInsets.all(DealGoSpacing.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    week ? l10n.drvHistEarnedWeek : l10n.drvHistEarnedToday,
                    style: textTheme.bodyMedium?.copyWith(
                      color: DealGoColors.card.withValues(alpha: 0.9),
                    ),
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: DealGoColors.card.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(DealGoRadius.pill),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DealGoSpacing.s8,
                      vertical: 4,
                    ),
                    child: Text(
                      l10n.drvHistJobs(jobs),
                      style: TextStyle(
                        color: DealGoColors.card,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: DealGoSpacing.s8),
            Text(
              formatVnd(amount),
              key: const Key('driver-history-hero-amount'),
              style: textTheme.headlineMedium?.copyWith(
                color: DealGoColors.card,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: DealGoSpacing.s4),
            Text(
              l10n.drvHistGrossLine(formatVnd(gross), formatVnd(fee)),
              key: const Key('driver-history-hero-breakdown'),
              style: textTheme.bodyMedium?.copyWith(
                color: DealGoColors.card,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SplitCard extends StatelessWidget {
  const _SplitCard({
    required this.title,
    required this.amount,
    required this.meta,
  });

  final String title;
  final String amount;
  final String meta;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return DealGoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: textTheme.bodySmall),
          const SizedBox(height: DealGoSpacing.s8),
          Text(amount, style: textTheme.titleMedium),
          Text(meta, style: textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _WeekBars extends StatelessWidget {
  const _WeekBars({required this.days});

  final List<DriverDaySummary> days;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    final peak = days.fold<int>(
      0,
      (max, day) => day.earningsVnd > max ? day.earningsVnd : max,
    );
    // A visible stub for empty days keeps the axis readable.
    final values = [
      for (final day in days)
        peak == 0 ? 0.04 : (day.earningsVnd / peak).clamp(0.04, 1.0),
    ];
    final labels = [
      for (final day in days) DateFormat.E(locale).format(day.date),
    ];
    return SizedBox(
      height: 120,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var index = 0; index < values.length; index++) ...[
            if (index > 0) const SizedBox(width: DealGoSpacing.s8),
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

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.item});

  final DriverHistoryItem item;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final isRide = item.kind == DriverJobKind.ride;
    final done = item.outcome == DriverJobOutcome.completed;
    final from =
        item.pickupLabel ?? (isRide ? l10n.drvHistRides : l10n.drvHistFood);
    final meta = [
      DateFormat('dd/MM · HH:mm', locale).format(item.finishedAt),
      if (item.outcome == DriverJobOutcome.cancelled)
        l10n.drvHistOutcomeCancelled,
      if (item.outcome == DriverJobOutcome.failed) l10n.drvHistOutcomeFailed,
      if (done && item.feeVnd > 0)
        (isRide ? l10n.drvHistItemFee : l10n.drvHistItemFeeFood)(
          _percentLabel(item.feePercent ?? 0, locale),
          formatVnd(item.feeVnd),
        ),
      if (item.driverStars != null) l10n.drvHistStars(item.driverStars!),
    ].join(' · ');
    return DealGoCard(
      key: Key('driver-history-item-${item.id}'),
      onTap: () => context.push(DriverRoutes.completed(item.id), extra: item),
      child: Row(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: DealGoColors.subtlePurple,
              borderRadius: BorderRadius.circular(12),
            ),
            child: SizedBox(
              width: 44,
              height: 44,
              child: Center(
                child: isRide
                    ? DriverVehicleVisual(
                        vehicleClassCode: context
                            .select<DriverKycCubit, String?>(
                              (cubit) => cubit.state.vehicleClassCode,
                            ),
                      )
                    : const Icon(
                        DriverServiceIcons.food,
                        color: DealGoColors.primary,
                      ),
              ),
            ),
          ),
          const SizedBox(width: DealGoSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$from → ${item.dropoffLabel}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleMedium?.copyWith(fontSize: 14),
                ),
                Text(meta, style: textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: DealGoSpacing.s8),
          Text(
            done ? '+${formatVnd(item.earningsVnd)}' : formatVnd(0),
            style: textTheme.titleMedium?.copyWith(
              color: done ? DealGoColors.brandGreen : DealGoColors.textTertiary,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}

/// "12,5" (vi) / "12.5" (en): at most two decimals, no trailing zeros.
String _percentLabel(double percent, String locale) =>
    NumberFormat('#,##0.##', locale).format(percent);
