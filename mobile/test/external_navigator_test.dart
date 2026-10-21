import 'package:dealgo/core/navigation/external_navigator.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('navigationUris (DEC-PROD-035)', () {
    test('Google Maps: native intent / scheme first, then the web link', () {
      final android = navigationUris(
        NavigationApp.googleMaps,
        lat: 16.06,
        lng: 108.22,
        platform: TargetPlatform.android,
      );
      expect(android.first.toString(), 'google.navigation:q=16.06,108.22&mode=d');
      expect(android.last.host, 'www.google.com');
      expect(android.last.queryParameters['destination'], '16.06,108.22');

      final ios = navigationUris(
        NavigationApp.googleMaps,
        lat: 16.06,
        lng: 108.22,
        platform: TargetPlatform.iOS,
      );
      expect(ios.first.scheme, 'comgooglemaps');
      expect(ios, hasLength(2));
    });

    test('Waze: app scheme then waze.com universal link', () {
      final uris = navigationUris(
        NavigationApp.waze,
        lat: 16.06,
        lng: 108.22,
        platform: TargetPlatform.android,
      );
      expect(uris.first.toString(), 'waze://?ll=16.06,108.22&navigate=yes');
      expect(uris.last.host, 'waze.com');
      expect(uris.last.queryParameters['ll'], '16.06,108.22');
    });
  });

  group('UrlLauncherNavigator', () {
    test('falls back to the web link when the app is missing', () async {
      final tried = <Uri>[];
      final navigator = UrlLauncherNavigator(
        platform: TargetPlatform.android,
        launcher: (uri) async {
          tried.add(uri);
          return uri.scheme == 'https';
        },
      );
      expect(await navigator.open(NavigationApp.waze, lat: 1, lng: 2), isTrue);
      expect(tried.map((uri) => uri.scheme), ['waze', 'https']);
    });

    test('reports false when nothing can be opened', () async {
      final navigator = UrlLauncherNavigator(
        platform: TargetPlatform.iOS,
        launcher: (_) async => false,
      );
      expect(await navigator.open(NavigationApp.googleMaps, lat: 1, lng: 2), isFalse);
    });
  });
}
