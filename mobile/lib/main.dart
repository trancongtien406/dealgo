import 'dart:async';

import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'app/dealgo_app.dart';
import 'core/design_system/components/dealgo_nav_insets.dart';
import 'core/auth/secure_token_store.dart';
import 'core/auth/token_store.dart';
import 'core/config/api_base_url.dart';
import 'core/config/app_env.dart';
import 'core/launch/launch_splash.dart';
import 'core/maps/maps_client_config.dart';
import 'core/mock/mock_seed.dart';
import 'core/observability/crash_reporting.dart';
import 'core/observability/performance_monitoring.dart';
import 'core/push/fcm_push.dart';
import 'core/appearance/app_appearance.dart';
import 'core/analytics/firebase_analytics_service.dart';
import 'core/app_check/app_check_service.dart';
import 'core/storage/customer_booking_prefs.dart';
import 'firebase_options.dart';

Future<void> main() => runWithCrashReporting(_start);

Future<void> _start() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Native launch screen stays until DealGoApp knows the first route.
  LaunchSplash.hold();
  enableAndroidEdgeToEdge();
  await CustomerBookingPrefs.warmUp();
  await AppAppearance.warmUp();
  if (!useMockData) {
    await MapsClientConfig.resolveAtLaunch(
      Dio(
        BaseOptions(
          baseUrl: normalizeBaseUrl(apiBaseUrl),
          connectTimeout: MapsClientConfig.launchWait,
          receiveTimeout: MapsClientConfig.launchWait,
        ),
      ),
    );
  }
  final bootTrace = await _initFirebaseSafely();
  await _maybeSeedSmokeSession();

  if (useMockData) {
    if (kReleaseMode) {
      throw StateError('USE_MOCK_DATA is not allowed in release builds');
    }
    final mocks = createSeededMockClients();
    _runApp(
      DealGoApp(
        identityClient: mocks.identity,
        foodClient: mocks.food,
        rideClient: mocks.ride,
        tokenStore: MemoryTokenStore(),
      ),
      bootTrace,
    );
    return;
  }
  _runApp(const DealGoApp(), bootTrace);
}

/// Runs [app] and, when measuring, ends the cold-start trace on the first
/// rendered frame — the point where the user can actually use the app.
void _runApp(Widget app, PerfTrace? bootTrace) {
  runApp(app);
  if (bootTrace == null) {
    return;
  }
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(bootTrace.stop());
  });
}

/// Local smoke only: inject seed session via `--dart-define=SMOKE_ACCESS_TOKEN=` /
/// `SMOKE_REFRESH_TOKEN=` (ignored in release; never invent production secrets).
Future<void> _maybeSeedSmokeSession() async {
  if (kReleaseMode) {
    return;
  }
  const access = String.fromEnvironment('SMOKE_ACCESS_TOKEN');
  const refresh = String.fromEnvironment('SMOKE_REFRESH_TOKEN');
  if (access.isEmpty || refresh.isEmpty) {
    return;
  }
  await SecureTokenStore().write(
    StoredTokens(accessToken: access, refreshToken: refresh),
  );
}

/// Soft-fail Firebase + FCM bootstrap so missing keys never crash cold start.
///
/// Returns the running cold-start trace (null when Performance is off or
/// Firebase could not start): the caller stops it on the first frame.
Future<PerfTrace?> _initFirebaseSafely() async {
  if (useMockData) {
    return null;
  }
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    // Collection must be on before the trace starts, otherwise the report is
    // dropped.
    await PerformanceMonitoring.instance.init();
    final bootTrace = PerformanceMonitoring.instance.startTrace(
      'app_bootstrap',
    );
    // Handler registration + iOS presentation options are not needed for
    // the first frame; do not keep the launch screen waiting on them.
    unawaited(
      configureFcmMessaging().catchError((Object error) {
        if (kDebugMode) debugPrint('FCM configure skipped: $error');
      }),
    );
    unawaited(
      AppCheckService().activate().catchError((Object error) {
        if (kDebugMode) debugPrint('App Check activate skipped: $error');
      }),
    );
    unawaited(
      initFirebaseCrashlytics().catchError((Object error) {
        if (kDebugMode) debugPrint('Crashlytics init skipped: $error');
      }),
    );
    unawaited(
      FirebaseAnalyticsService.instance.init().catchError((Object error) {
        if (kDebugMode) debugPrint('Analytics init skipped: $error');
      }),
    );
    return bootTrace;
  } catch (error, stack) {
    if (kDebugMode) {
      debugPrint('Firebase init skipped: $error');
      debugPrint('$stack');
    }
    return null;
  }
}
