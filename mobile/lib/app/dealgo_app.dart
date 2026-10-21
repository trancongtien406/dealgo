import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/auth/post_auth_gate.dart';
import '../core/auth/token_store.dart';
import '../core/deeplink/deep_link_router_hook.dart';
import '../core/design_system/theme/dealgo_theme.dart';
import '../core/storage/onboarding_storage.dart';
import '../features/presence/data/datasources/presence_remote_datasource.dart';
import '../features/address_book/domain/repositories/address_book_repository.dart';
import '../features/driver_history/domain/driver_history.dart';
import '../features/onboarding/presentation/document_image_source.dart';
import '../features/support/domain/help_faq.dart';
import '../features/ride/domain/ride_share.dart';
import '../features/account_deletion/domain/account_deletion.dart';
import '../features/account_settings/domain/account_settings.dart';
import '../features/support/domain/support_ticket.dart';
import '../features/driver_card/domain/driver_card.dart';
import '../core/location/location_service.dart';
import '../features/live_location/domain/driver_location.dart';
import '../features/pricing/domain/pricing.dart';
import '../core/navigation/external_navigator.dart';
import '../features/places/domain/place.dart';
import '../features/rating/domain/service_rating.dart';
import '../features/chat/data/datasources/chat_remote_datasource.dart';
import '../features/food/data/datasources/food_remote_datasource.dart';
import '../features/merchant/data/datasources/merchant_orders_remote_datasource.dart';
import '../features/identity/data/datasources/identity_remote_datasource.dart';
import '../features/inbox/data/datasources/inbox_remote_datasource.dart';
import '../features/identity/domain/auth_redirect.dart';
import '../features/identity/domain/entities/auth_state.dart';
import '../features/identity/domain/passkey_platform.dart';
import '../features/ride/data/datasources/ride_remote_datasource.dart';
import '../l10n/app_localizations.dart';
import 'di.dart';
import 'router/app_router.dart';
import '../core/realtime/snapshot_realtime.dart';

class DealGoApp extends StatefulWidget {
  const DealGoApp({
    super.key,
    this.identityClient,
    this.tokenStore,
    this.passkeyPlatform,
    this.foodClient,
    this.merchantOrdersClient,
    this.rideClient,
    this.presenceClient,
    this.realtime,
    this.chatClient,
    this.inboxRemote,
    this.addressBook,
    this.ratings,
    this.driverHistory,
    this.support,
    this.accountDeletion,
    this.accountSettings,
    this.helpFaqs,
    this.documentImageSource,
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

  /// Overrides the WebAuthn adapter (tests simulate unsupported devices).
  final PasskeyPlatform? passkeyPlatform;
  final TokenStore? tokenStore;
  final FoodClient? foodClient;
  final MerchantOrdersClient? merchantOrdersClient;
  final RideClient? rideClient;

  /// Test seam for driver presence and service toggles.
  final PresenceClient? presenceClient;

  /// Test seam for the snapshot socket (DEC-PROD-025).
  final SnapshotRealtime? realtime;
  final ChatClient? chatClient;
  final InboxRemoteDataSource? inboxRemote;
  final AddressBookRepository? addressBook;
  final RatingRepository? ratings;
  final DriverHistoryRepository? driverHistory;
  final SupportRepository? support;
  final AccountDeletionRepository? accountDeletion;
  final AccountSettingsRepository? accountSettings;
  final HelpFaqRepository? helpFaqs;
  final DocumentImageSource? documentImageSource;
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

class _DealGoAppState extends State<DealGoApp> {
  late final DealGoDependencies _deps;
  late final PostAuthGate _postAuth;
  late final AuthRefreshListenable _authRefresh;
  late final Listenable _refresh;
  late final GoRouter _router;
  late final DeepLinkRouterHook _deepLinks;
  StreamSubscription<AuthState>? _authSub;
  var _ownsPostAuth = false;

  @override
  void initState() {
    super.initState();
    _deps = DealGoDependencies.create(
      identityClient: widget.identityClient,
      tokenStore: widget.tokenStore,
      passkeyPlatform: widget.passkeyPlatform,
      foodClient: widget.foodClient,
      merchantOrdersClient: widget.merchantOrdersClient,
      rideClient: widget.rideClient,
      presenceClient: widget.presenceClient,
      realtime: widget.realtime,
      chatClient: widget.chatClient,
      inboxRemote: widget.inboxRemote,
      addressBook: widget.addressBook,
      ratings: widget.ratings,
      driverHistory: widget.driverHistory,
      support: widget.support,
      accountDeletion: widget.accountDeletion,
      accountSettings: widget.accountSettings,
      helpFaqs: widget.helpFaqs,
      documentImageSource: widget.documentImageSource,
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
    _authRefresh = AuthRefreshListenable(_deps.authCubit);
    _refresh = Listenable.merge([_authRefresh, _postAuth]);
    _router = createAppRouter(
      auth: _deps.authCubit,
      refreshListenable: _refresh,
      postAuth: _postAuth,
      initialLocation: widget.initialLocation ?? AuthRoutes.splash,
    );
    _deepLinks = DeepLinkRouterHook()..attach(_router);
    _deps.notificationRouter.bindNavigator(_router.go);
    _deps.snapshotSessionBinder.start();
    // Prompt OS permissions (no intermediate page) after profile setup, then
    // register FCM. Re-entry uses the stored flag so dialogs are not repeated.
    _postAuth.addListener(_maybePromptRuntimePermissions);
    _authSub = _deps.authCubit.stream.listen((state) {
      if (state is AuthSignedIn) {
        _maybePromptRuntimePermissions();
        unawaited(_deps.analytics.setUserId(state.profile.id));
      } else {
        unawaited(_deps.analytics.setUserId(null));
      }
    });
    unawaited(_postAuth.load());
    unawaited(_deps.authCubit.restore());
    unawaited(_deps.connectivity.start());
  }

  bool _promptingPermissions = false;

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

  @override
  void dispose() {
    _postAuth.removeListener(_maybePromptRuntimePermissions);
    unawaited(_authSub?.cancel() ?? Future<void>.value());
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
    return _deps.provide(
      child: ChangeNotifierProvider<PostAuthGate>.value(
        value: _postAuth,
        child: MaterialApp.router(
          title: 'DealGo',
          debugShowCheckedModeBanner: false,
          theme: DealGoTheme.light,
          locale: const Locale('vi'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          routerConfig: _router,
        ),
      ),
    );
  }
}
