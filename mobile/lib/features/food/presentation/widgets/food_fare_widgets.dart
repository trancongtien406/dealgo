import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design_system/icons/dealgo_icons.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../core/motion/dealgo_sheet.dart';
import '../../../../core/design_system/tokens/dealgo_type_scale.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../pricing/domain/pricing.dart';
import '../../data/food_fare_negotiation.dart';
import '../../domain/entities/food_money.dart';
import '../cubit/food_cart_cubit.dart';
import 'food_widgets.dart';

FoodFareClient? maybeFoodFareClient(BuildContext context) {
  try {
    return context.read<FoodFareClient>();
  } on ProviderNotFoundException {
    return null;
  }
}

/// Checkout: suggested fee + the customer's offer stepper (server fareStep),
/// or the read-only fixed fee when the server runs `FIXED` fee mode.
class FoodFareOfferPanel extends StatelessWidget {
  const FoodFareOfferPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cart = context.watch<FoodCartCubit>().state;
    final quote = cart.deliveryQuote;
    final offer = cart.offeredDeliveryFareVnd;
    if (quote == null || offer == null) {
      return const SizedBox.shrink();
    }
    final textTheme = Theme.of(context).textTheme;
    if (quote.feeMode == FoodDeliveryFeeMode.fixed || !quote.negotiable) {
      return FoodPanel(
        key: const Key('food-fare-fixed-panel'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.foodFareNegotiationTitle, style: textTheme.titleMedium),
            const SizedBox(height: DealGoSpacing.s4),
            FoodMoneyRow(
              label: l10n.foodFareFixedLabel,
              amount: formatVnd(quote.suggestedVnd),
            ),
            const SizedBox(height: DealGoSpacing.s8),
            Text(
              l10n.foodFareFixedHint,
              style: DealGoType.meta(textTheme)
                  .copyWith(color: DealGoColors.textSecondary),
            ),
          ],
        ),
      );
    }
    final cubit = context.read<FoodCartCubit>();
    return FoodPanel(
      key: const Key('food-fare-offer-panel'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.foodFareNegotiationTitle, style: textTheme.titleMedium),
          const SizedBox(height: DealGoSpacing.s4),
          FoodMoneyRow(
            label: l10n.foodFareSuggested,
            amount: formatVnd(quote.suggestedVnd),
          ),
          const SizedBox(height: DealGoSpacing.s8),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: DealGoSpacing.s8,
              vertical: DealGoSpacing.s4,
            ),
            decoration: BoxDecoration(
              color: DealGoColors.subtlePurple,
              borderRadius: BorderRadius.circular(DealGoRadius.input),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.foodFareYourOffer,
                    style: textTheme.titleSmall,
                  ),
                ),
                _StepButton(
                  buttonKey: const Key('food-fare-decrease'),
                  icon: DealGoIcons.removeCircle,
                  tooltip: l10n.foodFareDecrease,
                  onPressed: offer > quote.minOfferVnd
                      ? () => cubit.stepDeliveryOffer(-1)
                      : null,
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 84),
                  child: Text(
                    formatVnd(offer),
                    key: const Key('food-fare-offer-amount'),
                    textAlign: TextAlign.center,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: DealGoColors.primary,
                    ),
                  ),
                ),
                _StepButton(
                  buttonKey: const Key('food-fare-increase'),
                  icon: DealGoIcons.addCircle,
                  tooltip: l10n.foodFareIncrease,
                  onPressed: offer < quote.maxOfferVnd
                      ? () => cubit.stepDeliveryOffer(1)
                      : null,
                ),
              ],
            ),
          ),
          if (offer != quote.suggestedVnd)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const Key('food-fare-reset'),
                onPressed: cubit.resetDeliveryOffer,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, DealGoDimensions.minTapTarget),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(l10n.foodFareReset),
              ),
            ),
          const SizedBox(height: DealGoSpacing.s4),
          Text(
            l10n.foodFareNegotiationHint,
            key: const Key('food-fare-negotiation-hint'),
            style: DealGoType.meta(textTheme)
                .copyWith(color: DealGoColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.buttonKey,
    required this.icon,
    required this.tooltip,
    this.onPressed,
  });

  final Key buttonKey;
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: buttonKey,
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(
        icon,
        color: onPressed == null
            ? DealGoColors.textTertiary
            : DealGoColors.primary,
      ),
    );
  }
}

/// Tracking screen while no driver is assigned: the customer's offer, driver
/// counters (choose one) and a one-step raise. Polls every few seconds.
class FoodFareNegotiationCard extends StatefulWidget {
  const FoodFareNegotiationCard({
    required this.orderId,
    required this.accessToken,
    this.client,
    this.onAgreed,
    this.pollInterval = const Duration(seconds: 5),
    super.key,
  });

  final String orderId;
  final String Function() accessToken;
  final FoodFareClient? client;
  final VoidCallback? onAgreed;
  final Duration pollInterval;

  @override
  State<FoodFareNegotiationCard> createState() =>
      _FoodFareNegotiationCardState();
}

class _FoodFareNegotiationCardState extends State<FoodFareNegotiationCard> {
  FoodFareCubit? _cubit;
  Timer? _timer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_cubit != null) return;
    final client = widget.client ?? maybeFoodFareClient(context);
    if (client == null) return;
    _cubit = FoodFareCubit(
      client: client,
      orderId: widget.orderId,
      accessToken: widget.accessToken,
    )..refresh();
    _timer = Timer.periodic(widget.pollInterval, (_) => _cubit?.refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _cubit?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = _cubit;
    if (cubit == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    return BlocConsumer<FoodFareCubit, FoodFareState>(
      bloc: cubit,
      listenWhen: (a, b) =>
          b.error != null && a.error != b.error ||
          (a.offers?.agreed != true && b.offers?.agreed == true),
      listener: (context, state) {
        if (state.offers?.agreed == true) {
          _timer?.cancel();
          widget.onAgreed?.call();
          return;
        }
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text(
              state.error == 'RAISE_FAILED'
                  ? l10n.foodFareRaiseFailed
                  : l10n.foodFareSelectFailed,
            ),
          ),
        );
      },
      builder: (context, state) {
        final offers = state.offers;
        if (offers == null) return const SizedBox.shrink();
        final textTheme = Theme.of(context).textTheme;
        if (offers.agreed) {
          return FoodPanel(
            key: const Key('food-fare-agreed'),
            child: Text(
              l10n.foodFareAgreed(formatVnd(offers.deliveryFareVnd)),
              style: textTheme.titleSmall,
            ),
          );
        }
        final pending = offers.pendingOffers;
        final next = offers.nextRaiseVnd;
        return FoodPanel(
          key: const Key('food-fare-negotiation'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.foodFareNegotiationTitle, style: textTheme.titleMedium),
              const SizedBox(height: DealGoSpacing.s4),
              Text(
                l10n.foodFareWaiting(formatVnd(offers.deliveryFareVnd)),
                key: const Key('food-fare-waiting'),
              ),
              FoodMoneyRow(
                label: l10n.foodFareSuggested,
                amount: formatVnd(offers.suggestedDeliveryFareVnd),
              ),
              const Divider(height: 20),
              if (!offers.driversCanCounter)
                Text(
                  l10n.foodFareFixedWaiting,
                  key: const Key('food-fare-fixed-note'),
                  style: textTheme.bodySmall?.copyWith(
                    color: DealGoColors.textSecondary,
                  ),
                )
              else if (pending.isEmpty)
                Text(
                  l10n.foodFareOffersEmpty,
                  style: textTheme.bodySmall?.copyWith(
                    color: DealGoColors.textSecondary,
                  ),
                )
              else
                for (final o in pending)
                  Padding(
                    padding: const EdgeInsets.only(bottom: DealGoSpacing.s8),
                    child: Row(
                      key: Key('food-fare-offer-${o.id}'),
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(o.driverName ?? l10n.foodFareDriverOffer),
                              Text(
                                formatVnd(o.amountVnd),
                                style: textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        FilledButton(
                          key: Key('food-fare-select-${o.id}'),
                          onPressed: state.loading
                              ? null
                              : () => cubit.select(o.id),
                          child: Text(l10n.foodFareSelect),
                        ),
                      ],
                    ),
                  ),
              if (next != null) ...[
                const SizedBox(height: DealGoSpacing.s8),
                OutlinedButton(
                  key: const Key('food-fare-raise'),
                  onPressed: state.loading ? null : cubit.raise,
                  child: Text(l10n.foodFareRaise(formatVnd(next))),
                ),
                Text(
                  l10n.foodFareRaisesLeft(offers.raisesLeft),
                  style: textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: DealGoSpacing.s4),
              Text(
                l10n.foodFareCodExtra,
                style: textTheme.bodySmall?.copyWith(
                  color: DealGoColors.textSecondary,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Driver feed: propose another fee (bounded by the customer's offer ×
/// counterMax%, steps of fareStep). Returns true when sent.
Future<bool> showDriverFareCounterSheet(
  BuildContext context, {
  required String orderId,
  required int customerOfferVnd,
  required String accessToken,
  FoodFareClient? client,
}) async {
  final fare = client ?? maybeFoodFareClient(context);
  if (fare == null) return false;
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.maybeOf(context);
  FoodDeliveryOffers? bounds;
  try {
    bounds = await fare.list(accessToken: accessToken, orderId: orderId);
  } on ApiException {
    bounds = null;
  }
  if (!context.mounted) return false;
  if (bounds != null && !bounds.driversCanCounter) {
    messenger?.showSnackBar(SnackBar(content: Text(l10n.driverFareFixed)));
    return false;
  }
  final rawStep = bounds?.fareStepVnd ?? 1000;
  final step = rawStep < 1 ? 1000 : rawStep;
  final max = bounds?.counterMaxVnd ?? customerOfferVnd;
  // The customer's offer may predate fare-step rounding; the server rejects
  // counters that are not on the step grid, so start at the next whole step.
  final min = ((customerOfferVnd ~/ step) + 1) * step;
  if (max < min) return false;
  final amount = await showDealGoSheet<int>(
    context: context,
    builder: (sheetContext) {
      var value = min;
      return StatefulBuilder(
        builder: (context, setState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(DealGoSpacing.s16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.driverFareCounterTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(l10n.driverFareCustomerOffer(formatVnd(customerOfferVnd))),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      key: const Key('driver-fare-decrease'),
                      onPressed: value - step >= min
                          ? () => setState(() => value -= step)
                          : null,
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    Text(
                      formatVnd(value),
                      key: const Key('driver-fare-amount'),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    IconButton(
                      key: const Key('driver-fare-increase'),
                      onPressed: value + step <= max
                          ? () => setState(() => value += step)
                          : null,
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                  ],
                ),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    key: const Key('driver-fare-send'),
                    onPressed: () => Navigator.of(sheetContext).pop(value),
                    child: Text(l10n.driverFareCounterSend(formatVnd(value))),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
  if (amount == null) return false;
  try {
    await fare.counter(
      accessToken: accessToken,
      orderId: orderId,
      amountVnd: amount,
    );
    messenger?.showSnackBar(
      SnackBar(content: Text(l10n.driverFareCounterSent)),
    );
    return true;
  } on ApiException catch (e) {
    messenger?.showSnackBar(
      SnackBar(
        content: Text(
          e.errorCode == 'FOOD_FEE_NEGOTIATION_DISABLED'
              ? l10n.driverFareFixed
              : l10n.driverFareCounterFailed,
        ),
      ),
    );
    return false;
  }
}

/// Driver job card: "Đề xuất giá khác" — hidden when the admin fee mode is
/// FIXED (drivers can only accept the customer's price) or no client exists.
class DriverFareCounterButton extends StatefulWidget {
  const DriverFareCounterButton({
    super.key,
    required this.orderId,
    required this.customerOfferVnd,
    required this.accessToken,
    this.enabled = true,
    this.client,
  });

  final String orderId;
  final int customerOfferVnd;
  final String accessToken;
  final bool enabled;
  final FoodFareClient? client;

  @override
  State<DriverFareCounterButton> createState() =>
      _DriverFareCounterButtonState();
}

class _DriverFareCounterButtonState extends State<DriverFareCounterButton> {
  FoodFareClient? _client;
  bool _canCounter = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_client != null) return;
    _client = widget.client ?? maybeFoodFareClient(context);
    unawaited(_loadMode());
  }

  Future<void> _loadMode() async {
    final client = _client;
    if (client == null) return;
    try {
      final offers = await client.list(
        accessToken: widget.accessToken,
        orderId: widget.orderId,
      );
      if (mounted) setState(() => _canCounter = offers.driversCanCounter);
    } on ApiException {
      // Keep the button; the server still rejects counters in FIXED mode.
    }
  }

  @override
  Widget build(BuildContext context) {
    final client = _client;
    if (client == null || !_canCounter) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton.icon(
        key: const Key('driver-fare-counter'),
        onPressed: widget.enabled
            ? () => showDriverFareCounterSheet(
                context,
                orderId: widget.orderId,
                customerOfferVnd: widget.customerOfferVnd,
                accessToken: widget.accessToken,
                client: client,
              )
            : null,
        icon: const Icon(Icons.price_change_outlined),
        label: Text(l10n.driverFareCounter),
      ),
    );
  }
}
