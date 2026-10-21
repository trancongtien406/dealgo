import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/maps/map_lat_lng.dart';
import '../../../core/design_system/icons/dealgo_icons.dart';
import '../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../core/maps/map_port.dart';
import '../../../l10n/app_localizations.dart';
import '../../identity/domain/entities/auth_state.dart';
import '../../identity/presentation/cubit/auth_cubit.dart';
import '../domain/driver_location.dart';

/// Map for an active job that adds the assigned driver's live position
/// (DEC-PROD-031). Polls only while [tracking] is true; a missing or stale
/// position simply shows the stops.
class LiveDriverMap extends StatefulWidget {
  const LiveDriverMap({
    required this.job,
    required this.id,
    required this.tracking,
    required this.center,
    this.markers = const [],
    this.interval = const Duration(seconds: 10),
    super.key,
  });

  final TrackedJob job;
  final String id;
  final bool tracking;
  final MapLatLng center;
  final List<MapLatLng> markers;
  final Duration interval;

  @override
  State<LiveDriverMap> createState() => _LiveDriverMapState();
}

class _LiveDriverMapState extends State<LiveDriverMap> {
  Timer? _timer;
  DriverLiveLocation? _location;
  var _loading = false;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(LiveDriverMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tracking != widget.tracking || oldWidget.id != widget.id) {
      _sync();
    }
  }

  void _sync() {
    _timer?.cancel();
    _timer = null;
    if (!widget.tracking) {
      if (_location != null) {
        setState(() => _location = null);
      }
      return;
    }
    _timer = Timer.periodic(widget.interval, (_) => unawaited(_poll()));
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_poll()));
  }

  Future<void> _poll() async {
    if (!mounted || _loading || !widget.tracking) {
      return;
    }
    final auth = context.read<AuthCubit>().state;
    if (auth is! AuthSignedIn) {
      return;
    }
    DriverLocationRepository repository;
    try {
      repository = context.read<DriverLocationRepository>();
    } on ProviderNotFoundException {
      return;
    }
    _loading = true;
    try {
      final next = await repository.latest(
        accessToken: auth.tokens.accessToken,
        job: widget.job,
        id: widget.id,
      );
      if (mounted && widget.tracking) {
        setState(() => _location = next);
      }
    } catch (_) {
      // Keep the last fix; the next poll retries.
    } finally {
      _loading = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final location = _location;
    final map = context.read<MapPort>().buildMap(
      center: widget.center,
      markers: widget.markers,
      driver: location == null
          ? null
          : MapLatLng(lat: location.lat, lng: location.lng),
    );
    if (location == null) {
      return map;
    }
    final local = location.at.toLocal();
    final time =
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
    return Stack(
      fit: StackFit.expand,
      children: [
        map,
        Positioned(
          left: DealGoSpacing.s12,
          bottom: DealGoSpacing.s12,
          child: DecoratedBox(
            key: const Key('tracking-driver-live'),
            decoration: BoxDecoration(
              color: DealGoColors.card.withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: DealGoColors.border),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: DealGoSpacing.s8,
                vertical: DealGoSpacing.s4,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    DealGoIcons.motorbike,
                    size: 14,
                    color: DealGoColors.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    AppLocalizations.of(context).trackingDriverLiveAt(time),
                    style: Theme.of(context).textTheme.labelSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
