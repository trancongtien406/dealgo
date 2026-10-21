import 'package:dealgo/core/auth/token_store.dart';
import 'package:dealgo/core/network/dealgo_dio.dart';
import 'package:dio/dio.dart';

/// Shared Dio for unit tests that construct Dio*Client directly.
Dio createTestDealGoDio({TokenStore? tokenStore}) {
  return createDealGoDio(
    tokenStore: tokenStore ?? MemoryTokenStore(),
    onSessionRefreshed: (_) async {},
    onUnauthorized: () async {},
    enableLogging: false,
  );
}
