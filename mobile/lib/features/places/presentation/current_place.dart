import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/location/location_service.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/place.dart';

/// Outcome of asking the device for the customer's position.
sealed class CurrentPlaceResult {
  const CurrentPlaceResult();
}

class CurrentPlaceFound extends CurrentPlaceResult {
  const CurrentPlaceFound(this.place);

  final PlaceOption place;
}

/// Permission refused or location services off.
class CurrentPlaceDenied extends CurrentPlaceResult {
  const CurrentPlaceDenied();
}

class CurrentPlaceFailed extends CurrentPlaceResult {
  const CurrentPlaceFailed();
}

/// GPS fix, named through `GET /v1/places/reverse` when the provider knows it.
///
/// The coordinates always come from the device; only the label is looked up,
/// so a reverse-geocoding failure still yields a usable pickup.
Future<CurrentPlaceResult> locateCurrentPlace(
  BuildContext context, {
  required String? accessToken,
}) async {
  final l10n = AppLocalizations.of(context);
  final location = context.read<LocationService>();
  final places = context.read<PlacesRepository>();
  final double lat;
  final double lng;
  try {
    final position = await location.currentPosition().timeout(
      const Duration(seconds: 15),
    );
    if (position == null) {
      return const CurrentPlaceDenied();
    }
    lat = position.latitude;
    lng = position.longitude;
  } catch (_) {
    return const CurrentPlaceFailed();
  }
  PlaceOption? named;
  if (accessToken != null) {
    try {
      named = await places.reverse(
        accessToken: accessToken,
        lat: lat,
        lng: lng,
      );
    } catch (_) {
      named = null;
    }
  }
  return CurrentPlaceFound(
    PlaceOption(
      name: named?.name ?? l10n.placeCurrentNamed,
      address: named?.address ?? '',
      lat: lat,
      lng: lng,
      source: PlaceSource.current,
    ),
  );
}
