import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/entities/food_models.dart';

typedef FoodMapOpener = Future<bool> Function(Uri uri);

/// Test seam: widgets call the default launcher; tests swap this out.
@visibleForTesting
FoodMapOpener? debugFoodMapOpener;

/// Google Maps search link for the store: coordinates when the merchant set
/// them, otherwise the written address (Maps resolves the text itself).
Uri foodStoreMapsUri(FoodStoreDetail store) {
  final lat = store.lat;
  final lng = store.lng;
  final query = lat != null && lng != null
      ? '$lat,$lng'
      : [store.name, store.addressLabel]
            .whereType<String>()
            .map((part) => part.trim())
            .where((part) => part.isNotEmpty)
            .join(', ');
  return Uri.https('www.google.com', '/maps/search/', {
    'api': '1',
    'query': query,
  });
}

Future<bool> _launch(Uri uri) async {
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } on Object {
    return false;
  }
}

/// Opens the store in Google Maps; false when no handler accepted the link.
Future<bool> openStoreInGoogleMaps(
  FoodStoreDetail store, {
  FoodMapOpener open = _launch,
}) {
  final opener = debugFoodMapOpener ?? open;
  return opener(foodStoreMapsUri(store));
}
