import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Turn-by-turn apps a driver can hand a stop to (DEC-PROD-035 §nav).
///
/// DealGo itself does no turn-by-turn guidance: voice/lane guidance is
/// always delegated to one of these apps, so no in-app re-routing requests.
/// [web] is Google Maps in the browser: always available, the last resort.
enum NavigationApp { googleMaps, appleMaps, waze, web }

/// Opens a destination in an external navigation app.
///
/// Returns false when nothing could be opened (no app and no browser), so the
/// caller can tell the driver instead of failing silently.
abstract class ExternalNavigator {
  /// Apps this phone can hand a stop to (native app installed, checked with
  /// `canLaunchUrl`; needs LSApplicationQueriesSchemes / Android `<queries>`).
  /// Always contains [NavigationApp.web].
  Future<Set<NavigationApp>> available();

  Future<bool> open(
    NavigationApp app, {
    required double lat,
    required double lng,
  });
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
    case NavigationApp.appleMaps:
      return [
        if (platform == TargetPlatform.iOS)
          Uri.parse('maps://?daddr=$point&dirflg=d'),
        Uri.https('maps.apple.com', '/', {'daddr': point, 'dirflg': 'd'}),
      ];
    case NavigationApp.waze:
      return [
        Uri.parse('waze://?ll=$point&navigate=yes'),
        Uri.https('waze.com', '/ul', {'ll': point, 'navigate': 'yes'}),
      ];
    case NavigationApp.web:
      return [
        Uri.https('www.google.com', '/maps/dir/', {
          'api': '1',
          'destination': point,
          'travelmode': 'driving',
        }),
      ];
  }
}

/// The native scheme that proves an app is installed (null = always there /
/// not offered on this platform).
@visibleForTesting
Uri? installProbe(NavigationApp app, TargetPlatform platform) {
  switch (app) {
    case NavigationApp.googleMaps:
      return platform == TargetPlatform.android
          ? Uri.parse('google.navigation:q=0,0')
          : Uri.parse('comgooglemaps://');
    case NavigationApp.waze:
      return Uri.parse('waze://');
    case NavigationApp.appleMaps:
    case NavigationApp.web:
      return null;
  }
}

typedef UriLauncher = Future<bool> Function(Uri uri);

class UrlLauncherNavigator implements ExternalNavigator {
  UrlLauncherNavigator({
    UriLauncher? launcher,
    UriLauncher? canLaunch,
    this.platform,
  }) : _launch = launcher ?? _defaultLaunch,
       _canLaunch = canLaunch ?? _defaultCanLaunch;

  final UriLauncher _launch;
  final UriLauncher _canLaunch;

  static Future<bool> _defaultCanLaunch(Uri uri) async {
    try {
      return await canLaunchUrl(uri);
    } on Object {
      return false;
    }
  }

  @override
  Future<Set<NavigationApp>> available() async {
    final os = platform ?? defaultTargetPlatform;
    final out = <NavigationApp>{};
    for (final app in [
      NavigationApp.googleMaps,
      NavigationApp.appleMaps,
      NavigationApp.waze,
    ]) {
      if (app == NavigationApp.appleMaps) {
        // Ships with every iPhone; not offered elsewhere.
        if (os == TargetPlatform.iOS) out.add(app);
        continue;
      }
      final probe = installProbe(app, os);
      if (probe != null && await _canLaunch(probe)) {
        out.add(app);
      }
    }
    out.add(NavigationApp.web);
    return out;
  }

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
  Future<bool> open(
    NavigationApp app, {
    required double lat,
    required double lng,
  }) async {
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
