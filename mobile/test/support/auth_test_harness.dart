import 'package:dealgo/app/dealgo_app.dart';
import 'package:dealgo/core/auth/token_store.dart';
import 'package:dealgo/features/chat/data/datasources/chat_remote_datasource.dart';
import 'package:dealgo/features/food/data/datasources/food_remote_datasource.dart';
import 'package:dealgo/features/identity/data/datasources/identity_remote_datasource.dart';
import 'package:dealgo/features/identity/domain/entities/user_profile.dart';
import 'package:dealgo/features/ride/data/datasources/ride_remote_datasource.dart';
import 'package:dealgo/features/identity/domain/auth_redirect.dart';
import 'package:dealgo/features/shell/presentation/customer_tab_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_food_client.dart';
import 'fake_identity_client.dart';
import 'fake_ride_client.dart';
import 'memory_token_store.dart';

Future<MemoryTokenStore> pumpDealGo(
  WidgetTester tester, {
  required IdentityClient client,
  TokenStore? tokenStore,
  FoodClient? foodClient,
  RideClient? rideClient,
  ChatClient? chatClient,
  String initialLocation = AuthRoutes.login,
}) async {
  final store = tokenStore ?? MemoryTokenStore();
  await tester.pumpWidget(
    DealGoApp(
      identityClient: client,
      tokenStore: store,
      foodClient: foodClient ?? FakeFoodClient(),
      rideClient: rideClient ?? FakeRideClient(),
      chatClient: chatClient,
      initialLocation: initialLocation,
    ),
  );
  await tester.pumpAndSettle();
  return store is MemoryTokenStore ? store : MemoryTokenStore();
}

Future<MemoryTokenStore> pumpSignedIn(
  WidgetTester tester, {
  required UserProfile profile,
  FoodClient? foodClient,
  RideClient? rideClient,
  ChatClient? chatClient,
}) async {
  final store = MemoryTokenStore();
  await store.write(
    const StoredTokens(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
    ),
  );
  await tester.pumpWidget(
    DealGoApp(
      identityClient: FakeIdentityClient(profile: profile),
      tokenStore: store,
      foodClient: foodClient ?? FakeFoodClient(),
      rideClient: rideClient ?? FakeRideClient(),
      chatClient: chatClient,
    ),
  );
  await tester.pumpAndSettle();
  return store;
}

Future<void> submitPhone(WidgetTester tester, String national) async {
  await tester.enterText(find.byKey(const Key('phone-field')), national);
  await tester.pump();
  await tester.ensureVisible(find.text('Tiếp tục'));
  await tester.tap(find.text('Tiếp tục'));
  await tester.pumpAndSettle();
}

Future<void> submitOtp(WidgetTester tester, String code) async {
  for (final digit in code.split('')) {
    final key = find.byKey(Key('otp-key-$digit'));
    await tester.ensureVisible(key);
    await tester.tap(key);
    await tester.pump();
  }
  final confirm = find.text('Xác minh và tiếp tục');
  await tester.ensureVisible(confirm);
  await tester.tap(confirm);
  await tester.pumpAndSettle();
}

Finder navLabel(String label) {
  final navigationBar = find.byType(NavigationBar);
  final scope = navigationBar.evaluate().isNotEmpty
      ? navigationBar
      : find.byType(CustomerTabBar);
  return find.descendant(of: scope, matching: find.text(label));
}
