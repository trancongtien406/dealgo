import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class OnboardingStorage {
  Future<bool> hasSeenOnboarding();
  Future<void> setSeenOnboarding(bool value);

  Future<bool> hasCompletedProfileSetup();
  Future<void> setCompletedProfileSetup(bool value);

  Future<bool> hasCompletedPermissions();
  Future<void> setCompletedPermissions(bool value);
}

/// Standard mobile storage for onboarding state.
///
/// Uses [SharedPreferences] (iOS NSUserDefaults / Android SharedPreferences)
/// so that the onboarding state is strictly tied to the application sandbox
/// lifecycle and is reliably reset when the app is uninstalled/reinstalled
/// by the user (unlike iOS Keychain which persists across app deletions).
///
/// Also handles first-run detection to clean up any legacy keys left behind
/// in secure storage from older versions.
class AppOnboardingStorage implements OnboardingStorage {
  AppOnboardingStorage({this.prefs, FlutterSecureStorage? legacySecureStorage})
    : _legacy = legacySecureStorage ?? const FlutterSecureStorage();

  static const _key = 'dealgo.hasSeenOnboarding';
  static const _profileKey = 'dealgo.hasCompletedProfileSetup';
  static const _permissionsKey = 'dealgo.hasCompletedPermissions';
  static const _firstRunKey = 'dealgo.app_installed';
  final SharedPreferences? prefs;
  final FlutterSecureStorage _legacy;
  static bool? _fallbackSeen;
  static bool? _fallbackProfile;
  static bool? _fallbackPermissions;

  Future<SharedPreferences?> _getPrefs() async {
    if (prefs != null) return prefs;
    try {
      return await SharedPreferences.getInstance();
    } catch (_) {
      return null;
    }
  }

  Future<bool> _ensureInitialized(SharedPreferences prefs) async {
    final isInitialized = prefs.getBool(_firstRunKey) ?? false;
    if (isInitialized) {
      return true;
    }
    try {
      await _legacy.delete(key: _key);
    } catch (_) {}
    await prefs.setBool(_firstRunKey, true);
    await prefs.setBool(_key, false);
    await prefs.setBool(_profileKey, false);
    await prefs.setBool(_permissionsKey, false);
    return false;
  }

  @override
  Future<bool> hasSeenOnboarding() async {
    final prefs = await _getPrefs();
    if (prefs == null) {
      return _fallbackSeen ?? false;
    }
    try {
      final ready = await _ensureInitialized(prefs);
      if (!ready) {
        return false;
      }
      return prefs.getBool(_key) ?? false;
    } catch (_) {
      return _fallbackSeen ?? false;
    }
  }

  @override
  Future<void> setSeenOnboarding(bool value) async {
    _fallbackSeen = value;
    final prefs = await _getPrefs();
    if (prefs == null) return;
    try {
      await prefs.setBool(_key, value);
      try {
        await _legacy.delete(key: _key);
      } catch (_) {}
    } catch (_) {}
  }

  @override
  Future<bool> hasCompletedProfileSetup() async {
    final prefs = await _getPrefs();
    if (prefs == null) {
      return _fallbackProfile ?? false;
    }
    try {
      final ready = await _ensureInitialized(prefs);
      if (!ready) {
        return false;
      }
      return prefs.getBool(_profileKey) ?? false;
    } catch (_) {
      return _fallbackProfile ?? false;
    }
  }

  @override
  Future<void> setCompletedProfileSetup(bool value) async {
    _fallbackProfile = value;
    final prefs = await _getPrefs();
    if (prefs == null) return;
    try {
      await prefs.setBool(_profileKey, value);
    } catch (_) {}
  }

  @override
  Future<bool> hasCompletedPermissions() async {
    final prefs = await _getPrefs();
    if (prefs == null) {
      return _fallbackPermissions ?? false;
    }
    try {
      final ready = await _ensureInitialized(prefs);
      if (!ready) {
        return false;
      }
      return prefs.getBool(_permissionsKey) ?? false;
    } catch (_) {
      return _fallbackPermissions ?? false;
    }
  }

  @override
  Future<void> setCompletedPermissions(bool value) async {
    _fallbackPermissions = value;
    final prefs = await _getPrefs();
    if (prefs == null) return;
    try {
      await prefs.setBool(_permissionsKey, value);
    } catch (_) {}
  }
}

/// Backward compatibility alias for [AppOnboardingStorage].
class SecureOnboardingStorage extends AppOnboardingStorage {
  SecureOnboardingStorage({super.prefs, super.legacySecureStorage});
}

class MemoryOnboardingStorage implements OnboardingStorage {
  MemoryOnboardingStorage({
    bool initial = false,
    this._profileSetupCompleted = false,
    this._permissionsCompleted = false,
  }) : _seen = initial;

  bool _seen;
  bool _profileSetupCompleted;
  bool _permissionsCompleted;

  @override
  Future<bool> hasSeenOnboarding() async => _seen;

  @override
  Future<void> setSeenOnboarding(bool value) async {
    _seen = value;
  }

  @override
  Future<bool> hasCompletedProfileSetup() async => _profileSetupCompleted;

  @override
  Future<void> setCompletedProfileSetup(bool value) async {
    _profileSetupCompleted = value;
  }

  @override
  Future<bool> hasCompletedPermissions() async => _permissionsCompleted;

  @override
  Future<void> setCompletedPermissions(bool value) async {
    _permissionsCompleted = value;
  }
}
