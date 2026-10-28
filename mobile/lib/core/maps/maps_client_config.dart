import 'dart:async';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_env.dart';
import '../network/api_envelope.dart';
import '../network/api_paths.dart';

/// Runtime Mapbox public token from `GET /v1/public/client-config` (set in
/// Admin › Bản đồ). No mobile setting is needed: [resolveAtLaunch] runs under
/// the native splash so the first map already has the token, and [refresh]
/// applies a new or cleared token live (map pages rebuild through
/// [adminMapboxTokenListenable]) and caches it for the next launch.
abstract final class MapsClientConfig {
  static const _prefsKey = 'dealgo.mapboxPublicToken';

  /// Longest the splash waits for the network when nothing is cached.
  static const launchWait = Duration(seconds: 3);

  static bool _isPublicToken(Object? value) =>
      value is String && value.startsWith('pk.');

  /// Applies the cached token (instant, no network).
  static Future<void> warmUp() async {
    try {
      final cached = (await SharedPreferences.getInstance()).getString(
        _prefsKey,
      );
      adminMapboxToken = _isPublicToken(cached) ? cached! : '';
    } catch (_) {
      adminMapboxToken = '';
    }
  }

  /// Cached token first; with nothing cached (fresh install) the splash waits
  /// up to [launchWait] for the API. The refresh always finishes in the
  /// background, so a slow answer still switches the maps on.
  static Future<void> resolveAtLaunch(Dio dio) async {
    await warmUp();
    final pending = refresh(dio);
    if (adminMapboxToken.isEmpty) {
      await pending.timeout(launchWait, onTimeout: () {});
    } else {
      unawaited(pending);
    }
  }

  static Future<void> refresh(Dio dio) async {
    try {
      final response = await dio.get<Object?>(ApiPaths.publicClientConfig);
      final payload = readSuccessPayload(response.data);
      final token = payload is Map ? payload['mapboxPublicToken'] : null;
      final prefs = await SharedPreferences.getInstance();
      if (_isPublicToken(token)) {
        adminMapboxToken = token as String;
        await prefs.setString(_prefsKey, token);
      } else {
        // Cleared in Admin: back to the build-time key / placeholder.
        adminMapboxToken = '';
        await prefs.remove(_prefsKey);
      }
    } catch (_) {
      // Offline or older API: keep the cached / build-time token.
    }
  }
}
