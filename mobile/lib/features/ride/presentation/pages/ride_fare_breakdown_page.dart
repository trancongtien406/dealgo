import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/components/dealgo_banner.dart';
import '../../../../core/design_system/components/dealgo_chip.dart';
import '../../../../core/design_system/components/dealgo_primary_button.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/ride_money.dart';
import '../../domain/entities/ride_vehicle.dart';
import '../utils/ride_routes.dart';
import '../widgets/ride_widgets.dart';

/// C005 — illustrative fare components before customer proposes a bid (C006).
class RideFareBreakdownPage extends StatelessWidget {
  const RideFareBreakdownPage({required this.draft, super.key});

  final RideBookingDraft draft;

  void _continue(BuildContext context) {
    context.push(RideRoutes.fare, extra: draft);
  }

  void _back(BuildContext context) {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/customer');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final total = draft.suggestedFareVnd;
    // Fixture split matching C005 mock — not an OPEN fee policy.
    final base = (total * 0.6).round();
    final distance = total - base;
    return Scaffold(
      backgroundColor: DealGoColors.canvas,
      body: SafeArea(
        child: Column(
          children: [
            RideScreenHeader(
              title: l10n.rideFareBreakdownTitle,
              onBack: () => _back(context),
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
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: DealGoColors.subtlePurple,
                      borderRadius: BorderRadius.circular(DealGoRadius.card),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(DealGoSpacing.s16),
                      child: Row(
                        children: [
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: DealGoColors.card,
                              borderRadius: BorderRadius.circular(
                                DealGoRadius.input,
                              ),
                            ),
                            child: const SizedBox(
                              width: 56,
                              height: 56,
                              child: Icon(
                                Icons.directions_car_filled,
                                color: DealGoColors.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: DealGoSpacing.s12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${draft.vehicleLabel} · Toyota Vios',
                                  style: textTheme.titleMedium,
                                ),
                                const SizedBox(height: DealGoSpacing.s8),
                                Text(
                                  l10n.rideFareEstimatedFee,
                                  style: textTheme.bodySmall,
                                ),
                                Text(
                                  formatRideVnd(total),
                                  style: textTheme.headlineSmall?.copyWith(
                                    color: DealGoColors.primary,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: DealGoSpacing.s8),
                                DealGoChip(
                                  label: l10n.rideFareVersionChip,
                                  tone: DealGoChipTone.success,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: DealGoSpacing.s12),
                  RidePanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RideSectionTitle(l10n.rideFareComponentsTitle),
                        const SizedBox(height: DealGoSpacing.s12),
                        RideMoneyLine(
                          label: l10n.rideFareBase,
                          amount: formatRideVnd(base),
                        ),
                        RideMoneyLine(
                          label: l10n.rideFareDistance,
                          amount: formatRideVnd(distance),
                        ),
                        RideMoneyLine(
                          label: l10n.rideFareSurcharge,
                          amount: formatRideVnd(0),
                        ),
                        RideMoneyLine(
                          label: l10n.rideFareDiscount,
                          amount: formatRideVnd(0),
                        ),
                        const Divider(height: DealGoSpacing.s24),
                        RideMoneyLine(
                          label: l10n.rideFareProposedTotal,
                          amount: formatRideVnd(total),
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
                        RideSectionTitle(l10n.rideFareTripInfoTitle),
                        const SizedBox(height: DealGoSpacing.s12),
                        RideStopList(
                          pickup: draft.places.pickup.label,
                          dropoff: draft.places.dropoff.label,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: DealGoSpacing.s12),
                  DealGoBanner(
                    tone: DealGoBannerTone.warning,
                    message: l10n.rideFareBreakdownNote,
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
                key: const Key('ride-open-fare-bid'),
                label: l10n.rideFareProposeCta,
                trailingIcon: Icons.arrow_forward,
                onPressed: () => _continue(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
