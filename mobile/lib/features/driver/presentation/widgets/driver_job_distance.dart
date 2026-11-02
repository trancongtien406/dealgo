import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/maps/map_lat_lng.dart';
import '../../../../core/design_system/icons/dealgo_icons.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../live_location/domain/driver_location.dart';
import '../../../ride/domain/entities/ride_models.dart';
import '../../../ride/presentation/utils/ride_distance.dart';
import '../cubit/driver_duty_cubit.dart';

/// One km figure on a job card; [approx] = client straight-line estimate.
class JobKm {
  const JobKm(this.km, {required this.approx});

  final double km;
  final bool approx;

  String get text => '${approx ? '~' : ''}${formatRideKm(km)}';
}

/// t82u: trip length + driver→pickup distance for an open job.
///
/// Server values win (route km from the booking quote; pickup km from the
/// driver's last reported position). Otherwise a straight-line estimate
/// (`~`): trip over pickup → stops → drop-off, pickup from [driverFix].
/// Either is null when nothing is known — the card just hides it.
({JobKm? trip, JobKm? pickup}) jobDistances(
  OpenRide ride,
  DriverLocationFix? driverFix,
) {
  JobKm? trip;
  final serverTrip = ride.tripDistanceKm;
  if (serverTrip != null && serverTrip > 0) {
    trip = JobKm(serverTrip, approx: false);
  } else {
    final points = [ride.pickup, ...ride.stops, ride.dropoff];
    var sum = 0.0;
    for (var i = 1; i < points.length; i++) {
      sum += haversineKm(
        MapLatLng(lat: points[i - 1].lat, lng: points[i - 1].lng),
        MapLatLng(lat: points[i].lat, lng: points[i].lng),
      );
    }
    if (sum > 0) trip = JobKm(sum, approx: true);
  }
  JobKm? pickup;
  final serverPickup = ride.pickupDistanceKm;
  if (serverPickup != null && serverPickup >= 0) {
    pickup = JobKm(serverPickup, approx: false);
  } else if (driverFix != null) {
    pickup = JobKm(
      haversineKm(
        MapLatLng(lat: driverFix.lat, lng: driverFix.lng),
        MapLatLng(lat: ride.pickup.lat, lng: ride.pickup.lng),
      ),
      approx: true,
    );
  }
  return (trip: trip, pickup: pickup);
}

/// Last driver fix if a [DriverDutyCubit] is in scope (null in isolated tests).
DriverLocationFix? driverLastFixOf(BuildContext context) {
  try {
    return context.read<DriverDutyCubit>().lastFix;
  } on ProviderNotFoundException {
    return null;
  }
}

/// Compact "🛣 Chuyến 5,2 km · 📍 Cách điểm đón ~1,2 km" row.
class DriverJobDistanceRow extends StatelessWidget {
  const DriverJobDistanceRow({
    super.key,
    required this.ride,
    this.dense = true,
  });

  final OpenRide ride;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final d = jobDistances(ride, driverLastFixOf(context));
    final trip = d.trip;
    final pickup = d.pickup;
    if (trip == null && pickup == null) return const SizedBox.shrink();
    final style =
        (dense
                ? Theme.of(context).textTheme.labelMedium
                : Theme.of(context).textTheme.bodyMedium)
            ?.copyWith(
              color: DealGoColors.textSecondary,
              fontWeight: FontWeight.w600,
            );
    Widget item(Key key, IconData icon, String text) => Row(
      key: key,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: dense ? 14 : 16, color: DealGoColors.primary),
        const SizedBox(width: 2),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.only(top: DealGoSpacing.s4),
      child: Wrap(
        spacing: DealGoSpacing.s12,
        runSpacing: 2,
        children: [
          if (trip != null)
            item(
              Key('job-trip-km-${ride.id}'),
              DealGoIcons.navigation,
              l10n.driverJobTripKm(trip.text),
            ),
          if (pickup != null)
            item(
              Key('job-pickup-km-${ride.id}'),
              DealGoIcons.pin,
              l10n.driverJobPickupKm(pickup.text),
            ),
        ],
      ),
    );
  }
}
