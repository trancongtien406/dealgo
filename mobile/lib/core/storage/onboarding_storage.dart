import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class OnboardingStorage {
  Future<bool> hasSeenOnboarding();
  Future<void> setSeenOnboarding(bool value);
}

class SecureOnboardingStorage implements OnboardingStorage {
  SecureOnboardingStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'dealgo.hasSeenOnboarding';
  final FlutterSecureStorage _storage;

  @override
  Future<bool> hasSeenOnboarding() async {
    final value = await _storage.read(key: _key);
    return value == 'true';
  }

  @override
  Future<void> setSeenOnboarding(bool value) async {
    await _storage.write(key: _key, value: value ? 'true' : 'false');
  }
}

class MemoryOnboardingStorage implements OnboardingStorage {
  MemoryOnboardingStorage({bool initial = false}) : _seen = initial;

  bool _seen;

  @override
  Future<bool> hasSeenOnboarding() async => _seen;

  @override
  Future<void> setSeenOnboarding(bool value) async {
    _seen = value;
  }
}
