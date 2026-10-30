import '../core/mock/fake_ride_client.dart';
import '../core/drafts/draft_store.dart';
import '../core/drafts/text_draft.dart';

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:provider/provider.dart' show ChangeNotifierProvider;

import '../core/analytics/analytics_port.dart';
import '../core/analytics/console_analytics.dart';
import '../core/analytics/noop_analytics.dart';
import '../core/auth/secure_token_store.dart';
import '../core/auth/token_store.dart';
import '../core/config/app_env.dart';
import '../core/di/injection.dart';
import '../core/location/location_service.dart';
import '../core/navigation/external_navigator.dart';
import '../core/maps/create_map_port.dart';
import '../core/maps/map_port.dart';
import '../core/network/connectivity_service.dart';
import '../core/network/dealgo_dio.dart';
import '../features/driver/data/datasources/driver_active_job_client.dart';
import '../features/ride/data/datasources/customer_active_trip_client.dart';
import '../features/ride/data/datasources/ride_negotiation_clients.dart';
import '../features/ride/domain/negotiation/ride_negotiation_client.dart';
import '../features/parcel/data/dio_parcel_client.dart';
import '../features/parcel/data/fake_parcel_client.dart';
import '../features/parcel/domain/parcel_client.dart';
import '../features/ride/data/datasources/ride_stops_client_impl.dart';
import '../features/ride/domain/stops/ride_stops_client.dart';
import '../core/notifications/notification_router.dart';
import '../core/permissions/app_permission_service.dart';
import '../core/push/fake_push.dart';
import '../core/push/fcm_push.dart';
import '../core/push/push_port.dart';
import '../core/realtime/fake_snapshot_realtime.dart';
import '../core/realtime/snapshot_realtime.dart';
import '../core/realtime/snapshot_session_binder.dart';
import '../core/realtime/socket_snapshot_realtime.dart';
import '../features/activity/data/datasources/dio_history_remote_datasource.dart';
import '../features/activity/data/datasources/fake_history_client.dart';
import '../features/activity/data/datasources/history_remote_datasource.dart';
import '../features/activity/data/repositories/history_repository_impl.dart';
import '../features/activity/domain/repositories/history_repository.dart';
import '../features/activity/domain/usecases/list_food_history.dart';
import '../features/activity/domain/usecases/list_ride_history.dart';
import '../features/chat/data/datasources/chat_remote_datasource.dart';
import '../features/chat/data/datasources/dio_chat_remote_datasource.dart';
import '../features/chat/data/datasources/fake_chat_client.dart';
import '../features/chat/data/repositories/chat_repository_impl.dart';
import '../features/chat/domain/repositories/chat_repository.dart';
import '../features/chat/domain/usecases/list_food_order_chat_messages.dart';
import '../features/chat/domain/usecases/list_ride_chat_messages.dart';
import '../features/chat/domain/usecases/send_food_order_chat_message.dart';
import '../features/chat/domain/usecases/send_ride_chat_message.dart';
import '../features/driver/data/datasources/default_driver_jobs_client.dart';
import '../features/driver/data/datasources/driver_jobs_remote_datasource.dart';
import '../features/driver/data/repositories/driver_jobs_repository_impl.dart';
import '../features/driver/domain/repositories/driver_jobs_repository.dart';
import '../features/driver/domain/usecases/claim_food_order.dart';
import '../features/driver/domain/usecases/advance_driver_ride.dart';
import '../features/driver/domain/usecases/advance_food_delivery.dart';
import '../features/driver/domain/usecases/list_open_driver_rides.dart';
import '../features/driver/domain/usecases/list_ready_driver_orders.dart';
import '../features/driver/domain/usecases/submit_driver_ride_offer.dart';
import '../features/driver/presentation/cubit/driver_duty_cubit.dart';
import '../features/driver/presentation/cubit/driver_services_cubit.dart';
import '../features/food/data/datasources/dio_food_remote_datasource.dart';
import '../features/food/data/datasources/food_remote_datasource.dart';
import '../features/food/data/repositories/food_repository_impl.dart';
import '../features/food/domain/repositories/food_repository.dart';
import '../features/food/domain/usecases/cancel_food_order.dart';
import '../features/food/domain/usecases/get_food_order.dart';
import '../features/promotion/data/datasources/promotion_remote_datasource.dart';
import '../features/promotion/data/repositories/promotion_repository_impl.dart';
import '../features/promotion/domain/usecases/list_available_vouchers.dart';
import '../features/promotion/domain/usecases/validate_voucher.dart';
import '../features/support/data/help_faq_remote_datasource.dart';
import '../features/support/domain/help_faq.dart';
import '../features/ride/data/ride_share_remote_datasource.dart';
import '../features/ride/domain/ride_share.dart';
import '../features/address_book/data/datasources/address_book_remote_datasource.dart';
import '../features/address_book/domain/repositories/address_book_repository.dart';
import '../features/driver_history/data/driver_history_remote_datasource.dart';
import '../features/account_deletion/data/account_deletion_remote_datasource.dart';
import '../features/account_deletion/domain/account_deletion.dart';
import '../features/account_settings/data/account_settings_remote_datasource.dart';
import '../features/account_settings/domain/account_settings.dart';
import '../features/support/data/support_remote_datasource.dart';
import '../features/support/domain/support_ticket.dart';
import '../features/driver_card/domain/driver_card.dart';
import '../features/pricing/domain/pricing.dart';
import '../features/food/data/food_category_remote_datasource.dart';
import '../features/food/domain/entities/food_category.dart';
import '../features/food/presentation/food_categories_store.dart';
import '../features/home_banner/data/home_banner_remote_datasource.dart';
import '../features/home_banner/data/home_banner_tracker.dart';
import '../features/home_banner/domain/home_banner.dart';
import '../features/places/data/places_remote_datasource.dart';
import '../features/live_location/data/driver_location_remote_datasource.dart';
import '../features/live_location/domain/map_routing.dart';
import '../features/live_location/data/map_routing_remote_datasource.dart';
import '../features/live_location/domain/driver_location.dart';
import '../features/live_location/presentation/driver_location_reporter.dart';
import '../features/pricing/data/pricing_remote_datasource.dart';
import '../features/driver_card/data/driver_card_remote_datasource.dart';
import '../features/places/domain/place.dart';
import '../features/driver_history/domain/driver_history.dart';
import '../features/rating/data/rating_remote_datasource.dart';
import '../features/rating/domain/service_rating.dart';
import '../features/inbox/data/datasources/inbox_remote_datasource.dart';
import '../features/inbox/data/repositories/inbox_repository_impl.dart';
import '../features/inbox/domain/usecases/inbox_usecases.dart';
import '../features/food/domain/usecases/get_food_store.dart';
import '../features/food/domain/usecases/list_food_stores.dart';
import '../features/food/domain/usecases/list_ready_food_orders.dart';
import '../features/food/domain/usecases/place_food_order.dart';
import '../features/food/presentation/cubit/food_cart_cubit.dart';
import '../features/food/presentation/food_cart_draft.dart';
import '../features/identity/presentation/auth_methods_store.dart';
import '../features/identity/data/datasources/dio_identity_remote_datasource.dart';
import '../features/identity/data/datasources/identity_remote_datasource.dart';
import '../features/identity/data/repositories/identity_repository_impl.dart';
import '../features/identity/domain/entities/auth_state.dart';
import '../features/identity/domain/repositories/identity_repository.dart';
import '../features/identity/data/device_passkey_platform.dart';
import '../features/identity/domain/passkey_platform.dart';
import '../features/identity/domain/usecases/create_phone_challenge.dart';
import '../features/identity/domain/usecases/fetch_me.dart';
import '../features/identity/domain/usecases/get_auth_methods.dart';
import '../features/identity/domain/usecases/refresh_session.dart';
import '../features/identity/domain/usecases/verify_phone_challenge.dart';
import '../features/identity/presentation/cubit/auth_cubit.dart';
import '../features/merchant/data/datasources/default_merchant_orders_client.dart';
import '../features/merchant/data/datasources/merchant_orders_remote_datasource.dart';
import '../features/merchant/data/repositories/merchant_orders_repository_impl.dart';
import '../features/merchant/domain/repositories/merchant_orders_repository.dart';
import '../features/merchant/domain/usecases/accept_merchant_order.dart';
import '../features/merchant/domain/usecases/reject_merchant_order.dart';
import '../features/merchant/domain/usecases/create_merchant_catalog_item.dart';
import '../features/merchant/domain/usecases/update_store_accept_settings.dart';
import '../features/merchant/domain/usecases/update_store_hours.dart';
import '../features/merchant/domain/usecases/update_store_location.dart';
import '../features/merchant/domain/usecases/update_store_service_mode.dart';
import '../features/merchant/domain/usecases/get_merchant_catalog.dart';
import '../features/merchant/domain/usecases/get_merchant_order.dart';
import '../features/merchant/domain/usecases/list_merchant_order_queue.dart';
import '../features/merchant/domain/usecases/mark_merchant_order_ready.dart';
import '../features/merchant/domain/usecases/replace_merchant_item_options.dart';
import '../features/merchant/domain/usecases/set_merchant_item_availability.dart';
import '../features/onboarding/data/datasources/dio_partner_applications_remote_datasource.dart';
import '../features/onboarding/data/datasources/fake_partner_applications_client.dart';
import '../features/onboarding/data/ocr/mlkit_document_text_reader.dart';
import '../features/onboarding/data/datasources/partner_requirements_client.dart';
import '../features/onboarding/data/datasources/partner_applications_remote_datasource.dart';
import '../features/onboarding/data/repositories/partner_applications_repository_impl.dart';
import '../features/onboarding/domain/repositories/partner_applications_repository.dart';
import '../features/onboarding/domain/usecases/get_my_partner_application.dart';
import '../features/onboarding/domain/usecases/list_my_partner_applications.dart';
import '../features/onboarding/domain/usecases/submit_partner_application.dart';
import '../features/onboarding/presentation/cubit/driver_kyc_cubit.dart';
import '../features/onboarding/presentation/cubit/merchant_kyb_cubit.dart';
import '../features/onboarding/presentation/document_image_source.dart';
import '../features/onboarding/presentation/capture/smart_capture.dart';
import '../features/merchant/data/datasources/dio_merchant_stats_remote_datasource.dart';
import '../features/merchant/data/datasources/fake_merchant_stats_remote_datasource.dart';
import '../features/merchant/data/datasources/merchant_offers_remote_datasource.dart';
import '../features/merchant/domain/merchant_offers.dart';
import '../features/merchant/domain/merchant_stats.dart';
import '../features/presence/data/datasources/dio_presence_remote_datasource.dart';
import '../features/presence/data/datasources/fake_presence_client.dart';
import '../features/presence/data/datasources/presence_remote_datasource.dart';
import '../features/presence/data/repositories/presence_repository_impl.dart';
import '../features/presence/domain/repositories/presence_repository.dart';
import '../features/presence/domain/usecases/set_presence.dart';
import '../features/ride/data/datasources/dio_ride_remote_datasource.dart';
import '../features/ride/data/datasources/ride_remote_datasource.dart';
import '../features/ride/data/repositories/ride_repository_impl.dart';
import '../features/ride/domain/repositories/ride_repository.dart';
import '../features/ride/domain/usecases/cancel_ride.dart';
import '../features/ride/domain/usecases/create_ride.dart';
import '../features/ride/domain/usecases/get_ride.dart';
import '../features/ride/domain/usecases/list_open_rides.dart';
import '../features/ride/domain/usecases/select_ride_offer.dart';
import '../features/ride/domain/usecases/submit_ride_offer.dart';
import '../features/ride/presentation/cubit/ride_destination.dart';
import '../features/ride/presentation/cubit/ride_vehicle_pref.dart';
import '../features/ride/presentation/cubit/ride_session.dart';
import '../features/voice/data/native/callkit_native_call_ui.dart';
import '../features/voice/domain/ports/native_call_ui.dart';
import '../features/voice/data/datasources/dio_voice_remote_datasource.dart';
import '../features/voice/data/datasources/fake_voice_client.dart';
import '../features/voice/data/datasources/voice_remote_datasource.dart';
import '../features/voice/data/repositories/voice_repository_impl.dart';
import '../features/voice/domain/repositories/voice_repository.dart';
import '../features/voice/data/media/fake_voice_media_engine.dart';
import '../features/voice/data/media/livekit_voice_media_engine.dart';
import '../features/voice/domain/ports/voice_media_engine.dart';
import '../features/voice/domain/usecases/answer_voice_call.dart';
import '../features/voice/domain/usecases/end_voice_call.dart';
import '../features/voice/domain/usecases/get_voice_call.dart';
import '../features/voice/domain/usecases/get_voice_call_config.dart';
import '../features/voice/domain/usecases/start_voice_call.dart';
import '../features/voice/presentation/cubit/voice_call_cubit.dart';

/// Unsent form drafts (KYC/KYB, support, reviews…) that survive an app kill.
final DraftStore _formDrafts = SecureDraftStore();

class DealGoDependencies {
  DealGoDependencies._(this._locator) {
    FormDrafts.store = _formDrafts;
    FormDrafts.owner = _signedInUserId;
  }

  final GetIt _locator;

  TokenStore get tokenStore => _locator<TokenStore>();
  Dio get dio => _locator<Dio>();
  DriverActiveJobSource get driverActiveJob =>
      _locator<DriverActiveJobSource>();
  CustomerActiveTripSource get customerActiveTrip =>
      _locator<CustomerActiveTripSource>();
  IdentityClient get identityClient => _locator<IdentityClient>();
  IdentityRepository get identityRepository => _locator<IdentityRepository>();
  FoodClient get foodClient => _locator<FoodClient>();
  FoodRepository get foodRepository => _locator<FoodRepository>();
  ListFoodStores get listFoodStores => _locator<ListFoodStores>();
  GetFoodStore get getFoodStore => _locator<GetFoodStore>();
  PlaceFoodOrder get placeFoodOrder => _locator<PlaceFoodOrder>();
  GetFoodOrder get getFoodOrder => _locator<GetFoodOrder>();
  ListReadyFoodOrders get listReadyFoodOrders =>
      _locator<ListReadyFoodOrders>();
  RideClient get rideClient => _locator<RideClient>();
  RideRepository get rideRepository => _locator<RideRepository>();
  CreateRide get createRide => _locator<CreateRide>();
  GetRide get getRide => _locator<GetRide>();
  ListOpenRides get listOpenRides => _locator<ListOpenRides>();
  SelectRideOffer get selectRideOffer => _locator<SelectRideOffer>();
  CancelRide get cancelRide => _locator<CancelRide>();
  SubmitRideOffer get submitRideOffer => _locator<SubmitRideOffer>();
  SnapshotSessionBinder get snapshotSessionBinder =>
      _locator<SnapshotSessionBinder>();
  DriverJobsClient get driverJobsClient => _locator<DriverJobsClient>();
  DriverJobsRepository get driverJobsRepository =>
      _locator<DriverJobsRepository>();
  MerchantOrdersClient get merchantOrdersClient =>
      _locator<MerchantOrdersClient>();
  MerchantOrdersRepository get merchantOrdersRepository =>
      _locator<MerchantOrdersRepository>();
  PartnerApplicationsClient get partnerApplicationsClient =>
      _locator<PartnerApplicationsClient>();
  PartnerApplicationsRepository get partnerApplicationsRepository =>
      _locator<PartnerApplicationsRepository>();
  ChatClient get chatClient => _locator<ChatClient>();
  ChatRepository get chatRepository => _locator<ChatRepository>();
  VoiceClient get voiceClient => _locator<VoiceClient>();
  VoiceRepository get voiceRepository => _locator<VoiceRepository>();
  VoiceCallCubit get voiceCallCubit => _locator<VoiceCallCubit>();
  PresenceClient get presenceClient => _locator<PresenceClient>();
  PresenceRepository get presenceRepository => _locator<PresenceRepository>();
  HistoryClient get historyClient => _locator<HistoryClient>();
  HistoryRepository get historyRepository => _locator<HistoryRepository>();
  PushPort get push => _locator<PushPort>();

  /// Map adapter for the current Admin token (see [MapPortSource]).
  MapPort get mapPort => _locator<MapPortSource>().current;
  ExternalNavigator get externalNavigator => _locator<ExternalNavigator>();
  SnapshotRealtime get realtime => _locator<SnapshotRealtime>();
  RideNegotiationClient get rideNegotiation =>
      _locator<RideNegotiationClient>();
  RideStopsClient get rideStops => _locator<RideStopsClient>();
  ParcelClient get parcel => _locator<ParcelClient>();
  AnalyticsPort get analytics => _locator<AnalyticsPort>();
  NotificationRouter get notificationRouter => _locator<NotificationRouter>();
  AuthCubit get authCubit => _locator<AuthCubit>();
  ConnectivityService get connectivity => _locator<ConnectivityService>();
  AppPermissionService get permissions => _locator<AppPermissionService>();
  LocationService get location => _locator<LocationService>();
  CreatePhoneChallenge get createPhoneChallenge =>
      _locator<CreatePhoneChallenge>();
  VerifyPhoneChallenge get verifyPhoneChallenge =>
      _locator<VerifyPhoneChallenge>();
  AuthMethodsStore get authMethods => _locator<AuthMethodsStore>();
  FoodCategoriesStore get foodCategories => _locator<FoodCategoriesStore>();

  /// Composition root: builds an isolated GetIt graph and mirrors it to [getIt].
  static DealGoDependencies create({
    IdentityClient? identityClient,
    TokenStore? tokenStore,
    PasskeyPlatform? passkeyPlatform,
    FoodClient? foodClient,
    RideClient? rideClient,
    RideStopsClient? rideStopsClient,
    DriverJobsClient? driverJobsClient,
    MerchantOrdersClient? merchantOrdersClient,
    PartnerApplicationsClient? partnerApplicationsClient,
    ChatClient? chatClient,
    VoiceClient? voiceClient,
    PresenceClient? presenceClient,
    HistoryClient? historyClient,
    PushPort? push,
    MapPort? mapPort,
    ExternalNavigator? externalNavigator,
    SnapshotRealtime? realtime,
    AnalyticsPort? analytics,
    NotificationRouter? notificationRouter,
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
    DriverCardRepository? driverCard,
    LocationService? locationOverride,
    PricingRepository? pricing,
    PlacesRepository? places,
    DocumentImageSource? documentImageSource,
    PartnerRequirementsSource? partnerRequirements,
    MerchantStatsRepository? merchantStats,
    DriverLocationRepository? driverLocation,
    AuthMethodsCache? authMethodsCache,
  }) {
    final locator = GetIt.asNewInstance();
    _registerGraph(
      locator,
      identityClient: identityClient,
      tokenStore: tokenStore,
      passkeyPlatform: passkeyPlatform,
      authMethodsCache: authMethodsCache,
      foodClient: foodClient,
      rideClient: rideClient,
      rideStopsClient: rideStopsClient,
      driverJobsClient: driverJobsClient,
      merchantOrdersClient: merchantOrdersClient,
      partnerApplicationsClient: partnerApplicationsClient,
      chatClient: chatClient,
      voiceClient: voiceClient,
      presenceClient: presenceClient,
      historyClient: historyClient,
      push: push,
      mapPort: mapPort,
      externalNavigator: externalNavigator,
      realtime: realtime,
      analytics: analytics,
      notificationRouter: notificationRouter,
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
      driverCard: driverCard,
      locationOverride: locationOverride,
      pricing: pricing,
      places: places,
      documentImageSource: documentImageSource,
      partnerRequirements: partnerRequirements,
      merchantStats: merchantStats,
      driverLocation: driverLocation,
    );

    // Process-wide locator for `getIt<T>()` outside the widget tree.
    getIt.allowReassignment = true;
    _ensureLeafServices(getIt);
    _registerGraph(
      getIt,
      identityClient: identityClient,
      tokenStore: tokenStore,
      passkeyPlatform: passkeyPlatform,
      authMethodsCache: authMethodsCache,
      foodClient: foodClient,
      rideClient: rideClient,
      rideStopsClient: rideStopsClient,
      driverJobsClient: driverJobsClient,
      merchantOrdersClient: merchantOrdersClient,
      partnerApplicationsClient: partnerApplicationsClient,
      chatClient: chatClient,
      voiceClient: voiceClient,
      presenceClient: presenceClient,
      historyClient: historyClient,
      push: push,
      mapPort: mapPort,
      externalNavigator: externalNavigator,
      realtime: realtime,
      analytics: analytics,
      notificationRouter: notificationRouter,
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
      driverCard: driverCard,
      locationOverride: locationOverride,
      pricing: pricing,
      places: places,
      documentImageSource: documentImageSource,
      partnerRequirements: partnerRequirements,
      merchantStats: merchantStats,
      driverLocation: driverLocation,
      skipLeafServices: true,
    );

    return DealGoDependencies._(locator);
  }

  static void _ensureLeafServices(GetIt locator) {
    if (!locator.isRegistered<ConnectivityService>() ||
        !locator.isRegistered<AppPermissionService>() ||
        !locator.isRegistered<LocationService>()) {
      // Generated `@lazySingleton` registrations from injectable.
      try {
        initInjectableOn(locator);
      } catch (_) {
        // Fall through to manual registration when config is unavailable.
      }
    }
    if (!locator.isRegistered<ConnectivityService>()) {
      locator.registerLazySingleton<ConnectivityService>(
        ConnectivityService.new,
      );
    }
    if (!locator.isRegistered<AppPermissionService>()) {
      locator.registerLazySingleton<AppPermissionService>(
        AppPermissionService.new,
      );
    }
    if (!locator.isRegistered<LocationService>()) {
      locator.registerLazySingleton<LocationService>(
        () => LocationService(locator<AppPermissionService>()),
      );
    }
  }

  static void _registerGraph(
    GetIt locator, {
    bool skipLeafServices = false,
    IdentityClient? identityClient,
    TokenStore? tokenStore,
    AuthMethodsCache? authMethodsCache,
    PasskeyPlatform? passkeyPlatform,
    FoodClient? foodClient,
    RideClient? rideClient,
    RideStopsClient? rideStopsClient,
    DriverJobsClient? driverJobsClient,
    MerchantOrdersClient? merchantOrdersClient,
    PartnerApplicationsClient? partnerApplicationsClient,
    ChatClient? chatClient,
    VoiceClient? voiceClient,
    PresenceClient? presenceClient,
    HistoryClient? historyClient,
    PushPort? push,
    MapPort? mapPort,
    ExternalNavigator? externalNavigator,
    SnapshotRealtime? realtime,
    AnalyticsPort? analytics,
    NotificationRouter? notificationRouter,
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
    DriverCardRepository? driverCard,
    LocationService? locationOverride,
    PricingRepository? pricing,
    PlacesRepository? places,
    DocumentImageSource? documentImageSource,
    PartnerRequirementsSource? partnerRequirements,
    MerchantStatsRepository? merchantStats,
    DriverLocationRepository? driverLocation,
  }) {
    if (locationOverride != null) {
      if (locator.isRegistered<LocationService>()) {
        locator.unregister<LocationService>();
      }
      locator.registerSingleton<LocationService>(locationOverride);
    }
    final tokens = tokenStore ?? SecureTokenStore();
    late final AuthCubit auth;
    final sessionRefresher = SessionRefresher();
    final dio = createDealGoDio(
      tokenStore: tokens,
      sessionRefresher: sessionRefresher,
      onSessionRefreshed: (next) => auth.applyRefreshedTokens(next),
      onUnauthorized: () => auth.signOut(revokeRemote: false),
    );

    final useOverrides =
        identityClient != null || foodClient != null || rideClient != null;

    // System call screen (CallKit / ConnectionService); never in tests, mock
    // builds or on the web.
    final NativeCallUi nativeCallUi = useOverrides || useMockData || kIsWeb
        ? const NoopNativeCallUi()
        : CallkitNativeCallUi();

    final identity = identityClient ?? DioIdentityRemoteDataSource(dio: dio);
    final food = foodClient ?? DioFoodRemoteDataSource(dio: dio);
    final rides = rideClient ?? DioRideRemoteDataSource(dio: dio);
    final identityRepository = IdentityRepositoryImpl(identity);
    final foodRepository = FoodRepositoryImpl(food);
    final rideRepository = RideRepositoryImpl(rides);
    final fetchMe = FetchMe(identityRepository);
    final passkeys =
        passkeyPlatform ??
        (useOverrides || useMockData
            ? FakePasskeyPlatform()
            : DevicePasskeyPlatform());
    auth = AuthCubit(
      fetchMe: fetchMe,
      tokens: tokens,
      identityRepository: identityRepository,
    );

    late final PartnerApplicationsClient partners;
    late final ChatClient chat;
    late final VoiceClient voice;
    late final PresenceClient presence;
    late final HistoryClient history;
    late final PushPort pushPort;
    late final SnapshotRealtime snapshot;
    late final AnalyticsPort analyticsPort;

    if (useOverrides) {
      partners = partnerApplicationsClient ?? FakePartnerApplicationsClient();
      chat = chatClient ?? FakeChatClient();
      voice = voiceClient ?? FakeVoiceClient();
      presence = presenceClient ?? FakePresenceClient();
      history = historyClient ?? FakeHistoryClient();
      pushPort = push ?? FakePush();
      snapshot = realtime ?? FakeSnapshotRealtime();
      analyticsPort = analytics ?? const NoopAnalytics();
    } else {
      partners =
          partnerApplicationsClient ??
          (useMockData
              ? FakePartnerApplicationsClient()
              : DioPartnerApplicationsClient(dio: dio));
      chat =
          chatClient ??
          (useMockData ? FakeChatClient() : DioChatClient(dio: dio));
      voice =
          voiceClient ??
          (useMockData ? FakeVoiceClient() : DioVoiceClient(dio: dio));
      presence =
          presenceClient ??
          (useMockData ? FakePresenceClient() : DioPresenceClient(dio: dio));
      history =
          historyClient ??
          (useMockData ? FakeHistoryClient() : DioHistoryClient(dio: dio));
      pushPort =
          push ??
          (useMockData
              ? FakePush()
              : FcmPush(
                  dio: dio,
                  voipToken: nativeCallUi.voipPushToken,
                  voipTokenChanges: nativeCallUi.voipTokenChanges,
                  prepareCalls: nativeCallUi.ensureFullScreenCalls,
                ));
      snapshot =
          realtime ??
          (useMockData
              ? FakeSnapshotRealtime()
              : SocketSnapshotRealtime(
                  readAccessToken: () async =>
                      (await tokens.read())?.accessToken,
                  refreshAccessToken: () => refreshRealtimeToken(
                    sessionRefresher,
                    () => auth.signOut(revokeRemote: false),
                  ),
                ));
      analyticsPort =
          analytics ??
          (useMockData
              ? const NoopAnalytics()
              : (kDebugMode
                    ? const ConsoleAnalytics()
                    : const NoopAnalytics()));
    }

    final promotionRepository = PromotionRepositoryImpl(
      useOverrides || useMockData
          ? FakePromotionRemoteDataSource()
          : DioPromotionRemoteDataSource(dio: dio),
    );
    final addressBookRepository =
        addressBook ??
        (useOverrides
            ? FakeAddressBookRemoteDataSource()
            : useMockData
            ? FakeAddressBookRemoteDataSource(
                seed: FakeAddressBookRemoteDataSource.sample(),
              )
            : DioAddressBookRemoteDataSource(dio: dio));
    final ratingRepository =
        ratings ??
        (useOverrides || useMockData
            ? FakeRatingRemoteDataSource()
            : DioRatingRemoteDataSource(dio: dio));
    final driverHistoryRepository =
        driverHistory ??
        (useOverrides
            ? FakeDriverHistoryRemoteDataSource()
            : useMockData
            ? FakeDriverHistoryRemoteDataSource(
                seed: FakeDriverHistoryRemoteDataSource.sample(DateTime.now()),
              )
            : DioDriverHistoryRemoteDataSource(dio: dio));
    final placesRepository =
        places ??
        (useOverrides
            ? FakePlacesRemoteDataSource()
            : useMockData
            ? FakePlacesRemoteDataSource(
                catalog: FakePlacesRemoteDataSource.sampleCatalog,
                recent: FakePlacesRemoteDataSource.sampleRecent,
              )
            : DioPlacesRemoteDataSource(dio: dio));
    final HomeBannerRepository homeBannerRepository =
        useOverrides || useMockData
        ? FakeHomeBannerRepository()
        : DioHomeBannerRepository(dio: dio);
    final FoodCategoryRepository foodCategoryRepository =
        useOverrides || useMockData
        ? FakeFoodCategoryRepository()
        : DioFoodCategoryRepository(dio: dio);
    final pricingRepository =
        pricing ??
        (useOverrides || useMockData
            ? FakePricingRemoteDataSource()
            : DioPricingRemoteDataSource(dio: dio));
    final driverCardRepository =
        driverCard ??
        (useOverrides || useMockData
            ? FakeDriverCardRemoteDataSource()
            : DioDriverCardRemoteDataSource(dio: dio));
    final merchantStatsRepository =
        merchantStats ??
        (useOverrides || useMockData
            ? FakeMerchantStatsRemoteDataSource()
            : DioMerchantStatsRemoteDataSource(dio: dio));
    final driverLocationRepository =
        driverLocation ??
        (useOverrides || useMockData
            ? FakeDriverLocationRemoteDataSource()
            : DioDriverLocationRemoteDataSource(dio: dio));
    final mapRoutingRepository = useOverrides || useMockData
        ? FakeMapRoutingRemoteDataSource()
        : DioMapRoutingRemoteDataSource(dio: dio);
    final helpFaqRepository =
        helpFaqs ??
        (useOverrides || useMockData
            ? FakeHelpFaqRepository()
            : DioHelpFaqRemoteDataSource(dio: dio));
    final rideShareRepository =
        rideShare ??
        (useOverrides || useMockData
            ? FakeRideShareRepository()
            : DioRideShareRemoteDataSource(dio: dio));
    final supportRepository =
        support ??
        (useOverrides || useMockData
            ? FakeSupportRepository()
            : DioSupportRemoteDataSource(dio: dio));
    final accountDeletionRepository =
        accountDeletion ??
        (useOverrides || useMockData
            ? FakeAccountDeletionRepository()
            : DioAccountDeletionRemoteDataSource(dio: dio));
    final accountSettingsRepository =
        accountSettings ??
        (useOverrides || useMockData
            ? FakeAccountSettingsRepository()
            : DioAccountSettingsRemoteDataSource(dio: dio));
    // Raise fare / decline / withdraw / driver cancel / no-show /
    // customer rating / food release.
    final RideNegotiationClient rideNegotiation = useOverrides || useMockData
        ? FakeRideNegotiationClient()
        : DioRideNegotiationClient(dio: dio);
    final RideStopsClient rideStops =
        rideStopsClient ??
        (useOverrides || useMockData
            ? FakeRideStopsClient()
            : DioRideStopsClient(dio: dio));
    // DEC-PROD-071 goods delivery: same Dio + auth stack as Ride.
    final ParcelClient parcel = useOverrides || useMockData
        ? FakeParcelClient()
        : DioParcelClient(dio: dio);
    if (parcel is FakeParcelClient && rides is FakeRideClient) {
      parcel.bridgeInto(rides);
    }
    final inboxRepository = InboxRepositoryImpl(
      inboxRemote ??
          (useOverrides
              ? FakeInboxRemoteDataSource(seed: const [])
              : useMockData
              ? FakeInboxRemoteDataSource()
              : DioInboxRemoteDataSource(dio: dio)),
    );
    final driverJobs =
        driverJobsClient ?? DefaultDriverJobsClient(rides: rides, food: food);
    final merchantOrders =
        merchantOrdersClient ?? DefaultMerchantOrdersClient(food: food);
    final driverJobsRepository = DriverJobsRepositoryImpl(driverJobs);
    final merchantOrdersRepository = MerchantOrdersRepositoryImpl(
      merchantOrders,
    );
    final partnerApplicationsRepository = PartnerApplicationsRepositoryImpl(
      partners,
    );
    final chatRepository = ChatRepositoryImpl(chat);
    final voiceRepository = VoiceRepositoryImpl(voice);
    final presenceRepository = PresenceRepositoryImpl(presence);
    final historyRepository = HistoryRepositoryImpl(history);
    final maps = MapPortSource(mapPort);
    final notifications = notificationRouter ?? NotificationRouter();

    void put<T extends Object>(T value) {
      if (locator.isRegistered<T>()) {
        locator.unregister<T>();
      }
      locator.registerSingleton<T>(value);
    }

    put<TokenStore>(tokens);
    put<Dio>(dio);
    put<DriverActiveJobSource>(
      useOverrides || useMockData
          ? FakeDriverActiveJobSource()
          : DioDriverActiveJobSource(dio: dio),
    );
    put<CustomerActiveTripSource>(
      useOverrides || useMockData
          ? FakeCustomerActiveTripSource()
          : DioCustomerActiveTripSource(dio: dio),
    );
    put<IdentityRemoteDataSource>(identity);
    put<IdentityRepository>(identityRepository);
    put<PasskeyPlatform>(passkeys);
    put<FetchMe>(fetchMe);
    put<CreatePhoneChallenge>(CreatePhoneChallenge(identityRepository));
    put<VerifyPhoneChallenge>(VerifyPhoneChallenge(identityRepository));
    put<AuthMethodsStore>(
      AuthMethodsStore(
        GetAuthMethods(identityRepository).call,
        cache:
            authMethodsCache ??
            (useOverrides
                ? MemoryAuthMethodsCache()
                : const PrefsAuthMethodsCache()),
      ),
    );
    put<FoodCategoriesStore>(
      FoodCategoriesStore(
        foodCategoryRepository.list,
        cache: useOverrides
            ? MemoryFoodCategoriesCache()
            : const PrefsFoodCategoriesCache(),
      ),
    );
    put<RefreshSession>(RefreshSession(identityRepository));
    put<FoodClient>(food);
    put<FoodRemoteDataSource>(food);
    put<FoodRepository>(foodRepository);
    put<ListFoodStores>(ListFoodStores(foodRepository));
    put<GetFoodStore>(GetFoodStore(foodRepository));
    put<PlaceFoodOrder>(PlaceFoodOrder(foodRepository));
    put<GetFoodOrder>(GetFoodOrder(foodRepository));
    put<CancelFoodOrder>(CancelFoodOrder(foodRepository));
    put<ValidateVoucher>(ValidateVoucher(promotionRepository));
    put<ListAvailableVouchers>(ListAvailableVouchers(promotionRepository));
    put<AddressBookRepository>(addressBookRepository);
    put<RatingRepository>(ratingRepository);
    put<MerchantOfferRepository>(
      merchantOffers ??
          (useOverrides
              ? FakeMerchantOfferRepository()
              : useMockData
              ? FakeMerchantOfferRepository.sample()
              : DioMerchantOfferRemoteDataSource(dio: dio)),
    );
    put<MerchantStatsRepository>(merchantStatsRepository);
    put<DriverHistoryRepository>(driverHistoryRepository);
    put<PlacesRepository>(placesRepository);
    put<HomeBannerRepository>(homeBannerRepository);
    put<HomeBannerTracker>(
      HomeBannerTracker(
        repository: homeBannerRepository,
        analytics: analyticsPort,
      ),
    );
    put<PricingRepository>(pricingRepository);
    put<DriverLocationRepository>(driverLocationRepository);
    put<MapRoutingRepository>(mapRoutingRepository);
    put<DriverCardRepository>(driverCardRepository);
    put<SupportRepository>(supportRepository);
    put<AccountDeletionRepository>(accountDeletionRepository);
    put<AccountSettingsRepository>(accountSettingsRepository);
    put<RideNegotiationClient>(rideNegotiation);
    put<RideStopsClient>(rideStops);
    put<ParcelClient>(parcel);
    put<HelpFaqRepository>(helpFaqRepository);
    put<RideShareRepository>(rideShareRepository);
    put<ListInboxNotifications>(ListInboxNotifications(inboxRepository));
    put<MarkInboxNotificationRead>(MarkInboxNotificationRead(inboxRepository));
    put<MarkAllInboxNotificationsRead>(
      MarkAllInboxNotificationsRead(inboxRepository),
    );
    put<ListReadyFoodOrders>(ListReadyFoodOrders(foodRepository));
    put<RideClient>(rides);
    put<RideRemoteDataSource>(rides);
    put<RideRepository>(rideRepository);
    put<CreateRide>(CreateRide(rideRepository));
    put<GetRide>(GetRide(rideRepository));
    put<ListOpenRides>(ListOpenRides(rideRepository));
    put<SelectRideOffer>(SelectRideOffer(rideRepository));
    put<CancelRide>(CancelRide(rideRepository));
    put<SubmitRideOffer>(SubmitRideOffer(rideRepository));
    put<SnapshotSessionBinder>(
      SnapshotSessionBinder(authCubit: auth, realtime: snapshot),
    );
    put<DriverJobsClient>(driverJobs);
    put<DriverJobsRepository>(driverJobsRepository);
    put<ListOpenDriverRides>(ListOpenDriverRides(driverJobsRepository));
    put<ListReadyDriverOrders>(ListReadyDriverOrders(driverJobsRepository));
    put<SubmitDriverRideOffer>(SubmitDriverRideOffer(driverJobsRepository));
    put<ClaimFoodOrder>(ClaimFoodOrder(driverJobsRepository));
    put<AdvanceDriverRide>(AdvanceDriverRide(driverJobsRepository));
    put<AdvanceFoodDelivery>(AdvanceFoodDelivery(driverJobsRepository));
    put<MerchantOrdersClient>(merchantOrders);
    put<MerchantOrdersRepository>(merchantOrdersRepository);
    put<ListMerchantOrderQueue>(
      ListMerchantOrderQueue(merchantOrdersRepository),
    );
    put<AcceptMerchantOrder>(AcceptMerchantOrder(merchantOrdersRepository));
    put<RejectMerchantOrder>(RejectMerchantOrder(merchantOrdersRepository));
    put<MarkMerchantOrderReady>(
      MarkMerchantOrderReady(merchantOrdersRepository),
    );
    put<GetMerchantCatalog>(GetMerchantCatalog(merchantOrdersRepository));
    put<UpdateStoreServiceMode>(
      UpdateStoreServiceMode(merchantOrdersRepository),
    );
    put<UpdateStoreHours>(UpdateStoreHours(merchantOrdersRepository));
    put<UpdateStoreLocation>(UpdateStoreLocation(merchantOrdersRepository));
    put<UpdateStoreAcceptSettings>(
      UpdateStoreAcceptSettings(merchantOrdersRepository),
    );
    put<GetMerchantOrder>(GetMerchantOrder(merchantOrdersRepository));
    put<CreateMerchantCatalogItem>(
      CreateMerchantCatalogItem(merchantOrdersRepository),
    );
    put<SetMerchantItemAvailability>(
      SetMerchantItemAvailability(merchantOrdersRepository),
    );
    put<ReplaceMerchantItemOptions>(
      ReplaceMerchantItemOptions(merchantOrdersRepository),
    );
    put<PartnerApplicationsClient>(partners);
    put<PartnerApplicationsRepository>(partnerApplicationsRepository);
    put<ListMyPartnerApplications>(
      ListMyPartnerApplications(partnerApplicationsRepository),
    );
    put<GetMyPartnerApplication>(
      GetMyPartnerApplication(partnerApplicationsRepository),
    );
    put<DocumentImageSource>(
      documentImageSource ?? ImagePickerDocumentSource(),
    );
    // t52u: guided camera + on-device ML only in the real app; tests that
    // inject a fake source keep the plain picker path.
    if (documentImageSource == null) {
      put<SmartCaptureLauncher>(const CameraSmartCaptureLauncher());
    }
    put<PartnerRequirementsSource>(
      partnerRequirements ??
          (useMockData
              ? const FixedPartnerRequirements()
              : PartnerRequirementsClient(dio)),
    );
    put<SubmitPartnerApplication>(
      SubmitPartnerApplication(partnerApplicationsRepository),
    );
    put<ChatClient>(chat);
    put<ChatRepository>(chatRepository);
    put<ListRideChatMessages>(ListRideChatMessages(chatRepository));
    put<SendRideChatMessage>(SendRideChatMessage(chatRepository));
    put<ListFoodOrderChatMessages>(ListFoodOrderChatMessages(chatRepository));
    put<SendFoodOrderChatMessage>(SendFoodOrderChatMessage(chatRepository));
    put<VoiceClient>(voice);
    put<VoiceRepository>(voiceRepository);
    // Tests and mock builds never touch the microphone or a LiveKit server.
    final VoiceMediaEngine voiceMedia = useOverrides || useMockData
        ? FakeVoiceMediaEngine()
        : LiveKitVoiceMediaEngine();
    put<VoiceMediaEngine>(voiceMedia);
    put<VoiceCallCubit>(
      VoiceCallCubit(
        startVoiceCall: StartVoiceCall(voiceRepository),
        answerVoiceCall: AnswerVoiceCall(voiceRepository),
        endVoiceCall: EndVoiceCall(voiceRepository),
        getVoiceCall: GetVoiceCall(voiceRepository),
        getVoiceCallConfig: GetVoiceCallConfig(voiceRepository),
        media: voiceMedia,
        callEvents: snapshot.callEvents,
        reconnects: snapshot.reconnects,
        accessToken: () {
          final state = auth.state;
          return state is AuthSignedIn ? state.tokens.accessToken : null;
        },
        currentUserId: () {
          final state = auth.state;
          return state is AuthSignedIn ? state.profile.id : null;
        },
        nativeCallUi: nativeCallUi,
      ),
    );
    put<PresenceClient>(presence);
    put<PresenceRepository>(presenceRepository);
    put<SetPresence>(SetPresence(presenceRepository));
    put<HistoryClient>(history);
    put<HistoryRepository>(historyRepository);
    put<ListRideHistory>(ListRideHistory(historyRepository));
    put<ListFoodHistory>(ListFoodHistory(historyRepository));
    put<PushPort>(pushPort);
    put<MapPortSource>(maps);
    put<ExternalNavigator>(externalNavigator ?? UrlLauncherNavigator());
    put<SnapshotRealtime>(snapshot);
    put<AnalyticsPort>(analyticsPort);
    put<NotificationRouter>(notifications);
    put<AuthCubit>(auth);

    if (!skipLeafServices) {
      if (!locator.isRegistered<ConnectivityService>()) {
        locator.registerLazySingleton<ConnectivityService>(
          ConnectivityService.new,
        );
      }
      if (!locator.isRegistered<AppPermissionService>()) {
        locator.registerLazySingleton<AppPermissionService>(
          AppPermissionService.new,
        );
      }
      if (!locator.isRegistered<LocationService>()) {
        locator.registerLazySingleton<LocationService>(
          () => LocationService(locator<AppPermissionService>()),
        );
      }
    }
  }

  Widget provide({required Widget child}) {
    // The Admin token can arrive after the first frame (fresh install, token
    // changed in Admin): swap the MapPort so every map page rebuilds with
    // live tiles instead of staying on the placeholder until a restart.
    return ValueListenableBuilder<String>(
      valueListenable: adminMapboxTokenListenable,
      builder: (context, _, services) =>
          RepositoryProvider<MapPort>.value(value: mapPort, child: services!),
      child: _provideServices(child),
    );
  }

  Widget _provideServices(Widget child) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<RideClient>.value(value: rideClient),
        RepositoryProvider<RideRepository>.value(value: rideRepository),
        RepositoryProvider<CreateRide>.value(value: createRide),
        RepositoryProvider<GetRide>.value(value: getRide),
        RepositoryProvider<ListOpenRides>.value(value: listOpenRides),
        RepositoryProvider<SelectRideOffer>.value(value: selectRideOffer),
        RepositoryProvider<CancelRide>.value(value: cancelRide),
        RepositoryProvider<SubmitRideOffer>.value(value: submitRideOffer),
        RepositoryProvider<FoodClient>.value(value: foodClient),
        RepositoryProvider<FoodRepository>.value(value: foodRepository),
        RepositoryProvider<ListFoodStores>.value(value: listFoodStores),
        RepositoryProvider<GetFoodStore>.value(value: getFoodStore),
        RepositoryProvider<PlaceFoodOrder>.value(value: placeFoodOrder),
        RepositoryProvider<GetFoodOrder>.value(value: getFoodOrder),
        RepositoryProvider<CancelFoodOrder>.value(
          value: _locator<CancelFoodOrder>(),
        ),
        RepositoryProvider<ValidateVoucher>.value(
          value: _locator<ValidateVoucher>(),
        ),
        RepositoryProvider<RatingRepository>.value(
          value: _locator<RatingRepository>(),
        ),
        RepositoryProvider<MerchantOfferRepository>.value(
          value: _locator<MerchantOfferRepository>(),
        ),
        RepositoryProvider<MerchantStatsRepository>.value(
          value: _locator<MerchantStatsRepository>(),
        ),
        RepositoryProvider<AddressBookRepository>.value(
          value: _locator<AddressBookRepository>(),
        ),
        RepositoryProvider<DriverHistoryRepository>.value(
          value: _locator<DriverHistoryRepository>(),
        ),
        RepositoryProvider<PlacesRepository>.value(
          value: _locator<PlacesRepository>(),
        ),
        RepositoryProvider<HomeBannerRepository>.value(
          value: _locator<HomeBannerRepository>(),
        ),
        RepositoryProvider<HomeBannerTracker>.value(
          value: _locator<HomeBannerTracker>(),
        ),
        RepositoryProvider<DriverCardRepository>.value(
          value: _locator<DriverCardRepository>(),
        ),
        RepositoryProvider<SupportRepository>.value(
          value: _locator<SupportRepository>(),
        ),
        RepositoryProvider<AccountDeletionRepository>.value(
          value: _locator<AccountDeletionRepository>(),
        ),
        RepositoryProvider<AccountSettingsRepository>.value(
          value: _locator<AccountSettingsRepository>(),
        ),
        RepositoryProvider<HelpFaqRepository>.value(
          value: _locator<HelpFaqRepository>(),
        ),
        RepositoryProvider<RideShareRepository>.value(
          value: _locator<RideShareRepository>(),
        ),
        RepositoryProvider<ListAvailableVouchers>.value(
          value: _locator<ListAvailableVouchers>(),
        ),
        RepositoryProvider<PricingRepository>.value(
          value: _locator<PricingRepository>(),
        ),
        RepositoryProvider<DriverLocationRepository>.value(
          value: _locator<DriverLocationRepository>(),
        ),
        RepositoryProvider<MapRoutingRepository>.value(
          value: _locator<MapRoutingRepository>(),
        ),
        RepositoryProvider<ListInboxNotifications>.value(
          value: _locator<ListInboxNotifications>(),
        ),
        RepositoryProvider<MarkInboxNotificationRead>.value(
          value: _locator<MarkInboxNotificationRead>(),
        ),
        RepositoryProvider<MarkAllInboxNotificationsRead>.value(
          value: _locator<MarkAllInboxNotificationsRead>(),
        ),
        RepositoryProvider<ListReadyFoodOrders>.value(
          value: listReadyFoodOrders,
        ),
        RepositoryProvider<IdentityClient>.value(value: identityClient),
        RepositoryProvider<IdentityRepository>.value(value: identityRepository),
        RepositoryProvider<PasskeyPlatform>.value(
          value: _locator<PasskeyPlatform>(),
        ),
        RepositoryProvider<CreatePhoneChallenge>.value(
          value: createPhoneChallenge,
        ),
        RepositoryProvider<VerifyPhoneChallenge>.value(
          value: verifyPhoneChallenge,
        ),
        ChangeNotifierProvider<AuthMethodsStore>.value(value: authMethods),
        ChangeNotifierProvider<FoodCategoriesStore>.value(
          value: foodCategories,
        ),
        RepositoryProvider<DriverJobsClient>.value(value: driverJobsClient),
        RepositoryProvider<DriverJobsRepository>.value(
          value: driverJobsRepository,
        ),
        RepositoryProvider<ListOpenDriverRides>.value(
          value: _locator<ListOpenDriverRides>(),
        ),
        RepositoryProvider<ListReadyDriverOrders>.value(
          value: _locator<ListReadyDriverOrders>(),
        ),
        RepositoryProvider<SubmitDriverRideOffer>.value(
          value: _locator<SubmitDriverRideOffer>(),
        ),
        RepositoryProvider<ClaimFoodOrder>.value(
          value: _locator<ClaimFoodOrder>(),
        ),
        RepositoryProvider<AdvanceDriverRide>.value(
          value: _locator<AdvanceDriverRide>(),
        ),
        RepositoryProvider<AdvanceFoodDelivery>.value(
          value: _locator<AdvanceFoodDelivery>(),
        ),
        RepositoryProvider<MerchantOrdersClient>.value(
          value: merchantOrdersClient,
        ),
        RepositoryProvider<MerchantOrdersRepository>.value(
          value: merchantOrdersRepository,
        ),
        RepositoryProvider<ListMerchantOrderQueue>.value(
          value: _locator<ListMerchantOrderQueue>(),
        ),
        RepositoryProvider<AcceptMerchantOrder>.value(
          value: _locator<AcceptMerchantOrder>(),
        ),
        RepositoryProvider<RejectMerchantOrder>.value(
          value: _locator<RejectMerchantOrder>(),
        ),
        RepositoryProvider<MarkMerchantOrderReady>.value(
          value: _locator<MarkMerchantOrderReady>(),
        ),
        RepositoryProvider<GetMerchantCatalog>.value(
          value: _locator<GetMerchantCatalog>(),
        ),
        RepositoryProvider<UpdateStoreServiceMode>.value(
          value: _locator<UpdateStoreServiceMode>(),
        ),
        RepositoryProvider<UpdateStoreLocation>.value(
          value: _locator<UpdateStoreLocation>(),
        ),
        RepositoryProvider<UpdateStoreHours>.value(
          value: _locator<UpdateStoreHours>(),
        ),
        RepositoryProvider<UpdateStoreAcceptSettings>.value(
          value: _locator<UpdateStoreAcceptSettings>(),
        ),
        RepositoryProvider<GetMerchantOrder>.value(
          value: _locator<GetMerchantOrder>(),
        ),
        RepositoryProvider<CreateMerchantCatalogItem>.value(
          value: _locator<CreateMerchantCatalogItem>(),
        ),
        RepositoryProvider<SetMerchantItemAvailability>.value(
          value: _locator<SetMerchantItemAvailability>(),
        ),
        RepositoryProvider<ReplaceMerchantItemOptions>.value(
          value: _locator<ReplaceMerchantItemOptions>(),
        ),
        RepositoryProvider<PartnerApplicationsClient>.value(
          value: partnerApplicationsClient,
        ),
        RepositoryProvider<PartnerApplicationsRepository>.value(
          value: partnerApplicationsRepository,
        ),
        RepositoryProvider<SubmitPartnerApplication>.value(
          value: _locator<SubmitPartnerApplication>(),
        ),
        RepositoryProvider<ListMyPartnerApplications>.value(
          value: _locator<ListMyPartnerApplications>(),
        ),
        RepositoryProvider<DocumentImageSource>.value(
          value: _locator<DocumentImageSource>(),
        ),
        if (_locator.isRegistered<SmartCaptureLauncher>())
          RepositoryProvider<SmartCaptureLauncher>.value(
            value: _locator<SmartCaptureLauncher>(),
          ),
        RepositoryProvider<ChatClient>.value(value: chatClient),
        RepositoryProvider<ChatRepository>.value(value: chatRepository),
        RepositoryProvider<ListRideChatMessages>.value(
          value: _locator<ListRideChatMessages>(),
        ),
        RepositoryProvider<SendRideChatMessage>.value(
          value: _locator<SendRideChatMessage>(),
        ),
        RepositoryProvider<ListFoodOrderChatMessages>.value(
          value: _locator<ListFoodOrderChatMessages>(),
        ),
        RepositoryProvider<SendFoodOrderChatMessage>.value(
          value: _locator<SendFoodOrderChatMessage>(),
        ),
        RepositoryProvider<VoiceClient>.value(value: voiceClient),
        RepositoryProvider<VoiceRepository>.value(value: voiceRepository),
        RepositoryProvider<PresenceClient>.value(value: presenceClient),
        RepositoryProvider<PresenceRepository>.value(value: presenceRepository),
        RepositoryProvider<SetPresence>.value(value: _locator<SetPresence>()),
        RepositoryProvider<HistoryClient>.value(value: historyClient),
        RepositoryProvider<HistoryRepository>.value(value: historyRepository),
        RepositoryProvider<ListRideHistory>.value(
          value: _locator<ListRideHistory>(),
        ),
        RepositoryProvider<ListFoodHistory>.value(
          value: _locator<ListFoodHistory>(),
        ),
        RepositoryProvider<PushPort>.value(value: push),
        RepositoryProvider<ExternalNavigator>.value(value: externalNavigator),
        RepositoryProvider<SnapshotRealtime>.value(value: realtime),
        RepositoryProvider<RideNegotiationClient>.value(value: rideNegotiation),
        RepositoryProvider<RideStopsClient>.value(value: rideStops),
        RepositoryProvider<ParcelClient>.value(value: parcel),
        RepositoryProvider<AnalyticsPort>.value(value: analytics),
        RepositoryProvider<NotificationRouter>.value(value: notificationRouter),
        RepositoryProvider<ConnectivityService>.value(value: connectivity),
        RepositoryProvider<AppPermissionService>.value(value: permissions),
        RepositoryProvider<LocationService>.value(value: location),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<AuthCubit>.value(value: authCubit),
          BlocProvider<VoiceCallCubit>.value(value: voiceCallCubit),
          BlocProvider(
            create: (_) => attachFoodCartDraft(
              FoodCartCubit(),
              ownerChanges: authCubit.stream,
            ),
          ),
          BlocProvider(create: (_) => RideSessionCubit()),
          BlocProvider(create: (_) => RideDestinationCubit()),
          BlocProvider(create: (_) => RideVehiclePrefCubit()),
          BlocProvider(
            create: (_) => DriverDutyCubit(
              setPresence: _locator<SetPresence>(),
              accessToken: _accessToken,
              fetchServerOnline: () async {
                final token = _accessToken()?.trim() ?? '';
                if (token.isEmpty) {
                  return null;
                }
                final prefs = await _locator<PresenceRepository>()
                    .getServicePrefs(accessToken: token);
                return prefs.online;
              },
              reconnects: _locator<SnapshotRealtime>().reconnects,
              syncOnResume: true,
              locationReporter: DriverLocationReporter(
                repository: _locator<DriverLocationRepository>(),
                location: _locator<LocationService>(),
                accessToken: _accessToken,
              ),
            ),
          ),
          BlocProvider(
            create: (context) => DriverServicesCubit(
              repository: _locator<PresenceRepository>(),
              accessToken: _accessToken,
              online: () => context.read<DriverDutyCubit>().state,
            ),
          ),
          BlocProvider(
            create: (_) => DriverKycCubit(
              textReader: useMockData ? null : MlKitDocumentTextReader(),
              submitPartnerApplication: _locator<SubmitPartnerApplication>(),
              getMyPartnerApplication: _locator<GetMyPartnerApplication>(),
              accessToken: _accessToken,
              loadDocumentsRequired:
                  _locator<PartnerRequirementsSource>().documentsRequired,
              draftStore: _formDrafts,
              draftOwner: _signedInUserId,
              useMock: useMockData,
            ),
          ),
          BlocProvider(
            create: (_) => MerchantKybCubit(
              textReader: useMockData ? null : MlKitDocumentTextReader(),
              submitPartnerApplication: _locator<SubmitPartnerApplication>(),
              getMyPartnerApplication: _locator<GetMyPartnerApplication>(),
              accessToken: _accessToken,
              loadDocumentsRequired:
                  _locator<PartnerRequirementsSource>().documentsRequired,
              draftStore: _formDrafts,
              draftOwner: _signedInUserId,
              useMock: useMockData,
            ),
          ),
        ],
        child: child,
      ),
    );
  }

  String? _accessToken() {
    final state = authCubit.state;
    if (state is AuthSignedIn) {
      return state.tokens.accessToken;
    }
    return null;
  }

  /// Keys unsent form drafts per account (a shared phone never mixes them).
  String? _signedInUserId() {
    final state = authCubit.state;
    return state is AuthSignedIn ? state.profile.id : null;
  }

  /// Best-effort FCM/stub token registration after sign-in.
  Future<void> registerPushIfSignedIn() async {
    final token = _accessToken();
    if (token == null || token.isEmpty) {
      return;
    }
    try {
      await push.ensureRegistered(accessToken: token);
    } catch (_) {
      // Soft-fail: push is non-critical for MVP flows.
    }
  }

  Future<void> dispose() async {
    if (_locator.isRegistered<SnapshotSessionBinder>()) {
      await snapshotSessionBinder.stop();
    }
    await voiceCallCubit.close();
    await authCubit.close();
    authMethods.dispose();
    foodCategories.dispose();
    if (_locator.isRegistered<ConnectivityService>()) {
      await _locator<ConnectivityService>().dispose();
    }
    final snapshot = realtime;
    if (snapshot is SocketSnapshotRealtime) {
      await snapshot.dispose();
    } else if (snapshot is FakeSnapshotRealtime) {
      await snapshot.dispose();
    }
    dio.close(force: true);
  }
}

extension DealGoAuthTokenX on BuildContext {
  String? readAccessToken() {
    final state = read<AuthCubit>().state;
    if (state is AuthSignedIn) {
      return state.tokens.accessToken;
    }
    return null;
  }
}
