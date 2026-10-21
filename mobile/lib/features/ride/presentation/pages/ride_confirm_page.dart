import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/components/dealgo_primary_button.dart';
import '../../../../core/design_system/components/dealgo_secondary_button.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../domain/entities/ride_money.dart';
import '../../domain/entities/ride_models.dart';
import '../widgets/ride_widgets.dart';
import '../../../../core/design_system/icons/dealgo_icons.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../core/design_system/components/dealgo_app_header.dart';

class RideConfirmPage extends StatefulWidget {
  const RideConfirmPage({required this.args, super.key});

  final RideConfirmArgs args;

  @override
  State<RideConfirmPage> createState() => _RideConfirmPageState();
}

class _RideConfirmPageState extends State<RideConfirmPage> {
  var _acknowledged = false;

  RideView get _ride => widget.args.ride;

  bool get _fareChanged {
    final agreed = _ride.agreedFareVnd;
    if (agreed == null) {
      return false;
    }
    return agreed != widget.args.tappedAmountVnd;
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/customer');
  }

  @override
  Widget build(BuildContext context) {
    final agreed = _ride.agreedFareVnd;
    if (agreed == null) {
      return Scaffold(
        backgroundColor: DealGoColors.canvas,
        body: SafeArea(
          child: Column(
            children: [
              DealGoAppHeader(title: AppLocalizations.of(context).rideConfirmTitle, onBack: _back),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(DealGoDimensions.pageGutter),
                  child: Text(
                    AppLocalizations.of(context).rideConfirmNoAgreed,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (_fareChanged && !_acknowledged) {
      return _FareChanged(
        ride: _ride,
        tappedAmountVnd: widget.args.tappedAmountVnd,
        agreedFareVnd: agreed,
        onBack: _back,
        onAccept: () => setState(() => _acknowledged = true),
      );
    }
    return _Confirmed(ride: _ride, agreedFareVnd: agreed, onBack: _back);
  }
}

class _FareChanged extends StatelessWidget {
  const _FareChanged({
    required this.ride,
    required this.tappedAmountVnd,
    required this.agreedFareVnd,
    required this.onBack,
    required this.onAccept,
  });

  final RideView ride;
  final int tappedAmountVnd;
  final int agreedFareVnd;
  final VoidCallback onBack;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    final delta = agreedFareVnd - tappedAmountVnd;
    return Scaffold(
      backgroundColor: DealGoColors.canvas,
      body: SafeArea(
        child: Column(
          children: [
            DealGoAppHeader(title: AppLocalizations.of(context).rideConfirmNewPrice, onBack: onBack),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  DealGoDimensions.pageGutter,
                  DealGoSpacing.s8,
                  DealGoDimensions.pageGutter,
                  DealGoSpacing.s16,
                ),
                children: [
                  RideStateHero(
                    icon: DealGoIcons.alert,
                    iconColor: DealGoColors.warning,
                    background: DealGoColors.amberSurface,
                    title: AppLocalizations.of(context).rideFareChangedTitle,
                    message: AppLocalizations.of(context).rideFareChangedMessage,
                  ),
                  const SizedBox(height: DealGoSpacing.s16),
                  RidePanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RideSectionTitle(AppLocalizations.of(context).rideCurrentRoute),
                        const SizedBox(height: DealGoSpacing.s12),
                        RideStopList(
                          pickup: ride.pickup.label,
                          dropoff: ride.dropoff.label,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: DealGoSpacing.s12),
                  RidePanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RideSectionTitle(AppLocalizations.of(context).rideCompareFares),
                        const SizedBox(height: DealGoSpacing.s8),
                        RideMoneyLine(
                          label: AppLocalizations.of(context).rideFareYouPicked,
                          amount: formatRideVnd(tappedAmountVnd),
                        ),
                        RideMoneyLine(
                          label: AppLocalizations.of(context).rideAgreedFare,
                          amount: formatRideVnd(agreedFareVnd),
                        ),
                        RideMoneyLine(
                          label: AppLocalizations.of(context).rideFareDifference,
                          amount: formatRideVndDelta(delta),
                          emphasize: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: DealGoSpacing.s12),
                  RideNote(
                    message: AppLocalizations.of(context).rideFareChangedNote,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                DealGoDimensions.pageGutter,
                DealGoSpacing.s8,
                DealGoDimensions.pageGutter,
                DealGoSpacing.s12,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: DealGoSecondaryButton(
                      label: AppLocalizations.of(context).actionBack,
                      onPressed: onBack,
                    ),
                  ),
                  const SizedBox(width: DealGoSpacing.s12),
                  Expanded(
                    child: DealGoPrimaryButton(
                      key: const Key('ride-ack-fare'),
                      label: AppLocalizations.of(context).rideAcceptAmount(formatRideVnd(agreedFareVnd)),
                      onPressed: onAccept,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Confirmed extends StatelessWidget {
  const _Confirmed({
    required this.ride,
    required this.agreedFareVnd,
    required this.onBack,
  });

  final RideView ride;
  final int agreedFareVnd;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final driver = ride.assignedDriverId ?? AppLocalizations.of(context).kycRoleBadge;
    final initial = driver.isEmpty ? '?' : driver.substring(0, 1).toUpperCase();
    return Scaffold(
      backgroundColor: DealGoColors.canvas,
      body: SafeArea(
        child: Column(
          children: [
            DealGoAppHeader(title: AppLocalizations.of(context).rideConfirmTitle, onBack: onBack),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  DealGoDimensions.pageGutter,
                  DealGoSpacing.s8,
                  DealGoDimensions.pageGutter,
                  DealGoSpacing.s16,
                ),
                children: [
                  RidePanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RideSectionTitle(AppLocalizations.of(context).rideChosenRoute),
                        const SizedBox(height: DealGoSpacing.s12),
                        RideStopList(
                          pickup: ride.pickup.label,
                          dropoff: ride.dropoff.label,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: DealGoSpacing.s12),
                  RidePanel(
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: DealGoColors.subtlePurple,
                          child: Text(
                            initial,
                            style: const TextStyle(
                              color: DealGoColors.primary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: DealGoSpacing.s12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                driver,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Text(AppLocalizations.of(context).rideVehicleMotorbike),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: DealGoSpacing.s12),
                  RidePanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RideSectionTitle(AppLocalizations.of(context).rideOfferAgreed),
                        const SizedBox(height: DealGoSpacing.s8),
                        RideStatusChip(
                          label: AppLocalizations.of(context).rideStillValid,
                          tone: RideChipTone.green,
                        ),
                        const SizedBox(height: DealGoSpacing.s8),
                        RideMoneyLine(
                          label: AppLocalizations.of(context).rideFare,
                          amount: formatRideVnd(agreedFareVnd),
                        ),
                        if (ride.discountVnd > 0)
                          RideMoneyLine(
                            label: AppLocalizations.of(context)
                                .rideVoucherLine(ride.voucherCode ?? ''),
                            amount: formatRideVnd(-ride.discountVnd),
                          ),
                        RideMoneyLine(
                          key: const Key('ride-agreed-fare'),
                          label: AppLocalizations.of(context).rideCustomerPays,
                          amount: formatRideVnd(
                            rideCashAfterVoucher(agreedFareVnd, ride.discountVnd),
                          ),
                          emphasize: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: DealGoSpacing.s12),
                  RidePanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RideSectionTitle(AppLocalizations.of(context).ridePaymentMethod),
                        const SizedBox(height: DealGoSpacing.s8),
                        Row(
                          children: [
                            const Icon(
                              DealGoIcons.cash,
                              color: DealGoColors.brandGreen,
                            ),
                            const SizedBox(width: DealGoSpacing.s8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    AppLocalizations.of(context).paymentHistoryCash,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(AppLocalizations.of(context).rideCashNote),
                                ],
                              ),
                            ),
                            RideStatusChip(
                              label: AppLocalizations.of(context).commonSelected,
                              tone: RideChipTone.green,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: DealGoSpacing.s12),
                  RideNote(
                    message: AppLocalizations.of(context).rideConfirmPriceNote,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                DealGoDimensions.pageGutter,
                DealGoSpacing.s8,
                DealGoDimensions.pageGutter,
                DealGoSpacing.s12,
              ),
              child: DealGoPrimaryButton(
                label: AppLocalizations.of(context).rideRecordedAmount(
                  formatRideVnd(rideCashAfterVoucher(agreedFareVnd, ride.discountVnd)),
                ),
                onPressed: onBack,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
