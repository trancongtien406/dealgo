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
