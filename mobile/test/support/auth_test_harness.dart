import 'package:dealgo/features/onboarding/data/datasources/partner_requirements_client.dart';
import 'package:dealgo/features/identity/domain/passkey_platform.dart';
import 'package:dealgo/features/account_deletion/domain/account_deletion.dart';
import 'package:dealgo/features/account_settings/domain/account_settings.dart';
import 'package:dealgo/core/navigation/external_navigator.dart';
import 'package:dealgo/features/presence/data/datasources/presence_remote_datasource.dart';
import 'package:dealgo/features/onboarding/presentation/document_image_source.dart';
import 'package:dealgo/features/ride/domain/ride_share.dart';
import 'package:dealgo/features/support/domain/help_faq.dart';
import 'package:dealgo/app/dealgo_app.dart';
import 'package:dealgo/core/auth/post_auth_gate.dart';
import 'package:dealgo/core/auth/token_store.dart';
import 'package:dealgo/features/address_book/domain/repositories/address_book_repository.dart';
import 'package:dealgo/features/driver_history/domain/driver_history.dart';
import 'package:dealgo/features/support/domain/support_ticket.dart';
import 'package:dealgo/features/driver_card/domain/driver_card.dart';
import 'package:dealgo/core/location/location_service.dart';

import 'fake_location.dart';

import 'package:dealgo/features/live_location/domain/driver_location.dart';
import 'package:dealgo/features/pricing/domain/pricing.dart';
import 'package:dealgo/features/places/domain/place.dart';
import 'package:dealgo/features/merchant/domain/merchant_offers.dart';
import 'package:dealgo/features/rating/domain/service_rating.dart';
import 'package:dealgo/features/inbox/data/datasources/inbox_remote_datasource.dart';
import 'package:dealgo/features/chat/data/datasources/chat_remote_datasource.dart';
import 'package:dealgo/features/food/data/datasources/food_remote_datasource.dart';
import 'package:dealgo/features/merchant/data/datasources/merchant_orders_remote_datasource.dart';
import 'package:dealgo/features/identity/data/datasources/identity_remote_datasource.dart';
import 'package:dealgo/features/identity/domain/entities/user_profile.dart';
import 'package:dealgo/features/ride/data/datasources/ride_remote_datasource.dart';
import 'package:dealgo/features/identity/domain/auth_redirect.dart';
import 'package:dealgo/features/shell/presentation/customer_tab_bar.dart';
import 'package:dealgo/core/design_system/components/dealgo_tab_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_food_client.dart';
import 'fake_identity_client.dart';
import 'fake_ride_client.dart';

import 'package:dealgo/core/realtime/snapshot_realtime.dart';

PostAuthGate completedPostAuthGate() => PostAuthGate.seeded(
  profileSetupCompleted: true,
  permissionsCompleted: true,
);

PostAuthGate incompletePostAuthGate() => PostAuthGate.seeded();

Future<MemoryTokenStore> pumpDealGo(
  WidgetTester tester, {
  required IdentityClient client,
  TokenStore? tokenStore,
  FoodClient? foodClient,
  MerchantOrdersClient? merchantOrdersClient,
  RideClient? rideClient,
  PresenceClient? presenceClient,
  SnapshotRealtime? realtime,
  ChatClient? chatClient,
  InboxRemoteDataSource? inboxRemote,
  AddressBookRepository? addressBook,
  RatingRepository? ratings,
  MerchantOfferRepository? merchantOffers,
  DriverHistoryRepository? driverHistory,
  SupportRepository? support,
  AccountDeletionRepository? accountDeletion,
  AccountSettingsRepository? accountSettings,
  HelpFaqRepository? helpFaqs,
  RideShareRepository? rideShare,
  DocumentImageSource? documentImageSource,
  PartnerRequirementsSource? partnerRequirements,
  DriverCardRepository? driverCard,
  LocationService? locationOverride,
  PricingRepository? pricing,
  DriverLocationRepository? driverLocation,
  PlacesRepository? places,
  ExternalNavigator? externalNavigator,
  PostAuthGate? postAuthGate,
  bool completePostAuth = false,
  String initialLocation = AuthRoutes.login,
}) async {
  final store = tokenStore ?? MemoryTokenStore();
  await tester.pumpWidget(
    DealGoApp(
      identityClient: client,
      tokenStore: store,
      foodClient: foodClient ?? FakeFoodClient(),
      merchantOrdersClient: merchantOrdersClient,
      rideClient: rideClient ?? FakeRideClient(),
      presenceClient: presenceClient,
      realtime: realtime,
      chatClient: chatClient,
      inboxRemote: inboxRemote,
      addressBook: addressBook,
      ratings: ratings,
      merchantOffers: merchantOffers,
      driverHistory: driverHistory,
      support: support,
      accountDeletion: accountDeletion,
      accountSettings: accountSettings,
      helpFaqs: helpFaqs,
      rideShare: rideShare,
      documentImageSource: documentImageSource ?? FakeDocumentImageSource(),
      partnerRequirements:
          partnerRequirements ?? const FixedPartnerRequirements(),
      driverCard: driverCard,
      // Tests get a fixed GPS fix unless they pass their own (e.g. denied).
      locationOverride: locationOverride ?? FakeLocationService(),
      pricing: pricing,
      driverLocation: driverLocation,
      places: places,
      externalNavigator: externalNavigator,
      postAuthGate:
          postAuthGate ??
          (completePostAuth
              ? completedPostAuthGate()
              : incompletePostAuthGate()),
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
  MerchantOrdersClient? merchantOrdersClient,
  RideClient? rideClient,
  PresenceClient? presenceClient,
  SnapshotRealtime? realtime,
  ChatClient? chatClient,
  InboxRemoteDataSource? inboxRemote,
  AddressBookRepository? addressBook,
  RatingRepository? ratings,
  MerchantOfferRepository? merchantOffers,
  DriverHistoryRepository? driverHistory,
  SupportRepository? support,
  AccountDeletionRepository? accountDeletion,
  AccountSettingsRepository? accountSettings,
  HelpFaqRepository? helpFaqs,
  RideShareRepository? rideShare,
  DocumentImageSource? documentImageSource,
  PartnerRequirementsSource? partnerRequirements,
  DriverCardRepository? driverCard,
  LocationService? locationOverride,
  PricingRepository? pricing,
  DriverLocationRepository? driverLocation,
  PlacesRepository? places,
  ExternalNavigator? externalNavigator,
  PostAuthGate? postAuthGate,
  bool completePostAuth = true,
  String? initialLocation,
  PasskeyPlatform? passkeyPlatform,
  FakeIdentityClient? identityClient,
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
      identityClient: identityClient ?? FakeIdentityClient(profile: profile),
      tokenStore: store,
      passkeyPlatform: passkeyPlatform,
      foodClient: foodClient ?? FakeFoodClient(),
      merchantOrdersClient: merchantOrdersClient,
      rideClient: rideClient ?? FakeRideClient(),
      presenceClient: presenceClient,
      realtime: realtime,
      chatClient: chatClient,
      inboxRemote: inboxRemote,
      addressBook: addressBook,
      ratings: ratings,
      merchantOffers: merchantOffers,
      driverHistory: driverHistory,
      support: support,
      accountDeletion: accountDeletion,
      accountSettings: accountSettings,
      helpFaqs: helpFaqs,
      rideShare: rideShare,
      documentImageSource: documentImageSource ?? FakeDocumentImageSource(),
      partnerRequirements:
          partnerRequirements ?? const FixedPartnerRequirements(),
      driverCard: driverCard,
      // Tests get a fixed GPS fix unless they pass their own (e.g. denied).
      locationOverride: locationOverride ?? FakeLocationService(),
      pricing: pricing,
      driverLocation: driverLocation,
      places: places,
      externalNavigator: externalNavigator,
      postAuthGate:
          postAuthGate ?? (completePostAuth ? completedPostAuthGate() : null),
      initialLocation: initialLocation,
    ),
  );
  await tester.pumpAndSettle();
  return store;
}

Future<void> submitPhone(WidgetTester tester, String national) async {
  final phoneOption = find.byKey(const Key('auth-method-phone'));
  if (phoneOption.evaluate().isNotEmpty &&
      find.byKey(const Key('phone-field')).evaluate().isEmpty) {
    await tester.tap(phoneOption);
    await tester.pumpAndSettle();
  }
  await tester.enterText(find.byKey(const Key('phone-field')), national);
  await tester.pump();
  await tester.ensureVisible(find.text('Tiếp tục'));
  await tester.tap(find.text('Tiếp tục'));
  await tester.pumpAndSettle();
}

Future<void> submitOtp(WidgetTester tester, String code) async {
  final otpField = find.byKey(const Key('otp-field'));
  if (otpField.evaluate().isNotEmpty) {
    await tester.enterText(otpField, code);
    await tester.pump();
  } else {
    for (final digit in code.split('')) {
      final key = find.byKey(Key('otp-key-$digit'), skipOffstage: false);
      await tester.ensureVisible(key);
      await tester.tap(key, warnIfMissed: false);
      await tester.pump();
    }
  }
  // A full code auto-submits; tap "Xác nhận" only if the entry pane is still up.
  final confirm = find.text('Xác nhận');
  if (confirm.evaluate().isNotEmpty) {
    await tester.ensureVisible(confirm);
    await tester.tap(confirm, warnIfMissed: false);
  }
  await tester.pumpAndSettle();
}

Finder navLabel(String label) {
  // Customer shell uses CustomerTabBar; merchant/driver use DealGoTabBar.
  // Material NavigationBar is kept as a legacy fallback.
  for (final scope in [
    find.byType(CustomerTabBar),
    find.byType(DealGoTabBar),
    find.byType(NavigationBar),
  ]) {
    if (scope.evaluate().isNotEmpty) {
      return find.descendant(of: scope, matching: find.text(label));
    }
  }
  return find.descendant(
    of: find.byType(DealGoTabBar),
    matching: find.text(label),
  );
}

/// Cart/checkout tests: pick the delivery address via the place picker
/// (current GPS fix) so the server fare quote can load.
Future<void> chooseDeliveryAddress(WidgetTester tester) async {
  final pick = find.byKey(const Key('food-dropoff-pick'));
  await tester.ensureVisible(pick);
  await tester.tap(pick);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('place-current-location')));
  await tester.pumpAndSettle();
}
