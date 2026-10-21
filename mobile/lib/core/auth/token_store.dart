class StoredTokens {
  const StoredTokens({required this.accessToken, required this.refreshToken});

  final String accessToken;
  final String refreshToken;

  @override
  String toString() => 'StoredTokens()';
}

abstract interface class TokenStore {
  Future<StoredTokens?> read();

  Future<void> write(StoredTokens tokens);

  Future<void> clear();
}

class MemoryTokenStore implements TokenStore {
  StoredTokens? _tokens;

  MemoryTokenStore([this._tokens]);

  @override
  Future<StoredTokens?> read() async => _tokens;

  @override
  Future<void> write(StoredTokens tokens) async {
    _tokens = tokens;
  }

  @override
  Future<void> clear() async {
    _tokens = null;
  }
}
