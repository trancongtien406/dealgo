import 'package:flutter/foundation.dart';

import '../storage/onboarding_storage.dart';

/// Sync cache of post-sign-in onboarding flags for [GoRouter] redirects.
class PostAuthGate extends ChangeNotifier {
  PostAuthGate({OnboardingStorage? storage})
    : _storage = storage ?? AppOnboardingStorage();

  PostAuthGate.seeded({
    bool profileSetupCompleted = false,
    bool permissionsCompleted = false,
    OnboardingStorage? storage,
  }) : _storage =
           storage ??
           MemoryOnboardingStorage(
             profileSetupCompleted: profileSetupCompleted,
             permissionsCompleted: permissionsCompleted,
           ),
       _profileSetupCompleted = profileSetupCompleted,
       _permissionsCompleted = permissionsCompleted,
       _loaded = true;

  final OnboardingStorage _storage;
  bool _profileSetupCompleted = false;
  bool _permissionsCompleted = false;
  bool _loaded = false;

  bool get profileSetupCompleted => _profileSetupCompleted;
  bool get permissionsCompleted => _permissionsCompleted;
  bool get isLoaded => _loaded;

  Future<void> load() async {
    _profileSetupCompleted = await _storage.hasCompletedProfileSetup();
    _permissionsCompleted = await _storage.hasCompletedPermissions();
    _loaded = true;
    notifyListeners();
  }

  Future<void> setCompletedProfileSetup(bool value) async {
    await _storage.setCompletedProfileSetup(value);
    if (_profileSetupCompleted == value && _loaded) {
      return;
    }
    _profileSetupCompleted = value;
    _loaded = true;
    notifyListeners();
  }

  Future<void> setCompletedPermissions(bool value) async {
    await _storage.setCompletedPermissions(value);
    if (_permissionsCompleted == value && _loaded) {
      return;
    }
    _permissionsCompleted = value;
    _loaded = true;
    notifyListeners();
  }

  /// Aligns local profile-setup gate with server `needsProfileSetup` on sign-in.
  Future<void> syncFromServerNeedsProfileSetup(bool needsProfileSetup) {
    return setCompletedProfileSetup(!needsProfileSetup);
  }
}
