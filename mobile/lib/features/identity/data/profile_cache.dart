import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../domain/entities/user_profile.dart';
import 'models/user_profile_model.dart';

/// Last `/v1/me` answer, so a relaunch without network can reopen the signed-in
/// shell instead of the login page. Never used to grant anything: the server
/// re-checks every request.
abstract interface class ProfileCache {
  Future<UserProfile?> read();
  Future<void> write(UserProfile profile);
  Future<void> clear();
}

class SecureProfileCache implements ProfileCache {
  SecureProfileCache({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'dealgo.profile.v1';

  final FlutterSecureStorage _storage;

  @override
  Future<UserProfile?> read() async {
    try {
      final raw = await _storage.read(key: _key);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, Object?>) return null;
      return UserProfileModel.fromJson(decoded).toEntity();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(UserProfile profile) async {
    try {
      await _storage.write(
        key: _key,
        value: jsonEncode(UserProfileModel.fromEntity(profile).toJson()),
      );
    } catch (_) {
      // Only costs the offline relaunch; sign-in itself is unaffected.
    }
  }

  @override
  Future<void> clear() async {
    try {
      await _storage.delete(key: _key);
    } catch (_) {}
  }
}

class MemoryProfileCache implements ProfileCache {
  MemoryProfileCache([this.value]);

  UserProfile? value;

  @override
  Future<UserProfile?> read() async => value;

  @override
  Future<void> write(UserProfile profile) async => value = profile;

  @override
  Future<void> clear() async => value = null;
}
