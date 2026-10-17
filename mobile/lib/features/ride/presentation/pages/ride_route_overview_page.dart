import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/components/dealgo_chip.dart';
import '../../../../core/design_system/components/dealgo_primary_button.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../core/maps/map_lat_lng.dart';
import '../../../../core/maps/map_port.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../identity/presentation/widgets/auth_widgets.dart';
import '../../domain/entities/ride_models.dart';
import '../../domain/entities/ride_money.dart';
import '../utils/ride_routes.dart';
import '../widgets/ride_widgets.dart';

/// C003 — route overview before vehicle selection (fixture ETA/distance).
class RideRouteOverviewPage extends StatelessWidget {
  const RideRouteOverviewPage({required this.places, super.key});

  final RidePlaces places;

  void _continue(BuildContext context) {
    context.push(RideRoutes.vehicle, extra: places);
  }

  void _back(BuildContext context) {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/customer/book');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: DealGoColors.canvas,
      body: SafeArea(
        child: Column(
          children: [
            RideScreenHeader(
              title: l10n.rideRouteOverviewTitle,
              onBack: () => _back(context),
              trailing: const DealGoWordmark(),
            ),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: DealGoDimensions.pageGutter,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(DealGoRadius.card),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            context.read<MapPort>().buildMap(
                              center: const MapLatLng(
                                lat: rideSamplePickupLat,
                                lng: rideSamplePickupLng,
                              ),
                              markers: const [
                                MapLatLng(
                                  lat: rideSamplePickupLat,
                                  lng: rideSamplePickupLng,
                                ),
                                MapLatLng(
                                  lat: rideSampleDropoffLat,
                                  lng: rideSampleDropoffLng,
                                ),
                              ],
                            ),
                            Align(
                              alignment: Alignment.center,
                              child: DealGoChip(
                                label: l10n.rideRouteOverviewMapBadge,
                                tone: DealGoChipTone.brand,
                                leading: const Icon(
                                  Icons.directions_car_filled,
                                  size: 14,
                                  color: DealGoColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: DealGoSpacing.s8,
                    left: DealGoDimensions.pageGutter,
                    right: DealGoDimensions.pageGutter,
                    child: RidePanel(
                      child: Row(
                        children: [
                          Expanded(
                            child: RideStopList(
                              pickup: places.pickup.label,
                              dropoff: places.dropoff.label,
                            ),
                          ),
                          IconButton(
                            tooltip: l10n.rideRouteSwapTooltip,
                            onPressed: () {},
                            icon: const Icon(
                              Icons.swap_vert,
                              color: DealGoColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            DecoratedBox(
              decoration: const BoxDecoration(
                color: DealGoColors.card,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(DealGoRadius.card),
                ),
                border: Border(top: BorderSide(color: DealGoColors.border)),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  DealGoDimensions.pageGutter,
                  DealGoSpacing.s16,
                  DealGoDimensions.pageGutter,
                  DealGoSpacing.s16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: DealGoColors.border,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: DealGoSpacing.s12),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.rideRouteOverviewTitle,
                                style: textTheme.titleLarge,
                              ),
                              Text(
                                l10n.rideRouteOverviewSubtitle,
                                style: textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        DealGoChip(
                          label: l10n.rideRouteInService,
                          tone: DealGoChipTone.success,
                          leading: const Icon(
                            Icons.check_circle,
                            size: 14,
                            color: DealGoColors.brandGreen,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: DealGoSpacing.s12),
                    Row(
                      children: [
                        Expanded(
                          child: _StatTile(
                            label: l10n.rideRouteDistance,
                            value: l10n.rideRouteDistanceSample,
                          ),
                        ),
                        const SizedBox(width: DealGoSpacing.s8),
                        Expanded(
                          child: _StatTile(
                            label: l10n.rideRouteDuration,
                            value: l10n.rideRouteDurationSample,
                          ),
                        ),
                        const SizedBox(width: DealGoSpacing.s8),
                        Expanded(
                          child: _StatTile(
                            label: l10n.rideRouteRefPrice,
                            value: formatRideVnd(rideDefaultOfferVnd),
                            emphasize: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: DealGoSpacing.s12),
                    Text(l10n.rideRoutePriceHint, style: textTheme.bodySmall),
                    const SizedBox(height: DealGoSpacing.s16),
                    DealGoPrimaryButton(
                      key: const Key('ride-open-vehicle'),
                      label: l10n.rideRouteContinueVehicle,
                      trailingIcon: Icons.arrow_forward,
                      onPressed: () => _continue(context),
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

class _StatTile extends StatelessWidget {
  const _StatTile({
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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: DealGoColors.canvas,
        borderRadius: BorderRadius.circular(DealGoRadius.input),
      ),
      child: Padding(
        padding: const EdgeInsets.all(DealGoSpacing.s12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: textTheme.labelSmall),
            const SizedBox(height: DealGoSpacing.s4),
            Text(
              value,
              style: textTheme.titleSmall?.copyWith(
                color: emphasize ? DealGoColors.primary : DealGoColors.text,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
