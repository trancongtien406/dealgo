import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';

import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../core/location/location_service.dart';
import '../../../../core/maps/map_lat_lng.dart';
import '../../../../core/maps/map_markers.dart';
import '../../../../core/maps/map_port.dart';
import '../../../../l10n/app_localizations.dart';
import '../cubit/driver_feed_cubit.dart';

/// Reads the driver's current fix without ever prompting (null = unknown).
typedef DriverFixReader = Future<MapLatLng?> Function();

/// Round 27: the driver overview map. It used to be a hand-drawn
/// `CustomPaint` (fake streets / river / route) that ignored Mapbox and the
/// driver's position. It now renders through the shared [MapPort] (Mapbox
/// raster tiles when MAPS_API_KEY is set) with the driver's own GPS marker and
/// open-job pickups from the existing feed as demand hints. Tiles only: no
/// route is drawn, so no Directions request is ever made from here.
class DriverDutyMap extends StatefulWidget {
  const DriverDutyMap({
    required this.online,
    this.vehicleClassCode,
    this.demand = const [],
    this.readFix,
    this.refresh = const Duration(seconds: 10),
    super.key,
  });

  final bool online;
  final String? vehicleClassCode;

  /// Pickup points of open jobs near the driver (already filtered).
  final List<MapLatLng> demand;

  /// Test seam; defaults to [LocationService.quietPosition] from context.
  final DriverFixReader? readFix;
  final Duration refresh;

  @override
  State<DriverDutyMap> createState() => _DriverDutyMapState();
}

class _DriverDutyMapState extends State<DriverDutyMap> {
  MapLatLng? _fix;
  Timer? _timer;
  DriverFixReader? _reader;
  var _reading = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_reader != null) {
      return;
    }
    _reader = widget.readFix ?? _defaultReader(context);
    unawaited(_read());
    // The location reporter asks for permission when the driver goes online,
    // so poll the cached fix quietly instead of prompting from the overview.
    _timer = Timer.periodic(widget.refresh, (_) => unawaited(_read()));
  }

  static DriverFixReader? _defaultReader(BuildContext context) {
    LocationService? service;
    try {
      service = context.read<LocationService>();
    } on ProviderNotFoundException {
      return null;
    }
    return () async {
      final Position? p = await service!.quietPosition();
      return p == null ? null : MapLatLng(lat: p.latitude, lng: p.longitude);
    };
  }

  Future<void> _read() async {
    final reader = _reader;
    if (reader == null || _reading) {
      return;
    }
    _reading = true;
    try {
      final next = await reader();
      if (!mounted || next == null) {
        return;
      }
      final prev = _fix;
      if (prev == null ||
          (prev.lat - next.lat).abs() > 1e-6 ||
          (prev.lng - next.lng).abs() > 1e-6) {
        setState(() => _fix = next);
      }
    } catch (_) {
      // Best-effort preview; keep the last fix.
    } finally {
      _reading = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fix = _fix;
    final demand = fix == null
        ? const <MapLatLng>[]
        : nearbyDemand(fix, widget.demand);
    return ClipRRect(
      key: const Key('driver-duty-map'),
      borderRadius: BorderRadius.circular(DealGoRadius.card),
      child: SizedBox(
        height: 180,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // A preview card inside a scrolling page: let the page scroll.
            IgnorePointer(
              child: context.watch<MapPort>().buildMap(
                key: const ValueKey('driver-duty-map-port'),
                center: fix ?? danangViewportCenter,
                driver: fix,
                markers: demand,
                firstMarkerIsPickup: false,
                driverVehicle: mapVehicleForClass(widget.vehicleClassCode),
                fitPadding: const EdgeInsets.all(36),
              ),
            ),
            Positioned(
              left: 12,
              top: 12,
              child: DecoratedBox(
                key: Key(
                  widget.online
                      ? 'driver-duty-map-online'
                      : 'driver-duty-map-offline',
                ),
                decoration: BoxDecoration(
                  color: widget.online
                      ? DealGoColors.primary
                      : DealGoColors.textSecondary,
                  borderRadius: const BorderRadius.all(Radius.circular(999)),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DealGoSpacing.s12,
                    vertical: DealGoSpacing.s8,
                  ),
                  child: Text(
                    widget.online
                        ? AppLocalizations.of(context).driverOnDutyMapLabel
                        : AppLocalizations.of(context).driverOfflineChip,
                    style: const TextStyle(
                      color: DealGoColors.card,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Open-job pickups within [radiusM] of the driver, nearest first, at most
/// [limit], so a far job never zooms the overview out to a whole city.
List<MapLatLng> nearbyDemand(
  MapLatLng driver,
  List<MapLatLng> points, {
  double radiusM = 5000,
  int limit = 6,
}) {
  final scored = <(double, MapLatLng)>[
    for (final p in points)
      (Geolocator.distanceBetween(driver.lat, driver.lng, p.lat, p.lng), p),
  ]..removeWhere((e) => e.$1 > radiusM);
  scored.sort((a, b) => a.$1.compareTo(b.$1));
  return [for (final e in scored.take(limit)) e.$2];
}

/// Pickup points from the driver feed (rides + ready food orders).
List<MapLatLng> feedDemandPoints(DriverFeedState state) {
  if (state is! DriverFeedReady) {
    return const [];
  }
  return [
    for (final ride in state.rides)
      MapLatLng(lat: ride.pickup.lat, lng: ride.pickup.lng),
    for (final job in state.food)
      if (job.pickup case final p?) MapLatLng(lat: p.lat, lng: p.lng),
  ];
}
