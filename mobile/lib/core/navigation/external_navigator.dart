import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Turn-by-turn apps a driver can hand a stop to (DEC-PROD-035 §nav).
enum NavigationApp { googleMaps, waze }

/// Opens a destination in an external navigation app.
///
/// Returns false when nothing could be opened (no app and no browser), so the
/// caller can tell the driver instead of failing silently.
abstract class ExternalNavigator {
  Future<bool> open(NavigationApp app, {required double lat, required double lng});
}

/// Candidate URIs, most specific first: the native app scheme, then the
/// universal web link (opens the app when installed, else the browser).
@visibleForTesting
List<Uri> navigationUris(
  NavigationApp app, {
  required double lat,
  required double lng,
  required TargetPlatform platform,
}) {
  final point = '$lat,$lng';
  switch (app) {
    case NavigationApp.googleMaps:
      return [
        if (platform == TargetPlatform.android)
          Uri.parse('google.navigation:q=$point&mode=d'),
        if (platform == TargetPlatform.iOS)
          Uri.parse('comgooglemaps://?daddr=$point&directionsmode=driving'),
        Uri.https('www.google.com', '/maps/dir/', {
          'api': '1',
          'destination': point,
          'travelmode': 'driving',
        }),
      ];
    case NavigationApp.waze:
      return [
        Uri.parse('waze://?ll=$point&navigate=yes'),
        Uri.https('waze.com', '/ul', {'ll': point, 'navigate': 'yes'}),
      ];
  }
}

typedef UriLauncher = Future<bool> Function(Uri uri);

class UrlLauncherNavigator implements ExternalNavigator {
  UrlLauncherNavigator({UriLauncher? launcher, this.platform})
    : _launch = launcher ?? _defaultLaunch;

  final UriLauncher _launch;

  /// Overrides [defaultTargetPlatform] (tests).
  final TargetPlatform? platform;

  static Future<bool> _defaultLaunch(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on Object {
      // Missing app / no handler: try the next candidate.
      return false;
    }
  }

  @override
  Future<bool> open(NavigationApp app, {required double lat, required double lng}) async {
    final uris = navigationUris(
      app,
      lat: lat,
      lng: lng,
      platform: platform ?? defaultTargetPlatform,
    );
    for (final uri in uris) {
      if (await _launch(uri)) {
        return true;
      }
    }
    return false;
  }
}
