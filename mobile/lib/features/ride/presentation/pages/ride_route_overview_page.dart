import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/components/dealgo_banner.dart';
import '../../../../core/design_system/components/dealgo_chip.dart';
import '../../../../core/design_system/components/dealgo_primary_button.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../core/maps/map_lat_lng.dart';
import '../../../../core/maps/map_port.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../pricing/domain/pricing.dart';
import '../../domain/entities/ride_models.dart';
import '../../domain/entities/ride_money.dart';
import '../utils/ride_quote_error.dart';
import '../utils/ride_routes.dart';
import '../utils/ride_vehicle_label.dart';
import '../widgets/ride_widgets.dart';
import '../../../../core/design_system/icons/dealgo_icons.dart';
import '../../../../core/design_system/components/dealgo_app_header.dart';
import '../../../../core/maps/route_geometry.dart';
import '../../../../core/smoke/ride_smoke_flags.dart';

/// C003 — route overview before vehicle selection, priced by the server.
class RideRouteOverviewPage extends StatefulWidget {
  const RideRouteOverviewPage({required this.places, super.key});

  final RidePlaces places;

  @override
  State<RideRouteOverviewPage> createState() => _RideRouteOverviewPageState();
}

class _RideRouteOverviewPageState extends State<RideRouteOverviewPage> {
  RideQuote? _quote;
  var _failed = false;
  Object? _error;

  RidePlaces get places => widget.places;

  @override
  void initState() {
    super.initState();
    _quote = widget.places.quote;
    if (_quote == null) {
      unawaited(_load());
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _continue(context);
        }
      });
    }
  }

  Future<void> _load() async {
    final token = rideAccessToken(context);
    setState(() => _failed = false);
    if (token == null) {
      setState(() => _failed = true);
      return;
    }
    try {
      final quote = await context.read<PricingRepository>().quoteRide(
        accessToken: token,
        pickup: (
          lat: places.pickup.lat,
          lng: places.pickup.lng,
          label: places.pickup.label,
        ),
        dropoff: (
          lat: places.dropoff.lat,
          lng: places.dropoff.lng,
          label: places.dropoff.label,
        ),
        stops: [
          for (final s in places.stops)
            (lat: s.lat, lng: s.lng, label: s.label),
        ],
      );
      if (mounted) {
        setState(() => _quote = quote);
        // Hot path / deep-link: skip manual "continue" tap (inDrive-like).
        RideSmokeFlags.autoContinueAfterQuote = false;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _continue(context);
          }
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _failed = true;
          _error = error;
        });
      }
    }
  }

  void _continue(BuildContext context) {
    final quote = _quote;
    if (quote == null) {
      return;
    }
    // Hot path: class + bid on one screen (skip separate vehicle / breakdown hops).
    context.push(RideRoutes.fare, extra: places.withQuote(quote));
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
    final quote = _quote;
    final distance = quote == null
        ? '…'
        : l10n.rideDistanceKm(_formatKm(quote.distanceKm));
    return Scaffold(
      backgroundColor: DealGoColors.canvas,
      body: SafeArea(
        child: Column(
          children: [
            DealGoAppHeader(
              title: l10n.rideRouteOverviewTitle,
              onBack: () => _back(context),
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
                            context.watch<MapPort>().buildMap(
                              center: MapLatLng(
                                lat: places.pickup.lat,
                                lng: places.pickup.lng,
                              ),
                              markers: [
                                MapLatLng(
                                  lat: places.pickup.lat,
                                  lng: places.pickup.lng,
                                ),
                                MapLatLng(
                                  lat: places.dropoff.lat,
                                  lng: places.dropoff.lng,
                                ),
                              ],
                              route: (quote?.route ?? RouteGeometry.unavailable)
                                  .polylineOr([
                                    MapLatLng(
                                      lat: places.pickup.lat,
                                      lng: places.pickup.lng,
                                    ),
                                    MapLatLng(
                                      lat: places.dropoff.lat,
                                      lng: places.dropoff.lng,
                                    ),
                                  ]),
                              pulseRoute: true,
                            ),
                            if (quote != null)
                              Align(
                                alignment: Alignment.topCenter,
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 96),
                                  child: DealGoChip(
                                    label: distance,
                                    tone: DealGoChipTone.brand,
                                    leading: Icon(
                                      rideVehicleClassIcon(
                                        places.vehicleClassCode,
                                      ),
                                      size: 14,
                                      color: DealGoColors.primary,
                                    ),
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
                              stops: [for (final s in places.stops) s.label],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            RideBottomSheet(
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
                    const SizedBox(height: DealGoSpacing.s12),
                    Text(
                      l10n.rideRouteOverviewTitle,
                      style: textTheme.titleLarge,
                    ),
                    if (_failed)
                      Builder(
                        builder: (context) {
                          final zone = rideQuoteZoneErrorText(l10n, _error);
                          return DealGoBanner(
                            key: Key(
                              zone == null
                                  ? 'ride-quote-error'
                                  : 'ride-quote-zone-error',
                            ),
                            tone: DealGoBannerTone.warning,
                            message: zone ?? l10n.rideQuoteError,
                            actionLabel: zone == null ? l10n.actionRetry : null,
                            onAction: zone == null
                                ? () => unawaited(_load())
                                : null,
                          );
                        },
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: _StatTile(
                              label: l10n.rideRouteDistance,
                              value: distance,
                            ),
                          ),
                          const SizedBox(width: DealGoSpacing.s8),
                          Expanded(
                            child: _StatTile(
                              key: const Key('ride-quote-reference'),
                              label: l10n.rideRouteRefPrice,
                              value: quote == null
                                  ? '…'
                                  : formatRideVnd(quote.referenceFareVnd),
                              emphasize: true,
                            ),
                          ),
                        ],
                      ),
                    if (quote == null && !_failed) ...[
                      const SizedBox(height: DealGoSpacing.s12),
                      Text(l10n.rideQuoteLoading, style: textTheme.bodySmall),
                    ],
                    const SizedBox(height: DealGoSpacing.s16),
                    DealGoPrimaryButton(
                      key: const Key('ride-continue-booking'),
                      label: l10n.rideRouteContinueBooking,
                      trailingIcon: DealGoIcons.arrowRight,
                      enabled: quote != null,
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

String _formatKm(double km) => km.toStringAsFixed(1).replaceAll('.', ',');

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    this.emphasize = false,
    super.key,
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
