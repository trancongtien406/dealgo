import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'token_store.dart';

class SecureTokenStore implements TokenStore {
  SecureTokenStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _accessKey = 'dealgo.accessToken';
  static const _refreshKey = 'dealgo.refreshToken';

  final FlutterSecureStorage _storage;

  @override
  Future<StoredTokens?> read() async {
    final accessToken = await _storage.read(key: _accessKey);
    final refreshToken = await _storage.read(key: _refreshKey);
    if (accessToken == null ||
        accessToken.isEmpty ||
        refreshToken == null ||
        refreshToken.isEmpty) {
      return null;
    }
    return StoredTokens(accessToken: accessToken, refreshToken: refreshToken);
  }

  @override
  Future<void> write(StoredTokens tokens) async {
    await _storage.write(key: _accessKey, value: tokens.accessToken);
    await _storage.write(key: _refreshKey, value: tokens.refreshToken);
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
  }
}
