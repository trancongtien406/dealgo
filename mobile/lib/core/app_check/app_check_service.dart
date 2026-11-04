import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class AppCheckService {
  AppCheckService();

  bool _activated = false;

  /// Activates Firebase App Check with Play Integrity (Android) and DeviceCheck (iOS).
  /// In debug mode, falls back to debug providers.
  Future<void> activate() async {
    if (kIsWeb || Firebase.apps.isEmpty || _activated) {
      return;
    }
    try {
      await FirebaseAppCheck.instance.activate(
        providerAndroid: kDebugMode
            ? const AndroidDebugProvider()
            : const AndroidPlayIntegrityProvider(),
        providerApple: kDebugMode
            ? const AppleDebugProvider()
            : const AppleDeviceCheckProvider(),
      );
      _activated = true;
    } catch (e) {
      debugPrint('Firebase App Check activate skipped: $e');
    }
  }

  /// Retrieves the current App Check token; returns null if unavailable or error.
  Future<String?> getToken({bool forceRefresh = false}) async {
    if (kIsWeb || Firebase.apps.isEmpty) {
      return null;
    }
    try {
      if (!_activated) {
        await activate();
      }
      return await FirebaseAppCheck.instance.getToken(forceRefresh);
    } catch (e) {
      debugPrint('Firebase App Check getToken error: $e');
      return null;
    }
  }
}
