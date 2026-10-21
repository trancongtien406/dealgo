import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/components/dealgo_primary_button.dart';
import '../../../../core/design_system/icons/dealgo_icons.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/ride_models.dart';
import '../../domain/entities/ride_money.dart';
import '../../domain/entities/ride_vehicle.dart';
import '../utils/ride_routes.dart';
import '../widgets/ride_widgets.dart';
import '../../../../core/design_system/components/dealgo_app_header.dart';

/// C004 — vehicle step. Only motorbike rides are dispatched today, so the
/// single option is pre-selected and priced from the server quote.
class RideVehiclePage extends StatelessWidget {
  const RideVehiclePage({required this.places, super.key});

  final RidePlaces places;

  void _continue(BuildContext context) {
    context.push(
      RideRoutes.fareBreakdown,
      extra: RideBookingDraft(places: places),
    );
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
    final quote = places.quote;
    return Scaffold(
      backgroundColor: DealGoColors.canvas,
      body: SafeArea(
        child: Column(
          children: [
            DealGoAppHeader(
              title: l10n.rideVehicleTitle,
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
                  RidePanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: RideSectionTitle(
                                l10n.rideVehicleRouteTitle,
                              ),
                            ),
                            if (quote != null)
                              RideStatusChip(
                                label: l10n.rideDistanceKm(
                                  quote.distanceKm
                                      .toStringAsFixed(1)
                                      .replaceAll('.', ','),
                                ),
                                tone: RideChipTone.purple,
                              ),
                          ],
                        ),
                        const SizedBox(height: DealGoSpacing.s12),
                        RideStopList(
                          pickup: places.pickup.label,
                          dropoff: places.dropoff.label,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: DealGoSpacing.s16),
                  Text(
                    l10n.rideVehicleLabel,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: DealGoSpacing.s12),
                  _VehicleTile(
                    title: l10n.rideVehicleBikeTitle,
                    subtitle: l10n.rideVehicleBikeSubtitle,
                    selectedLabel: l10n.commonSelected,
                    fare: quote == null
                        ? null
                        : l10n.rideVehicleFrom(
                            formatRideVnd(quote.referenceFareVnd),
                          ),
                  ),
                  if (quote != null) ...[
                    const SizedBox(height: DealGoSpacing.s12),
                    RideInfoBanner(message: l10n.rideFareReferenceExplain),
                  ],
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
                key: const Key('ride-confirm-vehicle'),
                label: l10n.rideVehicleContinue,
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

class _VehicleTile extends StatelessWidget {
  const _VehicleTile({
    required this.title,
    required this.subtitle,
    required this.selectedLabel,
    required this.fare,
  });

  final String title;
  final String subtitle;
  final String selectedLabel;
  final String? fare;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return DecoratedBox(
      key: const Key('ride-vehicle-bike'),
      decoration: BoxDecoration(
        color: DealGoColors.subtlePurple,
        borderRadius: BorderRadius.circular(DealGoRadius.card),
        border: Border.all(color: DealGoColors.primary, width: 1.6),
      ),
      child: Padding(
        padding: const EdgeInsets.all(DealGoSpacing.s16),
        child: Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: DealGoColors.greenSurface,
                borderRadius: BorderRadius.circular(DealGoRadius.input),
              ),
              child: SizedBox(
                width: 48,
                height: 48,
                child: Image.asset(
                  'assets/images/vehicle_scooter_white.png',
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const Icon(
                    DealGoIcons.motorbike,
                    color: DealGoColors.brandGreen,
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
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleMedium,
                  ),
                  const SizedBox(height: DealGoSpacing.s4),
                  RideStatusChip(
                    label: selectedLabel,
                    tone: RideChipTone.purple,
                  ),
                  const SizedBox(height: DealGoSpacing.s4),
                  Text(subtitle, style: textTheme.bodySmall),
                ],
              ),
            ),
            if (fare != null)
              Text(
                fare!,
                style: textTheme.titleMedium?.copyWith(
                  color: DealGoColors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
