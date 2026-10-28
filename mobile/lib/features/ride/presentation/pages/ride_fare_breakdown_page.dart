import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/components/dealgo_primary_button.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/ride_money.dart';
import '../../domain/entities/ride_vehicle.dart';
import '../utils/ride_vehicle_label.dart';
import '../utils/ride_routes.dart';
import '../widgets/ride_widgets.dart';
import 'ride_route_overview_page.dart';
import '../../../../core/design_system/icons/dealgo_icons.dart';
import '../../../../core/design_system/components/dealgo_app_header.dart';

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
    final quote = draft.places.quote;
    if (quote == null) {
      // Opened without a quote (deep link): price the route first.
      return RideRouteOverviewPage(places: draft.places);
    }
    final total = quote.referenceFareVnd;
    return Scaffold(
      backgroundColor: DealGoColors.canvas,
      body: SafeArea(
        child: Column(
          children: [
            DealGoAppHeader(
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
                            child: SizedBox(
                              width: 56,
                              height: 56,
                              child: Icon(
                                rideVehicleClassIcon(quote.vehicleClassCode),
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
                                  quote.vehicleClassName ??
                                      rideVehicleClassLabel(
                                        l10n,
                                        quote.vehicleClassCode,
                                      ),
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
                        if (quote.baseFareVnd > 0)
                          RideMoneyLine(
                            label: l10n.rideFareOpening,
                            amount: formatRideVnd(quote.baseFareVnd),
                          ),
                        if (quote.perKmVnd > 0)
                          RideMoneyLine(
                            label: l10n.rideFarePerKm,
                            amount: formatRideVnd(quote.perKmVnd),
                          ),
                        if (quote.perMinuteVnd > 0 && quote.durationMin > 0)
                          RideMoneyLine(
                            label: l10n.rideFareTime(quote.durationMin),
                            amount: formatRideVnd(
                              quote.perMinuteVnd * quote.durationMin,
                            ),
                          ),
                        RideMoneyLine(
                          label: l10n.rideRouteDistance,
                          amount: l10n.rideDistanceKm(
                            quote.distanceKm
                                .toStringAsFixed(1)
                                .replaceAll('.', ','),
                          ),
                        ),
                        RideMoneyLine(
                          label: l10n.rideFareAllowedRange,
                          amount:
                              '${formatRideVnd(quote.minFareVnd)} – ${formatRideVnd(quote.maxFareVnd)}',
                        ),
                        const Divider(height: DealGoSpacing.s24),
                        RideMoneyLine(
                          key: const Key('ride-breakdown-reference'),
                          label: l10n.rideRouteRefPrice,
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
                          stops: [for (final s in draft.places.stops) s.label],
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
              child: DealGoPrimaryButton(
                key: const Key('ride-open-fare-bid'),
                label: l10n.rideFareProposeCta,
                trailingIcon: DealGoIcons.arrowRight,
                onPressed: () => _continue(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
