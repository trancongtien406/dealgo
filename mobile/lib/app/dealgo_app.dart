import 'dart:developer' as developer;

import '../core/appearance/app_appearance.dart';
import '../core/design_system/components/dealgo_nav_insets.dart';
import '../core/app_gate/app_gate_host.dart';

import 'dart:async';

import '../features/activity/data/datasources/history_remote_datasource.dart';
import '../features/promotion/domain/repositories/promotion_repository.dart';
import '../features/ride/domain/stops/ride_stops_client.dart';
import '../features/places/data/place_history_cache.dart';
import '../features/onboarding/data/datasources/partner_requirements_client.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/observability/crash_reporting.dart';
import '../core/auth/post_auth_gate.dart';
import '../core/auth/token_store.dart';
import '../core/deeplink/deep_link_gate.dart';
import '../core/launch/launch_splash.dart';
import '../core/deeplink/deep_link_router_hook.dart';
import '../features/identity/presentation/auth_methods_store.dart';
import '../features/identity/domain/entities/app_role.dart';
import '../core/push/push_port.dart';
import '../core/push/new_job_alert.dart';
import '../core/design_system/theme/dealgo_theme.dart';
import '../core/storage/onboarding_storage.dart';
import '../features/presence/data/datasources/presence_remote_datasource.dart';
import '../features/address_book/domain/repositories/address_book_repository.dart';
import '../features/driver_history/domain/driver_history.dart';
import '../features/driver_credit/domain/driver_credit.dart';
import '../features/onboarding/presentation/document_image_source.dart';
import '../features/support/domain/help_faq.dart';
import '../features/ride/domain/ride_share.dart';
import '../features/ride/domain/entities/ride_models.dart';
import '../core/smoke/ride_smoke_flags.dart';
import '../features/account_deletion/domain/account_deletion.dart';
import '../features/account_settings/domain/account_settings.dart';
import '../features/support/domain/support_ticket.dart';
import '../features/driver_card/domain/driver_card.dart';
import '../core/location/location_service.dart';
import '../features/live_location/domain/driver_location.dart';
import '../features/pricing/domain/pricing.dart';
import '../core/navigation/external_navigator.dart';
import '../features/places/domain/place.dart';
import '../features/ride/presentation/cubit/ride_destination.dart';
import '../features/merchant/domain/merchant_offers.dart';
import '../features/rating/domain/service_rating.dart';
import '../features/chat/data/datasources/chat_remote_datasource.dart';
import '../features/food/data/datasources/food_remote_datasource.dart';
import '../features/merchant/data/datasources/merchant_orders_remote_datasource.dart';
import '../features/identity/data/datasources/identity_remote_datasource.dart';
import '../features/inbox/data/datasources/inbox_remote_datasource.dart';
import '../features/identity/domain/auth_redirect.dart';
import '../features/identity/domain/entities/auth_state.dart';
import '../features/ride/data/datasources/customer_active_trip_client.dart';
import '../features/identity/domain/passkey_platform.dart';
import '../features/ride/data/datasources/ride_remote_datasource.dart';
import '../l10n/app_localizations.dart';
import '../features/driver/presentation/cubit/driver_duty_cubit.dart';
import '../features/driver/presentation/utils/driver_job_resumer.dart';
import '../features/ride/presentation/utils/customer_trip_resumer.dart';
import 'di.dart';
import 'router/app_router.dart';
import '../core/realtime/snapshot_realtime.dart';
import '../core/realtime/socket_snapshot_realtime.dart';
import '../features/driver/presentation/utils/driver_routes.dart';
import '../features/driver/presentation/utils/ride_unassigned_copy.dart';
import '../features/voice/presentation/widgets/voice_call_host.dart';
import '../core/ui/keyboard_dismiss.dart';

class DealGoApp extends StatefulWidget {
  const DealGoApp({
    super.key,
    this.identityClient,
    this.authMethodsCache,
    this.tokenStore,
    this.passkeyPlatform,
    this.foodClient,
    this.promotions,
    this.historyClient,
    this.merchantOrdersClient,
    this.rideClient,
    this.rideStopsClient,
    this.presenceClient,
    this.realtime,
    this.chatClient,
    this.inboxRemote,
    this.addressBook,
    this.ratings,
    this.merchantOffers,
    this.driverHistory,
    this.driverCredit,
    this.support,
    this.accountDeletion,
    this.accountSettings,
    this.helpFaqs,
    this.documentImageSource,
    this.partnerRequirements,
    this.rideShare,
    this.driverCard,
    this.locationOverride,
    this.pricing,
    this.driverLocation,
    this.places,
    this.externalNavigator,
    this.onboardingStorage,
    this.postAuthGate,
    this.initialLocation,
  });

  final IdentityClient? identityClient;

  /// Device cache of enabled sign-in methods (tests seed a returning user).
  final AuthMethodsCache? authMethodsCache;

  /// Overrides the WebAuthn adapter (tests simulate unsupported devices).
  final PasskeyPlatform? passkeyPlatform;
  final TokenStore? tokenStore;
  final FoodClient? foodClient;
  final PromotionRepository? promotions;
  final HistoryClient? historyClient;
  final MerchantOrdersClient? merchantOrdersClient;
  final RideClient? rideClient;

  /// Multi-stop commands override (tests).
  final RideStopsClient? rideStopsClient;

  /// Test seam for driver presence and service toggles.
  final PresenceClient? presenceClient;

  /// Test seam for the snapshot socket (DEC-PROD-025).
  final SnapshotRealtime? realtime;
  final ChatClient? chatClient;
  final InboxRemoteDataSource? inboxRemote;
  final AddressBookRepository? addressBook;
  final RatingRepository? ratings;
  final MerchantOfferRepository? merchantOffers;
  final DriverHistoryRepository? driverHistory;
  final DriverCreditRepository? driverCredit;
  final SupportRepository? support;
  final AccountDeletionRepository? accountDeletion;
  final AccountSettingsRepository? accountSettings;
  final HelpFaqRepository? helpFaqs;
  final DocumentImageSource? documentImageSource;
  final PartnerRequirementsSource? partnerRequirements;
  final RideShareRepository? rideShare;
  final DriverCardRepository? driverCard;
  final LocationService? locationOverride;
  final PricingRepository? pricing;
  final DriverLocationRepository? driverLocation;
  final PlacesRepository? places;

  /// Google Maps / Waze hand-off (tests pass a fake).
  final ExternalNavigator? externalNavigator;
  final OnboardingStorage? onboardingStorage;
  final PostAuthGate? postAuthGate;
  final String? initialLocation;

  @override
  State<DealGoApp> createState() => _DealGoAppState();
}

class _DealGoAppState extends State<DealGoApp> with WidgetsBindingObserver {
  late final DealGoDependencies _deps;
  late final PostAuthGate _postAuth;
  late final AuthRefreshListenable _authRefresh;
  late final Listenable _refresh;
  late final GoRouter _router;
  late final DeepLinkRouterHook _deepLinks;
  StreamSubscription<AuthState>? _authSub;
  StreamSubscription<bool>? _connectivitySub;
  StreamSubscription<RideUnassignedHint>? _unassignedSub;

  /// Ride ids the socket already announced as unassigned (push dedupe).
  final _socketUnassigned = <String>{};
  late final DriverJobResumer _driverResume;
  late final CustomerTripResumer _customerResume;
  late final AppLifecycleListener _lifecycle;
  late final AppAppearance _appearance;
  var _ownsPostAuth = false;

  @override
  void initState() {
    super.initState();
    _appearance = AppAppearance.fromWarmup();
    _appearance.addListener(_onAppearance);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncChrome());
    _deps = DealGoDependencies.create(
      identityClient: widget.identityClient,
      authMethodsCache: widget.authMethodsCache,
      tokenStore: widget.tokenStore,
      passkeyPlatform: widget.passkeyPlatform,
      foodClient: widget.foodClient,
      promotions: widget.promotions,
      historyClient: widget.historyClient,
      merchantOrdersClient: widget.merchantOrdersClient,
      rideClient: widget.rideClient,
      rideStopsClient: widget.rideStopsClient,
      presenceClient: widget.presenceClient,
      realtime: widget.realtime,
      chatClient: widget.chatClient,
      inboxRemote: widget.inboxRemote,
      addressBook: widget.addressBook,
      ratings: widget.ratings,
      merchantOffers: widget.merchantOffers,
      driverHistory: widget.driverHistory,
      driverCredit: widget.driverCredit,
      support: widget.support,
      accountDeletion: widget.accountDeletion,
      accountSettings: widget.accountSettings,
      helpFaqs: widget.helpFaqs,
      documentImageSource: widget.documentImageSource,
      partnerRequirements: widget.partnerRequirements,
      rideShare: widget.rideShare,
      driverCard: widget.driverCard,
      locationOverride: widget.locationOverride,
      pricing: widget.pricing,
      driverLocation: widget.driverLocation,
      places: widget.places,
      externalNavigator: widget.externalNavigator,
    );
    if (widget.postAuthGate != null) {
      _postAuth = widget.postAuthGate!;
    } else {
      _ownsPostAuth = true;
      _postAuth = PostAuthGate(
        storage: widget.onboardingStorage ?? AppOnboardingStorage(),
      );
    }
    _deps.authCubit.bindPostAuth(_postAuth);
    _deps.authCubit.beforeSignOut = (token) async {
      // Memory copy is dropped at once; the disk copy is removed in the
      // background so a slow platform store never delays sign-out.
      unawaited(PlaceHistoryCache.clear());
      unawaited(_deps.activeJobs.clear());
      await _deps.voiceCallCubit.signOut();
      await _deps.push.unregister(accessToken: token);
    };
    _authRefresh = AuthRefreshListenable(_deps.authCubit);
    _refresh = Listenable.merge([_authRefresh, _postAuth, _deps.authMethods]);
    _router = createAppRouter(
      auth: _deps.authCubit,
      refreshListenable: _refresh,
      postAuth: _postAuth,
      initialLocation: widget.initialLocation ?? AuthRoutes.splash,
      deepLinks: DeepLinkGate(notifications: _deps.notificationRouter),
      methodAvailable: _deps.authMethods.isEnabled,
    );
    _deepLinks = DeepLinkRouterHook()..attach(_router);
    _router.routerDelegate.addListener(_maybeReleaseLaunch);
    _router.routerDelegate.addListener(_recordNavigation);
    _refresh.addListener(_maybeReleaseLaunch);
    _registerSmokeNavigateHook();
    _deps.notificationRouter
      ..bindNavigator(_router.go)
      ..bindReadiness(_pushReadyRoles);
    // Opening the app from a push (foreground, background or cold
    // start) lands on the page it names for this user's roles; a tap that
    // arrives while the session is still restoring waits for sign-in.
    // A tapped call push also rings the call screen if it is still ringing.
    _deps.push.listenForTaps((data) {
      _deps.notificationRouter.handleTap(data);
      unawaited(_deps.voiceCallCubit.openFromPush(data));
    }).ignore();
    _deps.push.listenForeground(_showForegroundPush).ignore();
    _unassignedSub = _deps.realtime.rideUnassigned.listen(_onRideUnassigned);
    NewJobAlert.instance.inCall = () => _deps.voiceCallCubit.state.busy;
    unawaited(NewJobAlert.instance.restore());
    _refresh.addListener(_flushPendingPushTap);
    _deps.snapshotSessionBinder.start();
    // Prompt OS permissions (no intermediate page) after profile setup, then
    // register FCM. Re-entry uses the stored flag so dialogs are not repeated.
    _postAuth.addListener(_maybePromptRuntimePermissions);
    _driverResume = DriverJobResumer(
      source: _deps.driverActiveJob,
      ensureOnline: () {
        final navCtx = _router.routerDelegate.navigatorKey.currentContext;
        if (navCtx != null) {
          ensureDriverOnDuty(navCtx);
        }
      },
      navigate: (route) => _router.go(route),
      currentLocation: () => _router.state.uri.path,
      jobHints: _deps.realtime.snapshots,
      reconnects: _deps.realtime.reconnects,
      userNavigationClaimed: () => _deps.notificationRouter.claimsNavigation,
    );
    _customerResume = CustomerTripResumer(
      source: _deps.customerActiveTrip,
      navigate: (route) => _router.go(route),
      currentLocation: () => _router.state.uri.path,
      userNavigationClaimed: () => _deps.notificationRouter.claimsNavigation,
      cachedRoute: _cachedTripRoute,
    );
    _lifecycle = AppLifecycleListener(
      onResume: () {
        final realtime = _deps.realtime;
        if (realtime is SocketSnapshotRealtime) {
          realtime.resumeIfDisconnected();
        }
        unawaited(_driverResume.recheck());
        // t82u: re-check min build + pending terms on every resume.
        unawaited(_deps.appGateCubit.onResume());
        // The system call screen can be answered or ended while no Dart code
        // runs (Android kills the process on swipe away; iOS suspends it).
        unawaited(_deps.voiceCallCubit.onResume());
      },
    );
    _postAuth.addListener(_maybeResumeDriverJob);
    unawaited(_deps.appGateCubit.checkVersion());
    unawaited(
      _deps.appGateCubit.setSignedIn(_deps.authCubit.state is AuthSignedIn),
    );
    _bindActiveJobOwner(_deps.authCubit.state);
    _connectivitySub = _deps.connectivity.onStatusChanged.listen((online) {
      if (online) unawaited(_deps.authCubit.refreshProfile());
    });
    _authSub = _deps.authCubit.stream.listen((state) {
      _bindActiveJobOwner(state);
      _maybeResumeDriverJob();
      unawaited(_deps.appGateCubit.setSignedIn(state is AuthSignedIn));
      if (state is AuthSignedIn) {
        unawaited(_deps.voiceCallCubit.refreshConfig());
        _maybePromptRuntimePermissions();
        unawaited(_deps.analytics.setUserId(state.profile.id));
        setCrashReportingUser(state.profile.id);
      } else {
        if (state is AuthSignedOut) {
          unawaited(_deps.voiceCallCubit.signOut());
        }
        unawaited(_deps.analytics.setUserId(null));
        setCrashReportingUser(null);
      }
    });
    unawaited(_postAuth.load());
    // Sign-in options resolve behind the native splash, so the picker never
    // draws options that vanish a moment later.
    unawaited(_deps.authMethods.load());
    unawaited(_deps.foodCategories.load());
    unawaited(_deps.authCubit.restore());
    unawaited(_deps.connectivity.start());
  }

  String _lastPath = '';

  /// Crash-report breadcrumb for each route change (ids redacted).
  void _recordNavigation() {
    final path = _router.routerDelegate.currentConfiguration.uri.path;
    if (path == _lastPath) return;
    recordNavigation(_lastPath, path);
    _lastPath = path;
  }

  /// Lets Flutter paint its first frame (dropping the native launch screen)
  /// once the cold-start route is decided; see [LaunchSplash].
  void _maybeReleaseLaunch() {
    if (!LaunchSplash.isHeld) return;
    final ready = launchRouteReady(
      auth: _deps.authCubit.state,
      postAuthLoaded: _postAuth.isLoaded,
      location: _router.routerDelegate.currentConfiguration.uri.path,
      authMethodsLoading: _deps.authMethods.status == AuthMethodsStatus.loading,
    );
    if (ready) LaunchSplash.release();
  }

  bool _promptingPermissions = false;

  void _bindActiveJobOwner(AuthState state) {
    _deps.activeJobs.bindUser(state is AuthSignedIn ? state.profile.id : null);
  }

  Future<String?> _cachedTripRoute() async {
    final snapshot = await _deps.activeJobs.lookup();
    if (snapshot == null || snapshot.ended) return null;
    return CustomerActiveTrip(
      kind: snapshot.kind.wire,
      id: snapshot.id,
      status: snapshot.status,
    ).route;
  }

  /// Relaunch: reopen the driver's in-progress job (and go back on duty) or the
  /// customer's live ride / open food order.
  void _maybeResumeDriverJob() {
    final state = _deps.authCubit.state;
    if (state is! AuthSignedIn) {
      _driverResume.reset();
      _customerResume.reset();
      return;
    }
    unawaited(
      _driverResume.onSignedIn(
        userId: state.profile.id,
        roles: state.profile.activeAppRoles,
        profileDone: _postAuth.profileSetupCompleted,
      ),
    );
    unawaited(
      _customerResume.onSignedIn(
        userId: state.profile.id,
        roles: state.profile.activeAppRoles,
        profileDone: _postAuth.profileSetupCompleted,
      ),
    );
  }

  /// Roles of a session ready to open push targets, else null.
  List<AppRole>? _pushReadyRoles() {
    final auth = _deps.authCubit.state;
    if (auth is! AuthSignedIn ||
        !_postAuth.isLoaded ||
        !_postAuth.profileSetupCompleted) {
      return null;
    }
    return auth.profile.activeAppRoles;
  }

  final _messengerKey = GlobalKey<ScaffoldMessengerState>();

  /// the server moved this driver's ride back to NEGOTIATING (start /
  /// arrive timeout, ops reassign). Leave the trip page (no stale active job;
  /// DriverJobResumer re-reads /v1/driver/active-job) and say why.
  void _onRideUnassigned(RideUnassignedHint hint) {
    _socketUnassigned.add(hint.rideId);
    final onThatRide = _router.state.uri.path.startsWith(
      DriverRoutes.ride(hint.rideId),
    );
    if (onThatRide) {
      _router.go('/driver/jobs');
    }
    final messenger = _messengerKey.currentState;
    final ctx = _messengerKey.currentContext;
    final l10n = ctx == null
        ? null
        : Localizations.of<AppLocalizations>(ctx, AppLocalizations);
    if (messenger == null || l10n == null) {
      return;
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          key: const Key('driver-ride-unassigned-snackbar'),
          content: Text(rideUnassignedMessage(l10n, hint.reasonCode)),
          duration: const Duration(seconds: 6),
        ),
      );
  }

  /// Android foreground push → in-app banner whose action routes like a
  /// notification tap (chat bursts collapse into the latest one).
  void _showForegroundPush(PushMessage message) {
    // Usually the socket already rang the call screen. But a foreground push
    // also arrives while the socket is reconnecting or just after sign-in, and
    // then nothing would ever ring: let the cubit open the call if it still
    // rings (no-op otherwise, so there is still only one ring).
    if (message.data['eventType'] == 'Call.incoming') {
      unawaited(_deps.voiceCallCubit.openFromPush(message.data));
      return;
    }
    // the socket's rideUnassigned already showed the reason banner.
    if (message.data['eventType'] == 'Ride.driver.unassigned' &&
        _socketUnassigned.contains(
          message.data['aggregateId'] ?? message.data['rideId'],
        )) {
      return;
    }
    // New ride / food job / store order: spoken "DealGo, có cuốc mới" + vibrate
    // (Android foreground shows no system notification, so nothing else rings).
    unawaited(NewJobAlert.instance.handlePush(message.data));
    final messenger = _messengerKey.currentState;
    final ctx = _messengerKey.currentContext;
    final text = [
      message.title,
      message.body,
    ].whereType<String>().where((s) => s.trim().isNotEmpty).join('\n');
    if (messenger == null || ctx == null || text.isEmpty) {
      return;
    }
    final label =
        Localizations.of<AppLocalizations>(
          ctx,
          AppLocalizations,
        )?.pushForegroundOpen ??
        'Xem';
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          duration: const Duration(seconds: 6),
          action: SnackBarAction(
            label: label,
            onPressed: () => _deps.notificationRouter.handleTap(message.data),
          ),
        ),
      );
  }

  void _flushPendingPushTap() {
    // After the router has applied the auth redirect for this change.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _deps.notificationRouter.flushPending(),
    );
  }

  void _maybePromptRuntimePermissions() {
    if (_deps.authCubit.state is! AuthSignedIn) {
      return;
    }
    if (!_postAuth.profileSetupCompleted) {
      return;
    }
    if (_postAuth.permissionsCompleted) {
      unawaited(_deps.registerPushIfSignedIn());
      return;
    }
    // Local smoke (`--dart-define=SMOKE_ACCESS_TOKEN=`): skip OS dialogs so
    // automated E2E is not stuck behind the location sheet. Real installs still prompt.
    const smokeAccess = String.fromEnvironment('SMOKE_ACCESS_TOKEN');
    if (smokeAccess.isNotEmpty) {
      unawaited(() async {
        await _postAuth.setCompletedPermissions(true);
        await _deps.registerPushIfSignedIn();
      }());
      return;
    }
    if (_promptingPermissions) {
      return;
    }
    _promptingPermissions = true;
    unawaited(() async {
      try {
        await _deps.permissions.promptLaunchPermissions();
        await _postAuth.setCompletedPermissions(true);
        await _deps.registerPushIfSignedIn();
      } finally {
        _promptingPermissions = false;
      }
    }());
  }

  /// Debug/smoke only: `ext.dealgo.go` with `{path: /customer/book}` via VM service.
  /// Optional `places=dn` pushes Da Nang pickup/dropoff as `RidePlaces` extra
  /// (needed for route/fare screens that require state.extra).
  void _registerSmokeNavigateHook() {
    if (kReleaseMode) {
      return;
    }
    const access = String.fromEnvironment('SMOKE_ACCESS_TOKEN');
    if (access.isEmpty) {
      return;
    }
    developer.registerExtension('ext.dealgo.go', (method, params) async {
      final path = params['path'];
      if (path == null || path.isEmpty) {
        return developer.ServiceExtensionResponse.error(1, 'path required');
      }
      if (!mounted) {
        return developer.ServiceExtensionResponse.error(
          2,
          'DealGoApp not mounted',
        );
      }
      try {
        final placesFlag = params['places'];
        if (placesFlag == 'dn') {
          RideSmokeFlags.autoContinueAfterQuote =
              params['auto'] == '1' || params['auto'] == 'true';
          // Smoke-only Da Nang A/B so route overview + fare can load without UI taps.
          const places = RidePlaces(
            pickup: RidePoint(
              lat: 16.0544,
              lng: 108.2022,
              label: '123 Nguyễn Văn Linh, Hải Châu, Đà Nẵng',
            ),
            dropoff: RidePoint(
              lat: 16.06124,
              lng: 108.2278,
              label: 'Cầu Rồng, Sơn Trà, Đà Nẵng',
            ),
          );
          // Book tab reads destination from RideDestinationCubit (not route extra).
          if (path == '/customer/book') {
            final navCtx = _router.routerDelegate.navigatorKey.currentContext;
            if (navCtx != null) {
              navCtx.read<RideDestinationCubit>().choose(
                const PlaceOption(
                  name: 'Cầu Rồng',
                  address: 'Sơn Trà, Đà Nẵng',
                  lat: 16.06124,
                  lng: 108.2278,
                  source: PlaceSource.recent,
                ),
              );
            }
            _router.go(path);
          } else {
            _router.push(path, extra: places);
          }
        } else {
          // Sync go so smoke sees the route change (post-frame previously returned
          // ok while the callback could no-op).
          _router.go(path);
        }
      } catch (error) {
        return developer.ServiceExtensionResponse.error(3, '$error');
      }
      return developer.ServiceExtensionResponse.result(
        '{"ok":true,"location":"${_router.state.uri}"}',
      );
    });
  }

  void _onAppearance() {
    if (mounted) setState(_syncChrome);
  }

  @override
  void didChangePlatformBrightness() {
    if (_appearance.themeChoice == AppThemeChoice.system && mounted) {
      setState(_syncChrome);
    }
  }

  void _syncChrome() {
    final platform =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    applySystemNavigationStyle(_appearance.brightness(platform));
  }

  @override
  void dispose() {
    _appearance.removeListener(_onAppearance);
    WidgetsBinding.instance.removeObserver(this);
    _refresh.removeListener(_flushPendingPushTap);
    _refresh.removeListener(_maybeReleaseLaunch);
    _router.routerDelegate.removeListener(_maybeReleaseLaunch);
    _router.routerDelegate.removeListener(_recordNavigation);
    _postAuth.removeListener(_maybePromptRuntimePermissions);
    _postAuth.removeListener(_maybeResumeDriverJob);
    _driverResume.reset();
    _customerResume.reset();
    _lifecycle.dispose();
    unawaited(_authSub?.cancel() ?? Future<void>.value());
    unawaited(_connectivitySub?.cancel() ?? Future<void>.value());
    unawaited(_unassignedSub?.cancel() ?? Future<void>.value());
    _deepLinks.router = null;
    _router.dispose();
    _authRefresh.dispose();
    if (_ownsPostAuth) {
      _postAuth.dispose();
    }
    unawaited(_deps.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final platform =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    final brightness = _appearance.brightness(platform);
    _appearance.applyPalette(platform);
    return _deps.provide(
      child: ChangeNotifierProvider<AppAppearance>.value(
        value: _appearance,
        child: ChangeNotifierProvider<PostAuthGate>.value(
          value: _postAuth,
          child: MaterialApp.router(
            title: 'DealGo',
            debugShowCheckedModeBanner: false,
            theme: DealGoTheme.light,
            darkTheme: DealGoTheme.dark,
            themeMode: _appearance.themeMode,
            locale: _appearance.locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            routerConfig: _router,
            scaffoldMessengerKey: _messengerKey,
            scrollBehavior: const DealGoScrollBehavior(),
            // Status-bar icons follow the resolved appearance. Screens with a
            // brand-colored header override this with their own AnnotatedRegion.
            builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
              value: brightness == Brightness.dark
                  ? DealGoTheme.darkHeaderOverlay
                  : DealGoTheme.lightCanvasOverlay,
              child: KeyboardDismissOnTapOutside(
                child: AppGateHost(
                  child: VoiceCallHost(child: child ?? const SizedBox.shrink()),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
