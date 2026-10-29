import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/api_base_url.dart';
import '../../../../core/design_system/components/dealgo_primary_button.dart';
import '../../../../core/design_system/components/dealgo_success_mark.dart';
import '../../../../core/design_system/components/dealgo_secondary_button.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../domain/entities/ride_money.dart';
import '../../domain/entities/ride_models.dart';
import '../utils/ride_vehicle_label.dart';
import '../widgets/ride_widgets.dart';
import '../../../../core/design_system/icons/dealgo_icons.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../core/design_system/components/dealgo_app_header.dart';
import '../../../payment/domain/payment_models.dart';
import '../../../payment/presentation/payment_method_sheet.dart';
import '../../../payment/presentation/payment_status_page.dart';

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
              DealGoAppHeader(
                title: AppLocalizations.of(context).rideConfirmTitle,
                onBack: _back,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(DealGoDimensions.pageGutter),
                  child: Text(AppLocalizations.of(context).rideConfirmNoAgreed),
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
            DealGoAppHeader(
              title: AppLocalizations.of(context).rideConfirmNewPrice,
              onBack: onBack,
            ),
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
                    message: AppLocalizations.of(context)
                        .rideFareChangedMessage,
                  ),
                  const SizedBox(height: DealGoSpacing.s16),
                  RidePanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RideSectionTitle(
                          AppLocalizations.of(context).rideCurrentRoute,
                        ),
                        const SizedBox(height: DealGoSpacing.s12),
                        RideStopList(
                          pickup: ride.pickup.label,
                          dropoff: ride.dropoff.label,
                          stops: [for (final s in ride.stops) s.point.label],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: DealGoSpacing.s12),
                  RidePanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RideSectionTitle(
                          AppLocalizations.of(context).rideCompareFares,
                        ),
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
                          label: AppLocalizations.of(context)
                              .rideFareDifference,
                          amount: formatRideVndDelta(delta),
                          emphasize: true,
                        ),
                      ],
                    ),
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
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
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
                        label: AppLocalizations.of(context)
                            .rideAcceptAmount(formatRideVnd(agreedFareVnd)),
                        onPressed: onAccept,
                      ),
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

class _ConfirmedVehicle extends StatelessWidget {
  const _ConfirmedVehicle({required this.code, this.imageUrl});

  final String? code;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final photo = resolveMediaUrl(imageUrl);
    return Row(
      children: [
        if (photo == null)
          Icon(
            rideVehicleClassIcon(code),
            size: 16,
            color: DealGoColors.textSecondary,
          )
        else
          RideVehicleClassPhoto(imageUrl: imageUrl, code: code, size: 20),
        const SizedBox(width: DealGoSpacing.s8),
        Expanded(
          child: Text(
            rideVehicleClassLabel(AppLocalizations.of(context), code),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
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
    // RideView carries no driver display name; never surface the raw driver
    // UUID to the customer — show the localized role label instead.
    final driver = AppLocalizations.of(context).kycRoleBadge;
    final initial = driver.isEmpty ? '?' : driver.substring(0, 1).toUpperCase();
    return Scaffold(
      backgroundColor: DealGoColors.canvas,
      body: SafeArea(
        child: Column(
          children: [
            DealGoAppHeader(
              title: AppLocalizations.of(context).rideConfirmTitle,
              onBack: onBack,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  DealGoDimensions.pageGutter,
                  DealGoSpacing.s8,
                  DealGoDimensions.pageGutter,
                  DealGoSpacing.s16,
                ),
                children: [
                  const Center(
                    child: DealGoSuccessMark(size: 64, iconSize: 32),
                  ),
                  const SizedBox(height: DealGoSpacing.s16),
                  RidePanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RideSectionTitle(
                          AppLocalizations.of(context).rideChosenRoute,
                        ),
                        const SizedBox(height: DealGoSpacing.s12),
                        RideStopList(
                          pickup: ride.pickup.label,
                          dropoff: ride.dropoff.label,
                          stops: [for (final s in ride.stops) s.point.label],
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
                              _ConfirmedVehicle(
                                code: ride.vehicleClassCode,
                                imageUrl: ride.imageUrl,
                              ),
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
                        RideSectionTitle(
                          AppLocalizations.of(context).rideOfferAgreed,
                        ),
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
                            rideCashAfterVoucher(
                              agreedFareVnd,
                              ride.discountVnd,
                            ),
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
                        RideSectionTitle(
                          AppLocalizations.of(context).ridePaymentMethod,
                        ),
                        const SizedBox(height: DealGoSpacing.s8),
                        RidePaymentSection(ride: ride),
                      ],
                    ),
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
                  formatRideVnd(
                    rideCashAfterVoucher(agreedFareVnd, ride.discountVnd),
                  ),
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

/// Payment choice on the confirmed ride. CASH needs nothing more; an online
/// method is started server-side (amount = cash due) and tracked on
/// [PaymentStatusPage].
class RidePaymentSection extends StatefulWidget {
  const RidePaymentSection({required this.ride, super.key});

  final RideView ride;

  @override
  State<RidePaymentSection> createState() => _RidePaymentSectionState();
}

class _RidePaymentSectionState extends State<RidePaymentSection> {
  PaymentMethodOption _method = PaymentMethodOption.cash;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PaymentMethodTile(
          service: paymentServiceForVehicleClass(widget.ride.vehicleClassCode),
          selected: _method.code,
          onChanged: (m) => setState(() => _method = m),
        ),
        if (_method.isCash)
          Padding(
            padding: const EdgeInsets.only(top: DealGoSpacing.s4),
            child: Text(AppLocalizations.of(context).rideCashNote),
          )
        else ...[
          const SizedBox(height: DealGoSpacing.s12),
          DealGoPrimaryButton(
            key: const Key('ride-pay-online'),
            label: 'Thanh toán qua ${_method.label}',
            onPressed: () => context.push(
              PaymentRoutes.location(
                entityType: 'RIDE',
                entityId: widget.ride.id,
                startMethod: _method.code,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
