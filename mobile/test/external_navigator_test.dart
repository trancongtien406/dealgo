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
      expect(
        android.first.toString(),
        'google.navigation:q=16.06,108.22&mode=d',
      );
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

    test('Apple Maps (r25): maps:// on iOS, then maps.apple.com', () {
      final ios = navigationUris(
        NavigationApp.appleMaps,
        lat: 16.06,
        lng: 108.22,
        platform: TargetPlatform.iOS,
      );
      expect(ios.first.toString(), 'maps://?daddr=16.06,108.22&dirflg=d');
      expect(ios.last.host, 'maps.apple.com');
      expect(ios.last.queryParameters['daddr'], '16.06,108.22');
      final android = navigationUris(
        NavigationApp.appleMaps,
        lat: 16.06,
        lng: 108.22,
        platform: TargetPlatform.android,
      );
      expect(android, hasLength(1));
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
      expect(
        await navigator.open(NavigationApp.googleMaps, lat: 1, lng: 2),
        isFalse,
      );
    });
  });

  group('available()', () {
    test('lists only installed apps, Apple on iOS, web always', () async {
      final probed = <String>[];
      final ios = UrlLauncherNavigator(
        platform: TargetPlatform.iOS,
        launcher: (_) async => true,
        canLaunch: (uri) async {
          probed.add(uri.scheme);
          return uri.scheme == 'waze';
        },
      );
      expect(await ios.available(), {
        NavigationApp.appleMaps,
        NavigationApp.waze,
        NavigationApp.web,
      });
      expect(probed, ['comgooglemaps', 'waze']);

      final android = UrlLauncherNavigator(
        platform: TargetPlatform.android,
        launcher: (_) async => true,
        canLaunch: (uri) async => uri.scheme == 'google.navigation',
      );
      expect(await android.available(), {
        NavigationApp.googleMaps,
        NavigationApp.web,
      });
    });

    test('web fallback is a Google Maps directions link', () {
      final uris = navigationUris(
        NavigationApp.web,
        lat: 16.06,
        lng: 108.22,
        platform: TargetPlatform.iOS,
      );
      expect(uris.single.host, 'www.google.com');
      expect(uris.single.queryParameters['destination'], '16.06,108.22');
    });
  });
}
