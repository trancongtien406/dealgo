import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import '../core/auth/token_store.dart';
import '../core/deeplink/deep_link_router_hook.dart';
import '../core/design_system/theme/dealgo_theme.dart';
import '../features/chat/data/datasources/chat_remote_datasource.dart';
import '../features/food/data/datasources/food_remote_datasource.dart';
import '../features/identity/data/datasources/identity_remote_datasource.dart';
import '../features/identity/domain/auth_redirect.dart';
import '../features/identity/domain/entities/auth_state.dart';
import '../features/ride/data/datasources/ride_remote_datasource.dart';
import '../l10n/app_localizations.dart';
import 'di.dart';
import 'router/app_router.dart';

class DealGoApp extends StatefulWidget {
  const DealGoApp({
    super.key,
    this.identityClient,
    this.tokenStore,
    this.foodClient,
    this.rideClient,
    this.chatClient,
    this.initialLocation,
  });

  final IdentityClient? identityClient;
  final TokenStore? tokenStore;
  final FoodClient? foodClient;
  final RideClient? rideClient;
  final ChatClient? chatClient;
  final String? initialLocation;

  @override
  State<DealGoApp> createState() => _DealGoAppState();
}

class _DealGoAppState extends State<DealGoApp> {
  late final DealGoDependencies _deps;
  late final AuthRefreshListenable _refresh;
  late final GoRouter _router;
  late final DeepLinkRouterHook _deepLinks;
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    _deps = DealGoDependencies.create(
      identityClient: widget.identityClient,
      tokenStore: widget.tokenStore,
      foodClient: widget.foodClient,
      rideClient: widget.rideClient,
      chatClient: widget.chatClient,
    );
    _refresh = AuthRefreshListenable(_deps.authCubit);
    _router = createAppRouter(
      auth: _deps.authCubit,
      refreshListenable: _refresh,
      initialLocation: widget.initialLocation ?? AuthRoutes.onboarding,
    );
    // Kept for future OS app_links / universal-link registration.
    _deepLinks = DeepLinkRouterHook()..attach(_router);
    _deps.notificationRouter.bindNavigator(_router.go);
    _deps.snapshotSessionBinder.start();
    _authSub = _deps.authCubit.stream.listen((state) {
      if (state is AuthSignedIn) {
        unawaited(_deps.registerPushIfSignedIn());
        unawaited(
          _deps.analytics.setUserId(
            state.profile.id,
          ),
        );
      } else {
        unawaited(_deps.analytics.setUserId(null));
      }
    });
    unawaited(_deps.authCubit.restore());
    unawaited(_deps.connectivity.start());
  }

  @override
  void dispose() {
    unawaited(_authSub?.cancel() ?? Future<void>.value());
    _deepLinks.router = null;
    _router.dispose();
    _refresh.dispose();
    unawaited(_deps.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _deps.provide(
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
    );
  }
}
