import 'dart:io' show Platform;
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages a unique, persistent device identifier across app launches and sessions.
class DeviceIdService {
  DeviceIdService({
    FlutterSecureStorage? secureStorage,
    SharedPreferences? sharedPreferences,
    String? initialDeviceId,
  })  : _secureStorage = secureStorage,
        _cachedDeviceId = initialDeviceId {
    _sharedPreferences = sharedPreferences;
  }

  static const String storageKey = 'dealgo.device_id';

  final FlutterSecureStorage? _secureStorage;
  SharedPreferences? _sharedPreferences;
  String? _cachedDeviceId;

  static bool get _isTesting {
    try {
      return Platform.environment.containsKey('FLUTTER_TEST');
    } catch (_) {
      return false;
    }
  }

  FlutterSecureStorage? get _effectiveSecureStorage =>
      _secureStorage ?? (_isTesting ? null : const FlutterSecureStorage());

  /// Returns the cached device ID synchronously if already loaded.
  String? get currentDeviceId => _cachedDeviceId;

  /// Retrieves the persistent device ID, generating and persisting a new UUID v4 if not found.
  Future<String> getDeviceId() async {
    if (_cachedDeviceId != null && _cachedDeviceId!.isNotEmpty) {
      return _cachedDeviceId!;
    }

    if (_isTesting && _secureStorage == null && _sharedPreferences == null) {
      final newId = _generateUuidV4();
      _cachedDeviceId = newId;
      return newId;
    }

    final storage = _effectiveSecureStorage;
    if (storage != null) {
      try {
        final secureId = await storage
            .read(key: storageKey)
            .timeout(const Duration(milliseconds: 200));
        if (secureId != null && secureId.trim().isNotEmpty) {
          _cachedDeviceId = secureId.trim();
          return _cachedDeviceId!;
        }
      } catch (_) {
        // Secure storage may fail in some environments (e.g. desktop/testing), fallback to SharedPreferences.
      }
    }

    try {
      _sharedPreferences ??= await SharedPreferences.getInstance();
      final prefId = _sharedPreferences?.getString(storageKey);
      if (prefId != null && prefId.trim().isNotEmpty) {
        _cachedDeviceId = prefId.trim();
        // Sync to secure storage in background
        _tryPersistSecure(_cachedDeviceId!);
        return _cachedDeviceId!;
      }
    } catch (_) {
      // SharedPreferences unavailable
    }

    // Generate new UUID v4
    final newId = _generateUuidV4();
    _cachedDeviceId = newId;

    await _persist(newId);
    return newId;
  }

  Future<void> _persist(String id) async {
    final storage = _effectiveSecureStorage;
    if (storage != null) {
      try {
        await storage
            .write(key: storageKey, value: id)
            .timeout(const Duration(milliseconds: 200));
      } catch (_) {}
    }

    try {
      _sharedPreferences ??= await SharedPreferences.getInstance();
      await _sharedPreferences?.setString(storageKey, id);
    } catch (_) {}
  }

  Future<void> _tryPersistSecure(String id) async {
    final storage = _effectiveSecureStorage;
    if (storage != null) {
      try {
        await storage
            .write(key: storageKey, value: id)
            .timeout(const Duration(milliseconds: 200));
      } catch (_) {}
    }
  }

  /// Generates a RFC 4122 compliant UUID v4 using cryptographically secure random numbers.
  static String _generateUuidV4() {
    final random = Random.secure();
    final bytes = Uint8List(16);
    for (var i = 0; i < 16; i++) {
      bytes[i] = random.nextInt(256);
    }
    // Set version to 4 (0100)
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    // Set variant to RFC 4122 (10xx)
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}';
  }
}
