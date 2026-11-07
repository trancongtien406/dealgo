import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/design_system/components/dealgo_chip.dart';
import '../../../../core/design_system/components/dealgo_primary_button.dart';
import '../../../../core/design_system/components/dealgo_skeleton.dart';
import '../../../../core/design_system/components/dealgo_state_view.dart';
import '../../../../core/network/request_failure.dart';
import '../../../../core/design_system/icons/dealgo_icons.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../core/format/short_ref.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../driver_history/domain/driver_history.dart';
import '../../../food/domain/entities/food_money.dart';
import '../../../identity/domain/entities/auth_state.dart';
import '../../../identity/presentation/cubit/auth_cubit.dart';
import '../../../ride/presentation/widgets/ride_negotiation_ui.dart';
import '../widgets/driver_widgets.dart';

/// D034 — finished job detail from the driver's real history (fare, platform
/// fee snapshot, net earnings). [item] is passed when opened from the history
/// list; otherwise the page looks the job up in the latest history page.
class DriverJobCompletedPage extends StatefulWidget {
  const DriverJobCompletedPage({required this.jobId, this.item, super.key});

  final String jobId;
  final DriverHistoryItem? item;

  @override
  State<DriverJobCompletedPage> createState() => _DriverJobCompletedPageState();
}

class _DriverJobCompletedPageState extends State<DriverJobCompletedPage> {
  DriverHistoryItem? _item;
  var _loading = false;
  Object? _failure;

  @override
  void initState() {
    super.initState();
    _item = widget.item;
    if (_item == null) unawaited(_load());
  }

  Future<void> _load() async {
    final auth = context.read<AuthCubit>().state;
    if (auth is! AuthSignedIn) {
      setState(() {
        _loading = false;
        _failure = sessionExpiredFailure;
      });
      return;
    }
    setState(() {
      _loading = true;
      _failure = null;
    });
    try {
      final page = await context.read<DriverHistoryRepository>().list(
        accessToken: auth.tokens.accessToken,
        limit: 50,
      );
      if (!mounted) return;
      setState(() {
        _item = page.items.where((i) => i.id == widget.jobId).firstOrNull;
        _loading = false;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failure = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final item = _item;
    return DriverPageFrame(
      title: l10n.driverJobCompletedTitle,
      onBack: () => driverBack(context),
      footer: Padding(
        padding: const EdgeInsets.fromLTRB(
          DealGoDimensions.pageGutter,
          DealGoSpacing.s8,
          DealGoDimensions.pageGutter,
          DealGoSpacing.s12,
        ),
        child: DealGoPrimaryButton(
          key: const Key('driver-completed-back-jobs'),
          label: l10n.driverBackToJobs,
          fullWidth: true,
          trailingIcon: DealGoIcons.arrowRight,
          onPressed: () => context.go('/driver/jobs'),
        ),
      ),
      body: _loading
          ? const DealGoSkeletonList(itemCount: 3)
          : _failure != null && item == null
          ? DealGoStateView.failure(
              context,
              key: const Key('driver-completed-missing'),
              onRetry: _load,
              cause: _failure,
              message: l10n.errorLoadFailed,
            )
          : item == null
          ? DealGoStateView(
              key: const Key('driver-completed-missing'),
              art: DealGoStateArt.noOrders,
              title: l10n.driverCompletedNotFound,
              message: l10n.driverCompletedNotFoundHint,
              actionLabel: l10n.actionRetry,
              onAction: _load,
            )
          : _Detail(item: item),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.item});

  final DriverHistoryItem item;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final isRide = item.kind == DriverJobKind.ride;
    final done = item.outcome == DriverJobOutcome.completed;
    final from = item.pickupLabel ?? item.storeName;
    final percent = item.feePercent;
    final negotiation = maybeRideNegotiation(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        DealGoDimensions.pageGutter,
        DealGoSpacing.s8,
        DealGoDimensions.pageGutter,
        DealGoSpacing.s16,
      ),
      children: [
        DriverPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      isRide
                          ? l10n.rideRef(shortRef(item.id))
                          : l10n.orderRef(shortRef(item.id)),
                      key: const Key('driver-completed-ref'),
                      style: textTheme.titleMedium,
                    ),
                  ),
                  DealGoChip(
                    label: switch (item.outcome) {
                      DriverJobOutcome.completed => l10n.statusCompleted,
                      DriverJobOutcome.cancelled =>
                        l10n.drvHistOutcomeCancelled,
                      DriverJobOutcome.failed => l10n.drvHistOutcomeFailed,
                    },
                    tone: done ? DealGoChipTone.success : DealGoChipTone.danger,
                  ),
                ],
              ),
              const SizedBox(height: DealGoSpacing.s12),
              Text(
                from == null
                    ? item.dropoffLabel
                    : '$from → ${item.dropoffLabel}',
                style: textTheme.bodyMedium,
              ),
              const SizedBox(height: DealGoSpacing.s8),
              Text(
                DateFormat(
                  'HH:mm · dd/MM/yyyy',
                  locale,
                ).format(item.finishedAt),
                style: textTheme.bodySmall,
              ),
            ],
          ),
        ),
        const SizedBox(height: DealGoSpacing.s12),
        DriverPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.driverCompletedEarningsTitle,
                style: textTheme.titleMedium,
              ),
              const SizedBox(height: DealGoSpacing.s8),
              DriverMoneyRow(
                label: l10n.driverCompletedFareLabel,
                value: formatVnd(item.fareVnd),
              ),
              DriverMoneyRow(
                label: percent == null
                    ? l10n.driverCompletedFeeLabel
                    : (isRide
                          ? l10n.driverCompletedFeePercentLabel
                          : l10n.driverCompletedFoodFeePercentLabel)(
                        NumberFormat('#,##0.##', locale).format(percent),
                      ),
                value: formatVnd(item.feeVnd),
              ),
              DriverMoneyRow(
                label: l10n.driverCompletedNetLabel,
                value: formatVnd(item.earningsVnd),
                emphasize: true,
              ),
            ],
          ),
        ),
        // Two-way rating — the driver rates the customer.
        if (isRide && done && negotiation != null) ...[
          const SizedBox(height: DealGoSpacing.s12),
          DriverPanel(
            child: RateCustomerPanel(
              client: negotiation,
              rideId: item.id,
              accessToken: () => driverAccessToken(context) ?? '',
            ),
          ),
        ],
      ],
    );
  }
}
