import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

import '../core/analytics/analytics_port.dart';
import '../core/analytics/console_analytics.dart';
import '../core/analytics/noop_analytics.dart';
import '../core/auth/secure_token_store.dart';
import '../core/auth/token_store.dart';
import '../core/config/app_env.dart';
import '../core/di/injection.dart';
import '../core/location/location_service.dart';
import '../core/maps/create_map_port.dart';
import '../core/maps/map_port.dart';
import '../core/network/connectivity_service.dart';
import '../core/network/dealgo_dio.dart';
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
import '../features/driver/domain/usecases/list_open_driver_rides.dart';
import '../features/driver/domain/usecases/list_ready_driver_orders.dart';
import '../features/driver/domain/usecases/submit_driver_ride_offer.dart';
import '../features/driver/presentation/cubit/driver_duty_cubit.dart';
import '../features/food/data/datasources/dio_food_remote_datasource.dart';
import '../features/food/data/datasources/food_remote_datasource.dart';
import '../features/food/data/repositories/food_repository_impl.dart';
import '../features/food/domain/repositories/food_repository.dart';
import '../features/food/domain/usecases/get_food_order.dart';
import '../features/food/domain/usecases/get_food_store.dart';
import '../features/food/domain/usecases/list_food_stores.dart';
import '../features/food/domain/usecases/list_ready_food_orders.dart';
import '../features/food/domain/usecases/place_food_order.dart';
import '../features/food/presentation/cubit/food_cart_cubit.dart';
import '../features/identity/data/datasources/dio_identity_remote_datasource.dart';
import '../features/identity/data/datasources/identity_remote_datasource.dart';
import '../features/identity/data/repositories/identity_repository_impl.dart';
import '../features/identity/domain/entities/auth_state.dart';
import '../features/identity/domain/repositories/identity_repository.dart';
import '../features/identity/domain/usecases/create_phone_challenge.dart';
import '../features/identity/domain/usecases/fetch_me.dart';
import '../features/identity/domain/usecases/refresh_session.dart';
import '../features/identity/domain/usecases/verify_phone_challenge.dart';
import '../features/identity/presentation/cubit/auth_cubit.dart';
import '../features/merchant/data/datasources/default_merchant_orders_client.dart';
import '../features/merchant/data/datasources/merchant_orders_remote_datasource.dart';
import '../features/merchant/data/repositories/merchant_orders_repository_impl.dart';
import '../features/merchant/domain/repositories/merchant_orders_repository.dart';
import '../features/merchant/domain/usecases/accept_merchant_order.dart';
import '../features/merchant/domain/usecases/create_merchant_catalog_item.dart';
import '../features/merchant/domain/usecases/get_merchant_catalog.dart';
import '../features/merchant/domain/usecases/get_merchant_order.dart';
import '../features/merchant/domain/usecases/list_merchant_order_queue.dart';
import '../features/merchant/domain/usecases/mark_merchant_order_ready.dart';
import '../features/merchant/domain/usecases/set_merchant_item_availability.dart';
import '../features/onboarding/data/datasources/dio_partner_applications_remote_datasource.dart';
import '../features/onboarding/data/datasources/fake_partner_applications_client.dart';
import '../features/onboarding/data/datasources/partner_applications_remote_datasource.dart';
import '../features/onboarding/data/repositories/partner_applications_repository_impl.dart';
import '../features/onboarding/domain/repositories/partner_applications_repository.dart';
import '../features/onboarding/domain/usecases/list_my_partner_applications.dart';
import '../features/onboarding/domain/usecases/submit_partner_application.dart';
import '../features/onboarding/presentation/cubit/driver_kyc_cubit.dart';
import '../features/onboarding/presentation/cubit/merchant_kyb_cubit.dart';
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
import '../features/ride/presentation/cubit/ride_session.dart';
import '../features/shell/presentation/address_draft_cubit.dart';
import '../features/voice/data/datasources/dio_voice_remote_datasource.dart';
import '../features/voice/data/datasources/fake_voice_client.dart';
import '../features/voice/data/datasources/voice_remote_datasource.dart';
import '../features/voice/data/repositories/voice_repository_impl.dart';
import '../features/voice/domain/repositories/voice_repository.dart';
import '../features/voice/domain/usecases/create_food_order_voice_session.dart';
import '../features/voice/domain/usecases/create_ride_voice_session.dart';

class DealGoDependencies {
  DealGoDependencies._(this._locator);

  final GetIt _locator;

  TokenStore get tokenStore => _locator<TokenStore>();
  Dio get dio => _locator<Dio>();
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
  PresenceClient get presenceClient => _locator<PresenceClient>();
  PresenceRepository get presenceRepository => _locator<PresenceRepository>();
  HistoryClient get historyClient => _locator<HistoryClient>();
  HistoryRepository get historyRepository => _locator<HistoryRepository>();
  PushPort get push => _locator<PushPort>();
  MapPort get mapPort => _locator<MapPort>();
  SnapshotRealtime get realtime => _locator<SnapshotRealtime>();
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

  /// Composition root: builds an isolated GetIt graph and mirrors it to [getIt].
  static DealGoDependencies create({
    IdentityClient? identityClient,
    TokenStore? tokenStore,
    FoodClient? foodClient,
    RideClient? rideClient,
    DriverJobsClient? driverJobsClient,
    MerchantOrdersClient? merchantOrdersClient,
    PartnerApplicationsClient? partnerApplicationsClient,
    ChatClient? chatClient,
    VoiceClient? voiceClient,
    PresenceClient? presenceClient,
    HistoryClient? historyClient,
    PushPort? push,
    MapPort? mapPort,
    SnapshotRealtime? realtime,
    AnalyticsPort? analytics,
    NotificationRouter? notificationRouter,
  }) {
    final locator = GetIt.asNewInstance();
    _registerGraph(
      locator,
      identityClient: identityClient,
      tokenStore: tokenStore,
      foodClient: foodClient,
      rideClient: rideClient,
      driverJobsClient: driverJobsClient,
      merchantOrdersClient: merchantOrdersClient,
      partnerApplicationsClient: partnerApplicationsClient,
      chatClient: chatClient,
      voiceClient: voiceClient,
      presenceClient: presenceClient,
      historyClient: historyClient,
      push: push,
      mapPort: mapPort,
      realtime: realtime,
      analytics: analytics,
      notificationRouter: notificationRouter,
    );

    // Process-wide locator for `getIt<T>()` outside the widget tree.
    getIt.allowReassignment = true;
    _ensureLeafServices(getIt);
    _registerGraph(
      getIt,
      identityClient: identityClient,
      tokenStore: tokenStore,
      foodClient: foodClient,
      rideClient: rideClient,
      driverJobsClient: driverJobsClient,
      merchantOrdersClient: merchantOrdersClient,
      partnerApplicationsClient: partnerApplicationsClient,
      chatClient: chatClient,
      voiceClient: voiceClient,
      presenceClient: presenceClient,
      historyClient: historyClient,
      push: push,
      mapPort: mapPort,
      realtime: realtime,
      analytics: analytics,
      notificationRouter: notificationRouter,
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
    FoodClient? foodClient,
    RideClient? rideClient,
    DriverJobsClient? driverJobsClient,
    MerchantOrdersClient? merchantOrdersClient,
    PartnerApplicationsClient? partnerApplicationsClient,
    ChatClient? chatClient,
    VoiceClient? voiceClient,
    PresenceClient? presenceClient,
    HistoryClient? historyClient,
    PushPort? push,
    MapPort? mapPort,
    SnapshotRealtime? realtime,
    AnalyticsPort? analytics,
    NotificationRouter? notificationRouter,
  }) {
    final tokens = tokenStore ?? SecureTokenStore();
    late final AuthCubit auth;
    final dio = createDealGoDio(
      tokenStore: tokens,
      onSessionRefreshed: (next) => auth.applyRefreshedTokens(next),
      onUnauthorized: () => auth.signOut(),
    );

    final useOverrides =
        identityClient != null || foodClient != null || rideClient != null;

    final identity = identityClient ?? DioIdentityRemoteDataSource(dio: dio);
    final food = foodClient ?? DioFoodRemoteDataSource(dio: dio);
    final rides = rideClient ?? DioRideRemoteDataSource(dio: dio);
    final identityRepository = IdentityRepositoryImpl(identity);
    final foodRepository = FoodRepositoryImpl(food);
    final rideRepository = RideRepositoryImpl(rides);
    final fetchMe = FetchMe(identityRepository);
    auth = AuthCubit(fetchMe: fetchMe, tokens: tokens);

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
      analyticsPort = analytics ?? NoopAnalytics();
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
      pushPort = push ?? (useMockData ? FakePush() : FcmPush(dio: dio));
      snapshot =
          realtime ??
          (useMockData ? FakeSnapshotRealtime() : SocketSnapshotRealtime());
      analyticsPort =
          analytics ??
          (useMockData
              ? NoopAnalytics()
              : (kDebugMode ? ConsoleAnalytics() : NoopAnalytics()));
    }

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
    final maps = mapPort ?? createMapPort();
    final notifications = notificationRouter ?? NotificationRouter();

    void put<T extends Object>(T value) {
      if (locator.isRegistered<T>()) {
        locator.unregister<T>();
      }
      locator.registerSingleton<T>(value);
    }

    put<TokenStore>(tokens);
    put<Dio>(dio);
    put<IdentityRemoteDataSource>(identity);
    put<IdentityRepository>(identityRepository);
    put<FetchMe>(fetchMe);
    put<CreatePhoneChallenge>(CreatePhoneChallenge(identityRepository));
    put<VerifyPhoneChallenge>(VerifyPhoneChallenge(identityRepository));
    put<RefreshSession>(RefreshSession(identityRepository));
    put<FoodClient>(food);
    put<FoodRemoteDataSource>(food);
    put<FoodRepository>(foodRepository);
    put<ListFoodStores>(ListFoodStores(foodRepository));
    put<GetFoodStore>(GetFoodStore(foodRepository));
    put<PlaceFoodOrder>(PlaceFoodOrder(foodRepository));
    put<GetFoodOrder>(GetFoodOrder(foodRepository));
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
      SnapshotSessionBinder(
        authCubit: auth,
        realtime: snapshot,
      ),
    );
    put<DriverJobsClient>(driverJobs);
    put<DriverJobsRepository>(driverJobsRepository);
    put<ListOpenDriverRides>(ListOpenDriverRides(driverJobsRepository));
    put<ListReadyDriverOrders>(ListReadyDriverOrders(driverJobsRepository));
    put<SubmitDriverRideOffer>(SubmitDriverRideOffer(driverJobsRepository));
    put<ClaimFoodOrder>(ClaimFoodOrder(driverJobsRepository));
    put<MerchantOrdersClient>(merchantOrders);
    put<MerchantOrdersRepository>(merchantOrdersRepository);
    put<ListMerchantOrderQueue>(
      ListMerchantOrderQueue(merchantOrdersRepository),
    );
    put<AcceptMerchantOrder>(AcceptMerchantOrder(merchantOrdersRepository));
    put<MarkMerchantOrderReady>(
      MarkMerchantOrderReady(merchantOrdersRepository),
    );
    put<GetMerchantCatalog>(GetMerchantCatalog(merchantOrdersRepository));
    put<GetMerchantOrder>(GetMerchantOrder(merchantOrdersRepository));
    put<CreateMerchantCatalogItem>(
      CreateMerchantCatalogItem(merchantOrdersRepository),
    );
    put<SetMerchantItemAvailability>(
      SetMerchantItemAvailability(merchantOrdersRepository),
    );
    put<PartnerApplicationsClient>(partners);
    put<PartnerApplicationsRepository>(partnerApplicationsRepository);
    put<ListMyPartnerApplications>(
      ListMyPartnerApplications(partnerApplicationsRepository),
    );
    put<SubmitPartnerApplication>(
      SubmitPartnerApplication(partnerApplicationsRepository),
    );
    put<ChatClient>(chat);
    put<ChatRepository>(chatRepository);
    put<ListRideChatMessages>(ListRideChatMessages(chatRepository));
    put<SendRideChatMessage>(SendRideChatMessage(chatRepository));
    put<ListFoodOrderChatMessages>(
      ListFoodOrderChatMessages(chatRepository),
    );
    put<SendFoodOrderChatMessage>(
      SendFoodOrderChatMessage(chatRepository),
    );
    put<VoiceClient>(voice);
    put<VoiceRepository>(voiceRepository);
    put<CreateRideVoiceSession>(CreateRideVoiceSession(voiceRepository));
    put<CreateFoodOrderVoiceSession>(
      CreateFoodOrderVoiceSession(voiceRepository),
    );
    put<PresenceClient>(presence);
    put<PresenceRepository>(presenceRepository);
    put<SetPresence>(SetPresence(presenceRepository));
    put<HistoryClient>(history);
    put<HistoryRepository>(historyRepository);
    put<ListRideHistory>(ListRideHistory(historyRepository));
    put<ListFoodHistory>(ListFoodHistory(historyRepository));
    put<PushPort>(pushPort);
    put<MapPort>(maps);
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
        RepositoryProvider<ListReadyFoodOrders>.value(value: listReadyFoodOrders),
        RepositoryProvider<IdentityClient>.value(value: identityClient),
        RepositoryProvider<IdentityRepository>.value(value: identityRepository),
        RepositoryProvider<CreatePhoneChallenge>.value(value: createPhoneChallenge),
        RepositoryProvider<VerifyPhoneChallenge>.value(value: verifyPhoneChallenge),
        RepositoryProvider<DriverJobsClient>.value(value: driverJobsClient),
        RepositoryProvider<DriverJobsRepository>.value(value: driverJobsRepository),
        RepositoryProvider<ListOpenDriverRides>.value(
          value: _locator<ListOpenDriverRides>(),
        ),
        RepositoryProvider<ListReadyDriverOrders>.value(
          value: _locator<ListReadyDriverOrders>(),
        ),
        RepositoryProvider<SubmitDriverRideOffer>.value(
          value: _locator<SubmitDriverRideOffer>(),
        ),
        RepositoryProvider<ClaimFoodOrder>.value(value: _locator<ClaimFoodOrder>()),
        RepositoryProvider<MerchantOrdersClient>.value(value: merchantOrdersClient),
        RepositoryProvider<MerchantOrdersRepository>.value(
          value: merchantOrdersRepository,
        ),
        RepositoryProvider<ListMerchantOrderQueue>.value(
          value: _locator<ListMerchantOrderQueue>(),
        ),
        RepositoryProvider<AcceptMerchantOrder>.value(
          value: _locator<AcceptMerchantOrder>(),
        ),
        RepositoryProvider<MarkMerchantOrderReady>.value(
          value: _locator<MarkMerchantOrderReady>(),
        ),
        RepositoryProvider<GetMerchantCatalog>.value(
          value: _locator<GetMerchantCatalog>(),
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
        RepositoryProvider<CreateRideVoiceSession>.value(
          value: _locator<CreateRideVoiceSession>(),
        ),
        RepositoryProvider<CreateFoodOrderVoiceSession>.value(
          value: _locator<CreateFoodOrderVoiceSession>(),
        ),
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
        RepositoryProvider<MapPort>.value(value: mapPort),
        RepositoryProvider<SnapshotRealtime>.value(value: realtime),
        RepositoryProvider<AnalyticsPort>.value(value: analytics),
        RepositoryProvider<NotificationRouter>.value(value: notificationRouter),
        RepositoryProvider<ConnectivityService>.value(value: connectivity),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<AuthCubit>.value(value: authCubit),
          BlocProvider(create: (_) => AddressDraftCubit()),
          BlocProvider(create: (_) => FoodCartCubit()),
          BlocProvider(create: (_) => RideSessionCubit()),
          BlocProvider(
            create: (_) => DriverDutyCubit(
              setPresence: _locator<SetPresence>(),
              accessToken: _accessToken,
            ),
          ),
          BlocProvider(
            create: (_) => DriverKycCubit(
              submitPartnerApplication: _locator<SubmitPartnerApplication>(),
              accessToken: _accessToken,
              useMock: useMockData,
            ),
          ),
          BlocProvider(
            create: (_) => MerchantKybCubit(
              submitPartnerApplication: _locator<SubmitPartnerApplication>(),
              accessToken: _accessToken,
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
    await authCubit.close();
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
