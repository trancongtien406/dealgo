import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/components/dealgo_primary_button.dart';
import '../../../../core/design_system/icons/dealgo_icons.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../core/config/api_base_url.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../pricing/domain/pricing.dart';
import '../../domain/entities/ride_models.dart';
import '../../domain/entities/ride_money.dart';
import '../cubit/ride_vehicle_pref.dart';
import '../utils/ride_routes.dart';
import '../utils/ride_vehicle_label.dart';
import '../widgets/ride_widgets.dart';
import '../../../../core/design_system/components/dealgo_app_header.dart';
import '../../../../core/design_system/components/dealgo_network_image.dart';

/// C004 — customer picks a vehicle class. Each class has its own reference fare
/// and bid window; the customer still proposes the amount on the next screens.
class RideVehiclePage extends StatefulWidget {
  const RideVehiclePage({required this.places, super.key});

  final RidePlaces places;

  @override
  State<RideVehiclePage> createState() => _RideVehiclePageState();
}

class _RideVehiclePageState extends State<RideVehiclePage> {
  int _index = 0;

  List<RideQuote> get _options => widget.places.quote?.options ?? const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final pref = context.read<RideVehiclePrefCubit>().take();
      final options = _options;
      if (options.isEmpty || pref == null) {
        return;
      }
      final match = switch (pref) {
        RideVehiclePref.motorbike => options.indexWhere(
          (o) => o.vehicleClassCode == 'MOTORBIKE',
        ),
        RideVehiclePref.car => options.indexWhere(
          (o) => (o.vehicleClassCode ?? '').startsWith('CAR_'),
        ),
      };
      if (match >= 0) {
        setState(() => _index = match);
      }
    });
  }

  void _continue(BuildContext context) {
    final options = _options;
    // DG-DEC-VEH-001: do not invent a bike-only choice when quote options are empty.
    if (options.isEmpty) {
      return;
    }
    final index = _index.clamp(0, options.length - 1);
    final next = widget.places.selectClass(options[index]);
    // Skip illustrative breakdown hop — bid screen shows suggested fare.
    context.push(RideRoutes.fare, extra: next);
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
    final quote = widget.places.quote;
    final options = _options;
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
                          pickup: widget.places.pickup.label,
                          dropoff: widget.places.dropoff.label,
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
                  if (options.isEmpty)
                    RideInfoBanner(message: l10n.rideVehicleClassesUnavailable)
                  else
                    for (var i = 0; i < options.length; i++) ...[
                      if (i > 0) const SizedBox(height: DealGoSpacing.s12),
                      _VehicleTile(
                        tileKey: Key(
                          options[i].vehicleClassCode == 'MOTORBIKE'
                              ? 'ride-vehicle-bike'
                              : 'ride-vehicle-${options[i].vehicleClassCode}',
                        ),
                        title:
                            options[i].vehicleClassName ??
                            rideVehicleClassLabel(
                              l10n,
                              options[i].vehicleClassCode,
                            ),
                        subtitle: options[i].seats == null
                            ? l10n.rideVehicleBikeSubtitle
                            : l10n.rideVehicleSeats(options[i].seats!),
                        selectedLabel: l10n.commonSelected,
                        selected: _index == i,
                        icon: _iconFor(options[i].vehicleClassCode),
                        showBikeArt: options[i].vehicleClassCode == 'MOTORBIKE',
                        imageUrl: resolveMediaUrl(options[i].imageUrl),
                        fare: l10n.rideVehicleFrom(
                          formatRideVnd(options[i].referenceFareVnd),
                        ),
                        onTap: () => setState(() => _index = i),
                      ),
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
                label: l10n.rideVehicleContinueToOffer,
                trailingIcon: DealGoIcons.arrowRight,
                enabled: options.isNotEmpty,
                onPressed: () => _continue(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

IconData _iconFor(String? code) {
  return switch (code) {
    'CAR_7' => DealGoIcons.carSide,
    'CAR_4' => DealGoIcons.car,
    _ => DealGoIcons.motorbike,
  };
}

class _VehicleTile extends StatelessWidget {
  const _VehicleTile({
    required this.tileKey,
    required this.title,
    required this.subtitle,
    required this.selectedLabel,
    required this.selected,
    required this.icon,
    required this.showBikeArt,
    this.imageUrl,
    required this.fare,
    required this.onTap,
  });

  final Key tileKey;
  final String title;
  final String subtitle;
  final String selectedLabel;
  final bool selected;
  final IconData icon;
  final bool showBikeArt;
  final String? imageUrl;
  final String? fare;
  final VoidCallback onTap;

  Widget _artwork() {
    if (showBikeArt) {
      return Image.asset(
        'assets/images/vehicle_scooter_white.png',
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => Icon(icon, color: DealGoColors.brandGreen),
      );
    }
    return Icon(icon, color: DealGoColors.brandGreen);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: selected ? DealGoColors.subtlePurple : DealGoColors.card,
      borderRadius: BorderRadius.circular(DealGoRadius.card),
      child: InkWell(
        key: tileKey,
        borderRadius: BorderRadius.circular(DealGoRadius.card),
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(DealGoRadius.card),
            border: Border.all(
              color: selected ? DealGoColors.primary : DealGoColors.border,
              width: selected ? 1.6 : 1,
            ),
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
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(DealGoRadius.input),
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: imageUrl != null
                          ? DealGoNetworkImage(
                              imageUrl!,
                              fit: BoxFit.cover,
                              fallback: _artwork(),
                            )
                          : _artwork(),
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
                      if (selected) ...[
                        const SizedBox(height: DealGoSpacing.s4),
                        RideStatusChip(
                          label: selectedLabel,
                          tone: RideChipTone.purple,
                        ),
                      ],
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
        ),
      ),
    );
  }
}
